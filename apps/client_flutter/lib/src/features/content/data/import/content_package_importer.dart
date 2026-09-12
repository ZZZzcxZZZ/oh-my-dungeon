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
import '../../../rules/domain/rule_choice_resolver.dart';
import '../../../rules/domain/rule_diagnostic.dart';
import '../../../rules/domain/rule_profile_resolver.dart';
import '../../../rules/domain/rule_values.dart';
import '../local/content_repository.dart';
import 'legacy_class_feature_rules_migrator.dart';

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
      contentHash: contentHash,
      formatVersion: parsedReport.formatVersion,
      packageId: parsedReport.packageId,
      packageName: parsedReport.packageName,
      version: parsedReport.version,
      locale: parsedReport.locale,
      system: parsedReport.system,
      entryCount: parsedReport.entryCount,
      entries: parsedReport.entries,
      assets: assets,
    );
  }

  Future<ContentImportReport> previewJson(String jsonStr) async {
    final errors = <ContentValidationError>[];
    final warnings = <ContentValidationError>[];
    final assets = <String, Uint8List>{};
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
        entries: const [],
        assets: assets,
      );
    }

    final json = parsed;

    // Validate formatVersion：契约只承认一个版本，1/2 是旧格式，整包拒绝。
    // 判据是**严格不等** `!= 3`：`toInt()` 会把 3.5 截成 3 放行。
    final formatVersionValue = json['formatVersion'];
    var formatVersion = 0;
    if (formatVersionValue == null) {
      errors.add(
        const ContentValidationError(
          path: r'$.formatVersion',
          message: 'formatVersion is required',
        ),
      );
    } else if (formatVersionValue is! num) {
      errors.add(
        const ContentValidationError(
          path: r'$.formatVersion',
          message: 'formatVersion must be a number',
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
          errors.add(
            ContentValidationError(
              path: entryPath,
              message: 'invalid entry: $e',
            ),
          );
        }
        if (parsedEntryJson == null) continue;

        _validateStructuredClassRules(
          normalizedType: normalizedType,
          entryId: entryId is String ? entryId : '',
          name: '${parsedEntryJson['name'] ?? ''}',
          rawClassRules: rawClassRules,
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
          _validateRuleReferences(
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
      contentHash: contentHash,
      formatVersion: formatVersion,
      packageId: packageId,
      packageName: packageName,
      version: version,
      locale: locale,
      system: system,
      entryCount: migratedEntries.length,
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

  void _validateRuleReferences(
    String sourceEntryId,
    CharacterRuleDefinition rules,
    Set<String> entryIds,
    Map<String, ContentEntry> entries,
    String path,
    List<ContentValidationError> errors,
  ) {
    void validateGrants(List<RuleGrantDefinition> grants, String grantsPath) {
      for (var i = 0; i < grants.length; i++) {
        final entryId = grants[i].entryId;
        if (entryId != null && !entryIds.contains(entryId)) {
          errors.add(
            ContentValidationError(
              path: '$grantsPath[$i].entryId',
              message: 'rule entry reference "$entryId" does not exist',
            ),
          );
        }
      }
    }

    void validateChoices(
      List<RuleChoiceDefinition> choices,
      String choicesPath,
    ) {
      final resolver = RuleChoiceResolver(entries: entries);
      for (var i = 0; i < choices.length; i++) {
        for (var j = 0; j < choices[i].optionEntryIds.length; j++) {
          final entryId = choices[i].optionEntryIds[j];
          if (!entryIds.contains(entryId)) {
            errors.add(
              ContentValidationError(
                path: '$choicesPath[$i].optionEntryIds[$j]',
                message: 'rule choice option "$entryId" does not exist',
              ),
            );
          } else if (!resolver.allows(
            choices[i],
            entryId,
            sourceEntryId: sourceEntryId,
          )) {
            errors.add(
              ContentValidationError(
                path: '$choicesPath[$i].optionEntryIds[$j]',
                message:
                    'rule choice option "$entryId" does not satisfy its type, tag, or level filters',
              ),
            );
          }
        }
        for (var j = 0; j < choices[i].recommendedEntryIds.length; j++) {
          final entryId = choices[i].recommendedEntryIds[j];
          if (!entryIds.contains(entryId)) {
            errors.add(
              ContentValidationError(
                path: '$choicesPath[$i].recommendedEntryIds[$j]',
                message: 'recommended rule choice "$entryId" does not exist',
              ),
            );
          } else if (!resolver.allows(
            choices[i],
            entryId,
            sourceEntryId: sourceEntryId,
          )) {
            errors.add(
              ContentValidationError(
                path: '$choicesPath[$i].recommendedEntryIds[$j]',
                message:
                    'recommended rule choice "$entryId" does not satisfy its type, tag, or level filters',
              ),
            );
          }
        }
      }
    }

    validateGrants(rules.grants, '$path.grants');
    validateChoices(rules.choices, '$path.choices');
    for (var i = 0; i < rules.progression.length; i++) {
      final step = rules.progression[i];
      validateGrants(step.grants, '$path.progression[$i].grants');
      validateChoices(step.choices, '$path.progression[$i].choices');
    }
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
        path: path,
        diagnostics: diagnostics,
      );
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

  /// `hitPoints` / `ability` grant 的 `formula` 必须过 [MaxSpec] 的同一套封闭语法，
  /// 且 `kind: ability` 的 `target` 与 `formula: ability:<key>` 的键必须落在档案
  /// `abilities` 内（§5.1 `unknownAbility`）。
  ///
  /// 契约：非法 formula 在**导入期**就报 `invalidMaxSpec`，不能只在运行期静默跳过
  /// （运行期 [MaxSpec.tryParse] 返回 null 会让加值悄悄消失）。其它 grant kind 的
  /// `formula` 语义不同（如伤害骰），不受该封闭语法约束。
  ///
  /// 属性键同理：`MaxSpec` 的正则只保证 `ability:[a-z]{3}` 的**形状**，运行期
  /// [RulesDrivenCharacterBuilder] 对不在档案里的键是跳过（加值消失），所以键是否
  /// 存在必须在导入期报出来。属性键的唯一权威是档案 `abilities`。
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
        // §3.5：`hitPoints` / `ability` 的 `value` 与 `formula` 是**二选一**，
        // 同时写会让"到底按哪个结算"变成运行期猜测，导入期直接报 error。
        if (formula != null && grant.value != null) {
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
        if (formula.startsWith('ability:') &&
            !abilities.contains(formula.substring('ability:'.length))) {
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
    required String contentHash,
    required int formatVersion,
    required String packageId,
    required String packageName,
    required String version,
    required String locale,
    required String system,
    required int entryCount,
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
      entries: entries,
      errors: errors,
      warnings: warnings,
      assets: assets,
      contentHash: contentHash,
    );
  }
}
