import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_import_report.dart';
import '../../domain/content_package_manifest.dart';
import '../../domain/content_schema_registry.dart';
import '../../../characters/domain/dnd5e_rules.dart';
import '../../../rules/domain/character_rule_definition.dart';
import '../../../rules/domain/class_rule_set.dart';
import '../../../rules/domain/rule_diagnostic.dart';
import '../../../rules/domain/rule_profile.dart';
import '../../../rules/domain/rule_profile_resolver.dart';
import '../../../rules/domain/rule_values.dart';
import '../local/content_repository.dart';
import 'legacy_class_feature_rules_migrator.dart';
import 'rule_choice_validation.dart';

class ContentPackageImporter {
  static const _maxCompressedBytes = 50 * 1024 * 1024;
  static const _maxFileCount = 5000;
  static const _maxSingleFileBytes = 20 * 1024 * 1024;
  static const _maxUncompressedBytes = 200 * 1024 * 1024;

  ContentPackageImporter(this._repository);
  final ContentRepository _repository;

  /// Previews the portable ZIP package format without modifying local storage.
  ///
  /// A dndpack is deliberately constrained to a manifest, entries document,
  /// and image assets under `assets/`; this keeps imports predictable on every
  /// Flutter target and rejects archive traversal before any file is used.
  Future<ContentImportReport> previewDndPack(Uint8List bytes) async {
    if (bytes.lengthInBytes > _maxCompressedBytes) {
      return _invalidPackageReport(
        'package',
        'Archive exceeds the ${_maxCompressedBytes ~/ 1024 ~/ 1024} MB compressed size limit',
        contentHash: sha256.convert(bytes).toString(),
      );
    }

    final contentHash = sha256.convert(bytes).toString();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      return _invalidPackageReport(
        'package',
        'Invalid dndpack archive: $error',
        contentHash: contentHash,
      );
    }

    if (archive.files.length > _maxFileCount) {
      return _invalidPackageReport(
        'package',
        'Archive contains more than $_maxFileCount files',
        contentHash: contentHash,
      );
    }

    final files = <String, Uint8List>{};
    var totalUncompressedBytes = 0;
    for (final file in archive.files) {
      if (file.isDirectory) {
        continue;
      }
      final path = file.name;
      final pathError = _archivePathError(path);
      if (pathError != null) {
        return _invalidPackageReport(
          'package.$path',
          pathError,
          contentHash: contentHash,
        );
      }
      if (files.containsKey(path)) {
        return _invalidPackageReport(
          'package.$path',
          'Archive contains a duplicate path',
          contentHash: contentHash,
        );
      }

      final content = file.content;
      if (content.length > _maxSingleFileBytes) {
        return _invalidPackageReport(
          'package.$path',
          'File exceeds the ${_maxSingleFileBytes ~/ 1024 ~/ 1024} MB size limit',
          contentHash: contentHash,
        );
      }
      totalUncompressedBytes += content.length;
      if (totalUncompressedBytes > _maxUncompressedBytes) {
        return _invalidPackageReport(
          'package',
          'Archive exceeds the ${_maxUncompressedBytes ~/ 1024 ~/ 1024} MB uncompressed size limit',
          contentHash: contentHash,
        );
      }
      files[path] = Uint8List.fromList(content);
    }

    const requiredFiles = {'manifest.json', 'entries.json'};
    if (!requiredFiles.every(files.containsKey)) {
      return _invalidPackageReport(
        'package',
        'A dndpack must contain manifest.json and entries.json',
        contentHash: contentHash,
      );
    }
    for (final path in files.keys) {
      if (!requiredFiles.contains(path) && !path.startsWith('assets/')) {
        return _invalidPackageReport(
          'package.$path',
          'Only manifest.json, entries.json, and assets/ files are allowed',
          contentHash: contentHash,
        );
      }
    }

    final assets = <String, Uint8List>{};
    for (final entry in files.entries.where(
      (entry) => entry.key.startsWith('assets/'),
    )) {
      if (!_isSupportedImage(entry.key, entry.value)) {
        return _invalidPackageReport(
          'package.${entry.key}',
          'Assets must be PNG, JPEG, GIF, or WebP files with a matching signature',
          contentHash: contentHash,
        );
      }
      assets[entry.key] = entry.value;
    }

    Object? manifest;
    Object? entries;
    try {
      manifest = jsonDecode(utf8.decode(files['manifest.json']!));
      entries = jsonDecode(utf8.decode(files['entries.json']!));
    } catch (error) {
      return _invalidPackageReport(
        'package',
        'manifest.json or entries.json is not valid UTF-8 JSON: $error',
        contentHash: contentHash,
      );
    }
    if (manifest is! Map<String, Object?> || entries is! List<Object?>) {
      return _invalidPackageReport(
        'package',
        'manifest.json must be an object and entries.json must be an array',
        contentHash: contentHash,
      );
    }

    final combined = Map<String, Object?>.from(manifest)..['entries'] = entries;
    final parsedReport = await previewJson(jsonEncode(combined));
    final errors = [...parsedReport.errors];
    final warnings = [...parsedReport.warnings];
    for (
      var entryIndex = 0;
      entryIndex < parsedReport.entries.length;
      entryIndex++
    ) {
      final entry = parsedReport.entries[entryIndex];
      for (var blockIndex = 0; blockIndex < entry.body.length; blockIndex++) {
        final block = entry.body[blockIndex];
        if (block is ImageBlock && !assets.containsKey(block.asset)) {
          errors.add(
            ContentValidationError(
              path:
                  r'$.entries['
                  '$entryIndex].body[$blockIndex].asset',
              message: 'Image asset "${block.asset}" does not exist in assets/',
            ),
          );
        }
      }
    }
    return _buildReport(
      errors: errors,
      warnings: warnings,
      classRuleSources: parsedReport.classRuleSources,
      contentHash: contentHash,
      formatVersion: parsedReport.formatVersion,
      packageId: parsedReport.packageId,
      packageName: parsedReport.packageName,
      version: parsedReport.version,
      locale: parsedReport.locale,
      system: parsedReport.system,
      entryCount: parsedReport.entryCount,
      priority: parsedReport.priority,
      entries: parsedReport.entries,
      assets: assets,
    );
  }

  Future<ContentImportReport> previewJson(String jsonStr) async {
    final errors = <ContentValidationError>[];
    final warnings = <ContentValidationError>[];
    final assets = <String, Uint8List>{};
    // 每个 class 条目的列级来源（契约 §3.7）；由 [_validateStructuredClassRules]
    // 经生产解析链收集，`previewJson` 持有后带进报告。
    final classRuleSources = <String, List<RuleFieldSource>>{};
    final contentHash = sha256.convert(utf8.encode(jsonStr)).toString();

    Object? parsed;
    try {
      parsed = jsonDecode(jsonStr);
    } catch (e) {
      return ContentImportReport(
        valid: false,
        formatVersion: 0,
        packageId: '',
        packageName: '',
        version: '',
        locale: '',
        system: '',
        entryCount: 0,
        entries: const [],
        errors: [
          ContentValidationError(path: r'$', message: 'Invalid JSON: $e'),
        ],
        assets: const {},
        contentHash: contentHash,
      );
    }

    if (parsed is! Map<String, Object?>) {
      errors.add(
        const ContentValidationError(
          path: r'$',
          message: 'Root must be a JSON object',
        ),
      );
      return _buildReport(
        errors: errors,
        warnings: warnings,
        contentHash: contentHash,
        formatVersion: 0,
        packageId: '',
        packageName: '',
        version: '',
        locale: '',
        system: '',
        entryCount: 0,
        priority: 0,
        entries: const [],
        assets: assets,
      );
    }

    final json = parsed;

    // Validate formatVersion：契约只承认一个版本，1/2 是旧格式，整包拒绝。
    // 判据是**严格不等** `!= 3`：`toInt()` 会把 3.5 截成 3 放行。
    // 三条失败分支（缺省 / 非数字 / 数值不为 3）都带 `unsupportedFormatVersion`：
    // 它们对作者是同一件事——"这个版本不受支持，请重新生成"，code 不该只在其中一条出现。
    final formatVersionValue = json['formatVersion'];
    var formatVersion = 0;
    if (formatVersionValue == null) {
      errors.add(
        const ContentValidationError(
          path: r'$.formatVersion',
          message: '缺少 formatVersion：只支持 formatVersion 3；'
              '请用新版工具重新生成/重新提取资料包（unsupportedFormatVersion）',
        ),
      );
    } else if (formatVersionValue is! num) {
      errors.add(
        ContentValidationError(
          path: r'$.formatVersion',
          message: 'formatVersion 必须是数字（当前为 "$formatVersionValue"）：'
              '只支持 formatVersion 3；请用新版工具重新生成/重新提取资料包'
              '（unsupportedFormatVersion）',
        ),
      );
    } else if (formatVersionValue != 3) {
      errors.add(
        ContentValidationError(
          path: r'$.formatVersion',
          message:
              'formatVersion $formatVersionValue 是旧格式或不受支持的版本：'
              '只支持 formatVersion 3；请用新版工具重新生成/重新提取资料包'
              '（unsupportedFormatVersion）',
        ),
      );
    } else {
      formatVersion = 3;
    }

    // 规则覆盖优先级（S3 决策 D2）：整数 0..1000，缺省 0。非整数不静默取默认值——
    // 那会让"写了 '30' 的包"以为自己的勘误生效了，实际排在内置档案之后。
    final rawPriority = json['priority'];
    var priority = 0;
    if (rawPriority != null) {
      if (rawPriority is! int || rawPriority < 0 || rawPriority > 1000) {
        errors.add(
          const ContentValidationError(
            path: r'$.priority',
            message: 'priority 必须是 0..1000 的整数，缺省为 0（invalidPriority）',
          ),
        );
      } else {
        priority = rawPriority;
      }
    }

    // 内置档案是 abilities / skills 的**唯一权威**（§3.1、§5.2）：包自带同名清单
    // 不报错，但要明确告知作者"这份清单被忽略"，避免他以为改这里能生效。
    for (final ignored in const ['abilities', 'skills']) {
      if (json[ignored] == null) continue;
      warnings.add(
        ContentValidationError(
          path: '\$.$ignored',
          message: '资料包自带的 $ignored 清单会被忽略：内置档案是唯一权威'
              '（ignoredGlobalList）',
        ),
      );
    }

    // Validate required string fields
    final packageId =
        _validateNonEmptyString(json['id'], r'$.id', errors) ?? '';
    final packageName =
        _validateNonEmptyString(json['name'], r'$.name', errors) ?? '';
    final version =
        _validateNonEmptyString(json['version'], r'$.version', errors) ?? '';
    final locale =
        _validateNonEmptyString(json['locale'], r'$.locale', errors) ?? '';
    final system =
        _validateNonEmptyString(json['system'], r'$.system', errors) ?? '';
    if (system.isNotEmpty && system != 'dnd5e-2024') {
      errors.add(
        const ContentValidationError(
          path: r'$.system',
          message: 'Only dnd5e-2024 content is supported',
        ),
      );
    }

    // Validate entryCount
    final entryCountValue = json['entryCount'];
    var declaredEntryCount = -1;
    if (entryCountValue == null) {
      errors.add(
        const ContentValidationError(
          path: r'$.entryCount',
          message: 'entryCount is required',
        ),
      );
    } else if (entryCountValue is! num) {
      errors.add(
        const ContentValidationError(
          path: r'$.entryCount',
          message: 'entryCount must be a number',
        ),
      );
    } else {
      declaredEntryCount = entryCountValue.toInt();
    }

    // Parse and validate entries
    final entriesJson = json['entries'];
    final entries = <ContentEntry>[];
    final entryIds = <String>{};

    if (entriesJson is! List<Object?>) {
      errors.add(
        const ContentValidationError(
          path: r'$.entries',
          message: 'entries must be a list',
        ),
      );
    } else {
      // Check entryCount match
      if (declaredEntryCount >= 0 && declaredEntryCount != entriesJson.length) {
        errors.add(
          ContentValidationError(
            path: r'$.entryCount',
            message:
                'entryCount ($declaredEntryCount) does not match actual entries (${entriesJson.length})',
          ),
        );
      }

      // First pass: parse entries and validate IDs
      final parsedEntries = <int, ContentEntry>{};

      for (var i = 0; i < entriesJson.length; i++) {
        final entryJson = entriesJson[i];
        final entryPath = '\$.entries[$i]';

        if (entryJson is! Map<String, Object?>) {
          errors.add(
            ContentValidationError(
              path: entryPath,
              message: 'entry must be a JSON object',
            ),
          );
          continue;
        }

        // Validate entry ID prefix
        final entryId = entryJson['id'];
        if (entryId is String && packageId.isNotEmpty) {
          if (!entryId.startsWith('$packageId:')) {
            errors.add(
              ContentValidationError(
                path: '$entryPath.id',
                message: 'entry ID "$entryId" must start with "$packageId:"',
              ),
            );
          }
          if (entryIds.contains(entryId)) {
            errors.add(
              ContentValidationError(
                path: '$entryPath.id.duplicate',
                message: 'duplicate entry ID: $entryId',
              ),
            );
          } else {
            entryIds.add(entryId);
          }
        }

        // 解析前先在**原始 JSON** 上做一遍形状/参照校验：解析层只有一条没有
        // 位置的 [FormatException]，作者拿到 `$.entries[i]` 找不到字段（§5.1、
        // §10 第 5 条要求 path 精确到字段）。
        final preciseRuleErrors = validateRawEntryRules(
          entryJson,
          entryPath,
          errors,
        );

        // Parse the entry：这里只放"纯内容解析"。规则诊断在 try 之外运行，
        // 因为 `structured.classRules` 的档案校验要读 `Dnd5eRules.profile`——
        // 未装配档案是**启动装配错误**，不能被 `catch (e)` 降级成
        // "invalid entry: …"（把装配问题误报成内容问题）。
        String normalizedType = '';
        Map<String, Object?>? parsedEntryJson;
        Object? rawClassRules;
        try {
          final normalizedJson = Map<String, Object?>.from(entryJson);
          final sourceType = '${normalizedJson['type'] ?? ''}';
          normalizedType = ContentSchemaRegistry.defaults.normalizeType(
            sourceType,
          );
          normalizedJson['type'] = normalizedType;
          final structured = normalizedJson['structured'];
          if (structured is Map) {
            final normalizedStructured = ContentSchemaRegistry.defaults
                .normalizeStructured(
                  normalizedType,
                  Map<String, Object?>.from(structured),
                );
            rawClassRules = normalizedStructured['classRules'];
            normalizedJson['structured'] = normalizedStructured;
          }
          final entry = ContentEntry.fromJson(normalizedJson);
          parsedEntries[i] = entry;
          entries.add(entry);
          parsedEntryJson = normalizedJson;
        } catch (e) {
          // `value` + `formula` 同时声明由解析层拒绝（[RuleGrantDefinition.fromJson]），
          // 抛出的 [FormatException] 不带位置。契约要求 path 精确到 `[i].formula`，
          // 所以在原始 JSON 上重新定位一次；定位成功就只报那条精确 error，
          // 不再追加笼统的 "invalid entry"（避免同一条输入报两次）。
          final precisePath = e is FormatException
              ? ruleGrantValueAndFormulaPath(
                  entryJson['rules'] is Map
                      ? Map<String, Object?>.from(entryJson['rules'] as Map)
                      : const <String, Object?>{},
                  '$entryPath.rules',
                )
              : null;
          if (precisePath != null) {
            errors.add(
              ContentValidationError(
                path: precisePath,
                message:
                    'hitPoints / ability 授予的 value 与 formula 只能二选一，'
                    '不能同时声明（invalidMaxSpec）',
              ),
            );
          } else if (!preciseRuleErrors) {
            // 上面的原始 JSON 校验已经给出精确 path 时不再追加笼统的
            // "invalid entry"——同一条输入报两次只会淹没真正的出错字段。
            errors.add(
              ContentValidationError(
                path: entryPath,
                message: 'invalid entry: $e',
              ),
            );
          }
        }
        if (parsedEntryJson == null) continue;

        _validateStructuredClassRules(
          normalizedType: normalizedType,
          entryId: entryId is String ? entryId : '',
          name: '${parsedEntryJson['name'] ?? ''}',
          rawClassRules: rawClassRules,
          entryRuleDefinition: parsedEntries[i]?.rules,
          priority: priority,
          classRuleSources: classRuleSources,
          path: '$entryPath.structured.classRules',
          errors: errors,
          warnings: warnings,
        );
      }

      // Second pass: validate links
      for (final entryMap in parsedEntries.entries) {
        final i = entryMap.key;
        final entry = entryMap.value;
        for (var j = 0; j < entry.body.length; j++) {
          final block = entry.body[j];
          if (block is EntryLinkBlock) {
            if (!entryIds.contains(block.targetId)) {
              errors.add(
                ContentValidationError(
                  path: '\$.entries[$i].body[$j].targetId',
                  message:
                      'link target "${block.targetId}" does not exist in package',
                ),
              );
            }
          }
        }
        for (var j = 0; j < entry.relations.length; j++) {
          final relation = entry.relations[j];
          if (!entryIds.contains(relation.targetId)) {
            errors.add(
              ContentValidationError(
                path: '\$.entries[$i].relations[$j].targetId',
                message:
                    'relation target "${relation.targetId}" does not exist in package',
              ),
            );
          }
        }
        if (formatVersion >= 2 && entry.rules != null) {
          validateRuleReferences(
            entry.id,
            entry.rules!,
            entryIds,
            {for (final candidate in entries) candidate.id: candidate},
            '\$.entries[$i].rules',
            errors,
          );
        }
        if (entry.rules != null) {
          _validateGrantFormulas(
            entry.rules!,
            '\$.entries[$i].rules',
            errors,
          );
        }
      }
    }

    final migratedEntries = errors.isEmpty
        ? const LegacyClassFeatureRulesMigrator().migrate(entries)
        : entries;
    return _buildReport(
      errors: errors,
      warnings: warnings,
      classRuleSources: classRuleSources,
      contentHash: contentHash,
      formatVersion: formatVersion,
      packageId: packageId,
      packageName: packageName,
      version: version,
      locale: locale,
      system: system,
      entryCount: migratedEntries.length,
      priority: priority,
      entries: migratedEntries,
      assets: assets,
    );
  }

  Future<void> importReport(ContentImportReport report) async {
    if (!report.valid) {
      throw ArgumentError('Cannot import an invalid report');
    }
    await _repository.replacePackage(
      manifest: ContentPackageManifest(
        formatVersion: report.formatVersion,
        id: report.packageId,
        name: report.packageName,
        version: report.version,
        locale: report.locale,
        system: report.system,
        entryCount: report.entryCount,
        // 从 report 重建 manifest 必须带上 priority：否则导入预览里显示的优先级
        // 与落库值不一致，"预览 40 实际 0"会让勘误静默排在档案之后。
        priority: report.priority,
      ),
      entries: report.entries,
      contentHash: report.contentHash,
      assets: report.assets,
    );
  }

  String? _archivePathError(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.startsWith('\\') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(path) ||
        path.contains('\\') ||
        path.split('/').any((segment) => segment == '..' || segment.isEmpty)) {
      return 'Archive path is unsafe';
    }
    return null;
  }

  bool _isSupportedImage(String path, Uint8List bytes) {
    final extension = path.split('.').last.toLowerCase();
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final isGif =
        bytes.length >= 6 &&
        (utf8.decode(bytes.sublist(0, 6), allowMalformed: true) == 'GIF87a' ||
            utf8.decode(bytes.sublist(0, 6), allowMalformed: true) == 'GIF89a');
    final isWebp =
        bytes.length >= 12 &&
        utf8.decode(bytes.sublist(0, 4), allowMalformed: true) == 'RIFF' &&
        utf8.decode(bytes.sublist(8, 12), allowMalformed: true) == 'WEBP';
    return (extension == 'png' && isPng) ||
        ((extension == 'jpg' || extension == 'jpeg') && isJpeg) ||
        (extension == 'gif' && isGif) ||
        (extension == 'webp' && isWebp);
  }

  ContentImportReport _invalidPackageReport(
    String path,
    String message, {
    required String contentHash,
  }) => _buildReport(
    errors: [ContentValidationError(path: path, message: message)],
    contentHash: contentHash,
    formatVersion: 0,
    packageId: '',
    packageName: '',
    version: '',
    locale: '',
    system: '',
    entryCount: 0,
    priority: 0,
    entries: const [],
    assets: const {},
  );

  String? _validateNonEmptyString(
    Object? value,
    String path,
    List<ContentValidationError> errors,
  ) {
    if (value is! String || value.isEmpty) {
      errors.add(
        ContentValidationError(
          path: path,
          message: '$path must be a non-empty string',
        ),
      );
      return null;
    }
    return value;
  }

  /// `structured.classRules` 的导入期诊断（契约：error 阻断整包、warning 只提示）。
  ///
  /// 四条规则：
  /// 1. 显式声明了 `classRules`（对象）→ 交给 `ClassRuleSet.parse`（形状/类型，
  ///    `abilities` 传档案的）+ [RuleProfileResolver.validateEntryClassRules]
  ///    （档案侧：`unknownArchetype` 与 §5.2 的 warning），按 severity 分流；
  /// 2. 写了 `classRules` 却不是对象 → error `invalidTable`。这不是"没有规则来源"，
  ///    降级成 warning 会让坏声明静默通过，职业最后一条规则都没有；
  /// 3. 未声明、且规范 slug 命中**内置档案**的职业 → error
  ///    `builtinSlugRequiresExplicitRules`：杜绝"slug 写错就静默继承内置职业数值"。
  ///    判据来自 [Dnd5eRules.profile] 的 `classes` / `classAliases`，不写死名单；
  /// 4. 未声明的普通自制职业（档案里也没有）→ warning `unresolvedClassRule`；
  ///    命中档案的条目**不再**收到该 warning（文案与 error 自相矛盾）。
  ///
  /// 判定用的 slug 与运行期**同源**：都是"条目 id 末段"（[Dnd5eRules.resolveClassSlug]），
  /// 不是条目里的 `slug` 展示字段——运行期按 id 末段继承内置数值，保护必须盯同一个键。
  void _validateStructuredClassRules({
    required String normalizedType,
    required String entryId,
    required String name,
    required Object? rawClassRules,
    required CharacterRuleDefinition? entryRuleDefinition,
    required int priority,
    required Map<String, List<RuleFieldSource>> classRuleSources,
    required String path,
    required List<ContentValidationError> errors,
    required List<ContentValidationError> warnings,
  }) {
    if (normalizedType != 'class') return;

    final slug = Dnd5eRules.resolveClassSlug(
      entryId: entryId.isEmpty ? null : entryId,
      classSummary: name,
    );
    final archiveRules = slug.isEmpty
        ? null
        : Dnd5eRules.profile.classRules(slug);

    final diagnostics = <RuleDiagnostic>[];
    if (rawClassRules is Map) {
      final entryRules = ClassRuleSet.parse(
        Map<String, Object?>.from(rawClassRules),
        path: path,
        diagnostics: diagnostics,
        abilities: Dnd5eRules.profile.abilities,
      );
      RuleProfileResolver.validateEntryClassRules(
        profile: Dnd5eRules.profile,
        entryRules: entryRules,
        // 整块缺 `spellcasting` 的施法职业只能靠**作者意图**判断（`mode` 无从得知）：
        // 条目 `rules` 里有 `optionType == 'spell'` 的选择即视为施法职业。
        // 判据的唯一遍历点在 [CharacterRuleDefinition.declaresChoiceOfType]。
        hasSpellChoiceIntent:
            entryRuleDefinition?.declaresChoiceOfType('spell') ?? false,
        // 档案侧（`spellcasting` 继承判断 + 补丁资源的低 tier 可补齐性）只看这一份：
        // 档案已提供 `spellcasting` 时条目不写它不是缺省（字段级继承，§3.6），
        // 拆成两个入参只会多一处"忘传 → 静默变 false"的隐患。
        archiveRules: archiveRules,
        path: path,
        diagnostics: diagnostics,
      );

      // 来源摘要（契约 §3.7）：**复用生产解析链**，不另写一份合并。
      // 导入预览阶段的语义是"只看这个包 + 内置档案"，因此不接跨包索引
      // （冲突是运行期概念：导入单个包时看不到别的包）。
      final merged = RuleProfileResolver.resolveClassRules(
        profile: Dnd5eRules.profile,
        slug: slug,
        entryRules: entryRules,
        entryId: entryId.isEmpty ? null : entryId,
        entryPriority: priority,
      );
      classRuleSources[entryId] = [
        for (final field in merged.fieldSources.keys.toList()..sort())
          merged.fieldSources[field]!,
      ];
    } else if (rawClassRules != null) {
      errors.add(
        ContentValidationError(
          path: path,
          message: 'classRules 必须是对象（invalidTable）',
        ),
      );
    } else if (archiveRules != null) {
      // 未声明 classRules 却命中内置职业：必须阻断，不能静默继承内置数值。
      diagnostics.add(
        RuleDiagnostic(
          path: path,
          severity: RuleSeverity.error,
          code: 'builtinSlugRequiresExplicitRules',
          message:
              'slug "$slug" 属于内置职业：若要覆盖其数值必须显式声明 classRules，'
              '否则会静默继承内置数值',
        ),
      );
    } else {
      // 既无 classRules 也无档案匹配：这才是"没有任何可用规则来源"（§5.2）。
      diagnostics.add(
        RuleDiagnostic(
          path: path,
          severity: RuleSeverity.warning,
          code: 'unresolvedClassRule',
          message: '职业条目未声明 classRules，且内置档案没有同 slug 职业：'
              '该职业没有任何可用规则来源',
        ),
      );
    }

    for (final diagnostic in diagnostics) {
      final target = diagnostic.severity == RuleSeverity.error
          ? errors
          : warnings;
      target.add(
        ContentValidationError(
          path: diagnostic.path,
          message: '${diagnostic.message}（${diagnostic.code}）',
        ),
      );
    }
  }

  /// `hitPoints` grant 的 `formula` 必须过 [MaxSpec] 的同一套封闭语法；`kind:
  /// ability` 只接受 `value`（`formula` 与自引用一律拒绝）；两种授予的 `value` /
  /// `formula` 都必须二选一。
  ///
  /// 契约：非法声明在**导入期**就报 error，不能只在运行期静默跳过（运行期
  /// [MaxSpec.tryParse] 返回 null 会让加值悄悄消失）。其它 grant kind 的
  /// `formula` 语义不同（如伤害骰），不受该封闭语法约束。
  ///
  /// 属性键同理：`kind: ability` 的 `target` 与 `formula: ability:<键>` 的键必须
  /// 落在档案 `abilities` 内（`unknownAbility`）；属性键的唯一权威是档案。
  void _validateGrantFormulas(
    CharacterRuleDefinition rules,
    String rulesPath,
    List<ContentValidationError> errors,
  ) {
    final abilities = Dnd5eRules.profile.abilities;
    void validate(
      List<RuleGrantDefinition> grants,
      String grantsPath,
    ) {
      for (var i = 0; i < grants.length; i++) {
        final grant = grants[i];
        if (grant.kind != RuleGrantKind.hitPoints &&
            grant.kind != RuleGrantKind.ability) {
          continue;
        }
        if (grant.kind == RuleGrantKind.ability &&
            grant.target != null &&
            !abilities.contains(grant.target)) {
          errors.add(
            ContentValidationError(
              path: '$grantsPath[$i].target',
              message:
                  '未知属性键 "${grant.target}"，可用：${abilities.join(', ')}'
                  '（unknownAbility）',
            ),
          );
        }
        final formula = grant.formula;
        // §3.5：`hitPoints` / `ability` 的 `value` 与 `formula` 是**二选一**
        // （判据的唯一实现是 [rejectsValueAndFormula]）。解析层已在
        // [RuleGrantDefinition.fromJson] 抛错；这里是纵深防御，覆盖"绕过解析层
        // 直接构造 CharacterRuleDefinition"的调用方。
        if (rejectsValueAndFormula(
          grant.kind,
          value: grant.value,
          formula: grant.formula,
        )) {
          errors.add(
            ContentValidationError(
              path: '$grantsPath[$i].formula',
              message:
                  'hitPoints / ability 授予的 value 与 formula 只能二选一，'
                  '不能同时声明（invalidMaxSpec）',
            ),
          );
          continue;
        }
        if (formula == null) continue;
        // §3.5：`kind: ability` **只接受 `value`**。`formula` 会让
        // `baseAbilitiesFrom` 的减法没有精确逆：自引用（`ability:int` 授予 int）
        // 每次再派生都把属性抬高一份，链式引用（A 引用 B、B 引用 A）也不保证
        // 不动点。两条都在导入期拒绝，避免"文档允许、运行期算错"。
        if (grant.kind == RuleGrantKind.ability) {
          final target = grant.target;
          if (target != null &&
              (formula == target || formula == 'ability:$target')) {
            errors.add(
              ContentValidationError(
                path: '$grantsPath[$i].formula',
                message:
                    'ability 授予不得自引用：formula "$formula" 读的是本授予的 '
                    'target "$target"（invalidMaxSpec）',
              ),
            );
          } else {
            errors.add(
              ContentValidationError(
                path: '$grantsPath[$i].formula',
                message:
                    'ability 授予只接受 value，不接受 formula（"$formula"）：'
                    'formula 型属性加值没有精确逆运算，再派生会重复叠加'
                    '（invalidMaxSpec）',
              ),
            );
          }
          continue;
        }
        // 属性键判据与 `classRules.resources[].maximum.formula` 共用
        // [abilityKeyInFormula]（唯一实现点），两处不得各写一份 substring。
        final abilityKey = abilityKeyInFormula(formula);
        if (abilityKey != null && !abilities.contains(abilityKey)) {
          errors.add(
            ContentValidationError(
              path: '$grantsPath[$i].formula',
              message:
                  'formula "$formula" 的属性键不在档案 abilities 内，'
                  '可用：${abilities.join(', ')}（unknownAbility）',
            ),
          );
        }
        if (MaxSpec.tryParse(<String, Object?>{'formula': formula}) != null) {
          continue;
        }
        errors.add(
          ContentValidationError(
            path: '$grantsPath[$i].formula',
            message:
                'formula "$formula" 非法：只支持 level / ability:<属性键> / <整数>*level / <整数>'
                '（invalidMaxSpec）',
          ),
        );
      }
    }

    // 内联选项里的 grants 也带 formula（契约 §3.10.2），一并走同一套校验。
    void validateChoiceOptions(
      List<RuleChoiceDefinition> choices,
      String choicesPath,
    ) {
      for (var i = 0; i < choices.length; i++) {
        final options = choices[i].options;
        for (var j = 0; j < options.length; j++) {
          validate(
            options[j].grants,
            '$choicesPath[$i].options[$j].grants',
          );
        }
      }
    }

    validate(rules.grants, '$rulesPath.grants');
    validateChoiceOptions(rules.choices, '$rulesPath.choices');
    for (var i = 0; i < rules.progression.length; i++) {
      validate(rules.progression[i].grants, '$rulesPath.progression[$i].grants');
      validateChoiceOptions(
        rules.progression[i].choices,
        '$rulesPath.progression[$i].choices',
      );
    }
  }

  ContentImportReport _buildReport({
    required List<ContentValidationError> errors,
    List<ContentValidationError> warnings = const [],
    Map<String, List<RuleFieldSource>> classRuleSources = const {},
    required String contentHash,
    required int formatVersion,
    required String packageId,
    required String packageName,
    required String version,
    required String locale,
    required String system,
    required int entryCount,
    required int priority,
    required List<ContentEntry> entries,
    required Map<String, Uint8List> assets,
  }) {
    return ContentImportReport(
      valid: errors.isEmpty,
      formatVersion: formatVersion,
      packageId: packageId,
      packageName: packageName,
      version: version,
      locale: locale,
      system: system,
      entryCount: entryCount,
      priority: priority,
      entries: entries,
      errors: errors,
      warnings: warnings,
      classRuleSources: classRuleSources,
      assets: assets,
      contentHash: contentHash,
    );
  }
}
