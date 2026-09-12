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
import '../../../rules/domain/rule_choice_semantics.dart';
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

  /// `optionType` 的合法取值 = 内容 schema 的**条目类型** ∪ 值类型
  /// （[kValueOptionTypes]，契约 §3.10.2）。
  ///
  /// 不能拿 `ContentSchemaRegistry.normalizeType` 判断"是否已知"——它把任何未知
  /// 类型都降级成 `custom`，永远返回一个合法类型。schema 的类型集合是唯一权威。
  static final Set<String> _knownOptionTypes = {
    for (final schema in ContentSchemaRegistry.defaults.schemas) schema.type,
    ...kValueOptionTypes,
  };

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
        final preciseRuleErrors = _validateRawEntryRules(
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

    // 档案是属性键 / 技能名的**唯一权威**（与运行期 `skills.containsKey` 同源）。
    // `late` 让没有值类型选择、没有 `requires` 的条目完全不付这份代价。
    late final Set<String> abilityKeys = Dnd5eRules.profile.abilities;
    late final Set<String> skillNames = Dnd5eRules.skills
        .map((skill) => skill.name)
        .toSet();

    /// `requires` 的**引用/取值语义**校验（§5.1 `invalidRequires`）。
    ///
    /// 作用域链的遍历**唯一**走 [RuleChoiceSemantics.scopeEntryIdsFor]（与运行期
    /// 同源，导入器不得自己重写一遍 `relations` 遍历）；`option` 的存在性判定 =
    /// 该选择的候选集（[RuleChoiceSemantics.candidatesFor]，决策 D3/D5：`option`
    /// 指的是**选中值**，内联选项 id 与条目 id 都算）。
    void validateRequires(
      List<RuleRequiresDefinition> requires,
      String requiresPath,
    ) {
      for (var index = 0; index < requires.length; index++) {
        final requirement = requires[index];
        final itemPath = '$requiresPath[$index]';
        if (requirement.isAbilityForm) {
          final ability = requirement.ability;
          if (ability != null && !abilityKeys.contains(ability)) {
            errors.add(
              ContentValidationError(
                path: '$itemPath.ability',
                message:
                    'requires 引用的属性键 "$ability" 不在档案 abilities 内'
                    '（invalidRequires）',
              ),
            );
          }
          continue;
        }
        final choiceId = requirement.choice;
        if (choiceId == null) continue;
        // 作用域内**所有**同 `choiceId` 的定义（不是首个命中）。选择键是
        // `<entryId>#<choiceId>`，运行期 [RuleChoiceSemantics.requiresSatisfied]
        // 经 `_selectedOptions` 把作用域内所有同 choiceId 键的选中值取**并集**；
        // 导入期若只取首个命中，当同一条选择 id 同时出现在条目与其
        // `featureOf` / `subclassOf` 祖先时，祖先定义的合法 option 会被误拒
        // （导入口径比运行期更严 = 假阴性）。
        final definitions =
            <({RuleChoiceDefinition definition, String sourceEntryId})>[];
        for (final scopeId in RuleChoiceSemantics.scopeEntryIdsFor(
          sourceEntryId,
          entries,
        )) {
          final found = RuleChoiceSemantics.definitionForKey(
            '$scopeId#$choiceId',
            entries: entries,
          );
          if (found != null) {
            definitions.add((
              definition: found.definition,
              sourceEntryId: found.sourceEntryId,
            ));
          }
        }
        if (definitions.isEmpty) {
          errors.add(
            ContentValidationError(
              path: '$itemPath.choice',
              message:
                  'requires 引用的选择 "$choiceId" 不存在于本条目及其祖先'
                  '（invalidRequires）',
            ),
          );
          continue;
        }
        final option = requirement.option;
        if (option == null) continue;
        final candidateIds = <String>{
          for (final found in definitions)
            ...RuleChoiceSemantics.candidatesFor(
              found.definition,
              entries: entries,
              sourceEntryId: found.sourceEntryId,
            ).map((candidate) => candidate.id),
        };
        if (!candidateIds.contains(option)) {
          errors.add(
            ContentValidationError(
              path: '$itemPath.option',
              message:
                  'requires 引用的选项 "$option" 不在选择 "$choiceId" 的候选集内'
                  '（invalidRequires）',
            ),
          );
        }
      }
    }

    /// **值类型选择候选校验的唯一实现点**（§5.1 `unknownSkill` /
    /// `unknownAbility` / `invalidSkillCount` / `invalidAutoGrant`）。
    ///
    /// 候选枚举只走 [RuleChoiceSemantics.candidatesFor]，自动授予只走
    /// [RuleChoiceSemantics.autoGrantsFor]——与 UI、引擎同一份判据。这样"导入期
    /// 校验 label、运行期使用 id"的分叉不会再让"声明了但静默无效"通过：运行期
    /// 由自动授予把 `candidate.id` 变成 `skill:<id>` / `ability:<id>`，所以只有
    /// `id` 落在档案 `skills` / `abilities` 内才算真的可用。
    ///
    /// 显式写了 `grants` 的候选不在这里校验（`_validateGrantFormulas` 管它们的
    /// formula / 属性键），因为它不经过自动推断路径。
    void validateValueChoiceCandidates(
      RuleChoiceDefinition choice,
      String choicePath,
    ) {
      if (!choice.isValueTypeChoice) return;
      final candidates = RuleChoiceSemantics.candidatesFor(
        choice,
        entries: entries,
        sourceEntryId: sourceEntryId,
      );
      for (final candidate in candidates) {
        final optionIndex = choice.options.indexWhere(
          (option) => option.id == candidate.id,
        );
        if (optionIndex < 0) continue;
        final optionPath = '$choicePath.options[$optionIndex]';
        if (candidate.grants.isNotEmpty) continue;
        final inferred = _autoGrantsForOption(
          optionType: choice.optionType,
          optionId: candidate.id,
          data: candidate.data,
          path: optionPath,
        );
        if (inferred.error != null) {
          errors.add(inferred.error!);
          continue;
        }
        for (final grant in inferred.grants!) {
          final target = grant.target;
          if (target == null) continue;
          if (grant.kind == RuleGrantKind.proficiency &&
              target.startsWith('skill:') &&
              !skillNames.contains(target.substring('skill:'.length))) {
            errors.add(
              ContentValidationError(
                path: optionPath,
                message: '未知技能 "${candidate.id}"（unknownSkill）',
              ),
            );
          } else if (grant.kind == RuleGrantKind.ability &&
              !abilityKeys.contains(target)) {
            errors.add(
              ContentValidationError(
                path: optionPath,
                message:
                    '未知属性键 "${candidate.id}"，可用：'
                    '${abilityKeys.join(', ')}（unknownAbility）',
              ),
            );
          }
        }
      }
      if (choice.optionType == RuleChoiceDefinition.skillOptionType) {
        final candidateCount = candidates.length;
        if (choice.minimum > candidateCount) {
          errors.add(
            ContentValidationError(
              path: '$choicePath.minimum',
              message:
                  '技能选择的数量必须为 0..$candidateCount（invalidSkillCount）',
            ),
          );
        }
        if (choice.maximum > candidateCount) {
          errors.add(
            ContentValidationError(
              path: '$choicePath.maximum',
              message:
                  '技能选择的数量必须为 0..$candidateCount（invalidSkillCount）',
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
                message:
                    'rule choice option "$entryId" does not exist'
                    '（invalidOptionRef）',
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
                    'rule choice option "$entryId" does not satisfy its type, '
                    'tag, or level filters（invalidOptionRef）',
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
                message:
                    'recommended rule choice "$entryId" does not exist'
                    '（invalidOptionRef）',
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
                    'recommended rule choice "$entryId" does not satisfy its '
                    'type, tag, or level filters（invalidOptionRef）',
              ),
            );
          }
        }
        // §3.10 选择系统的取值/引用语义：值类型候选（skill / ability / …）与
        // `requires` 的引用，一律在这里按**解析后的定义**校验（值类型候选的
        // 唯一口径是解析层导出的 `RuleChoiceSemantics.candidatesFor`）。
        validateValueChoiceCandidates(choices[i], '$choicesPath[$i]');
        validateRequires(choices[i].requires, '$choicesPath[$i].requires');
        for (var j = 0; j < choices[i].options.length; j++) {
          validateRequires(
            choices[i].options[j].requires,
            '$choicesPath[$i].options[$j].requires',
          );
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

  /// 在解析 [ContentEntry] **之前**对条目原始 `rules` JSON 做形状/参照校验，
  /// 返回本条目是否已经产出**精确到字段**的 error。
  ///
  /// 为什么要有这一遍：解析层
  /// （[RuleGrantDefinition.fromJson] / [RuleChoiceDefinition.fromJson] /
  /// [RuleProgressionDefinition.fromJson]）只抛一条**没有位置**的
  /// [FormatException]；若原样降级成 `invalid entry: …`（path 只到条目），作者
  /// 拿不到出错字段，违反 §5.1 与 §10 第 5 条。这里的每条 error 都指向原始 JSON
  /// 的具体字段。
  ///
  /// 返回值的用途：调用方在 `catch` 里据此**不再**追加笼统的 `invalid entry`，
  /// 避免同一条输入报两次、淹没精确位置。
  ///
  /// 覆盖范围（§5.1）：`unknownGrantKind`、`unknownField`（选择对象的未知字段）、
  /// `unknownOptionType`、`invalidChoiceRange`、`duplicateOptionId`、
  /// `invalidValueOption`、`invalidAutoGrant`（条目类型的字符串元素）、
  /// `countsToward` 取值（`invalidCountsToward`）、`requires` 的形状/取值
  /// （`invalidRequires`）。
  ///
  /// **不覆盖**（仍走解析层笼统的 `invalid entry`，因为 §5.1 没有对应 code、
  /// 或属于"列表本身不是数组 / 元素不是对象"这类结构错误）：`rules.grants` /
  /// `rules.choices` / `progression[].grants` / `progression[].choices` 不是数组、
  /// grant 项不是对象或缺 `id`、`maximumOptionLevel` 越界（0..9）、未知
  /// `builderStep`、`repeatable` 非布尔、`group`/`help` 非非空字符串。
  ///
  /// **值类型候选的语义校验**（`unknownSkill` / `invalidSkillCount` /
  /// `unknownAbility` / `invalidAutoGrant`）不在这一遍：它们必须按
  /// [RuleChoiceSemantics.candidatesFor]（UI 与引擎的**唯一候选枚举点**）判定，
  /// 因此放在解析成功之后的 [_validateRuleReferences]（见
  /// [_validateValueChoiceCandidates]）。
  bool _validateRawEntryRules(
    Map<String, Object?> entryJson,
    String entryPath,
    List<ContentValidationError> errors,
  ) {
    final rawRules = entryJson['rules'];
    if (rawRules is! Map) return false;
    final rules = Map<String, Object?>.from(rawRules);
    final rulesPath = '$entryPath.rules';
    final before = errors.length;

    void checkChoices(Object? raw, String path) {
      if (raw is! List) return;
      for (var index = 0; index < raw.length; index++) {
        final item = raw[index];
        if (item is! Map) continue;
        _validateRawChoice(
          Map<String, Object?>.from(item),
          '$path[$index]',
          errors,
        );
      }
    }

    _validateRawGrantKinds(rules['grants'], '$rulesPath.grants', errors);
    checkChoices(rules['choices'], '$rulesPath.choices');

    final progression = rules['progression'];
    if (progression == null) return errors.length > before;
    if (progression is! List) {
      errors.add(
        ContentValidationError(
          path: '$rulesPath.progression',
          message: 'progression 必须是数组（invalidTable）',
        ),
      );
      return errors.length > before;
    }
    for (var index = 0; index < progression.length; index++) {
      final step = progression[index];
      if (step is! Map) continue;
      final stepPath = '$rulesPath.progression[$index]';
      if (step.containsKey('level')) {
        errors.add(
          ContentValidationError(
            path: '$stepPath.level',
            message:
                'progression 统一用 levels 数组声明等级，不再接受 level'
                '（unknownField）',
          ),
        );
      }
      _validateRawProgressionLevels(step['levels'], '$stepPath.levels', errors);
      _validateRawGrantKinds(step['grants'], '$stepPath.grants', errors);
      checkChoices(step['choices'], '$stepPath.choices');
    }
    return errors.length > before;
  }

  /// 所有 grants 的 `kind` 必须在 [RuleGrantKind] 枚举内（§3.5、§5.1
  /// `unknownGrantKind`），path 精确到出错的 `kind` 字段。
  void _validateRawGrantKinds(
    Object? raw,
    String path,
    List<ContentValidationError> errors,
  ) {
    if (raw is! List) return;
    final allowed = RuleGrantKind.values.map((kind) => kind.name).toList();
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      if (item is! Map) continue;
      final kind = item['kind'];
      if (kind is String &&
          RuleGrantKind.values.any((candidate) => candidate.name == kind)) {
        continue;
      }
      final hint = kind == 'resource' ? '，职业资源请改用 classRules.resources' : '';
      errors.add(
        ContentValidationError(
          path: '$path[$index].kind',
          message:
              '未知 grant kind "$kind"$hint，合法值：${allowed.join(' / ')}'
              '（unknownGrantKind）',
        ),
      );
    }
  }

  /// `progression[].levels` 的形状（§5.1 `invalidTable`：1..20、非空、不重复）。
  void _validateRawProgressionLevels(
    Object? raw,
    String path,
    List<ContentValidationError> errors,
  ) {
    if (raw is! List || raw.isEmpty) {
      errors.add(
        ContentValidationError(
          path: path,
          message: 'progression.levels 必须是非空数组，元素为 1..20 的整数（invalidTable）',
        ),
      );
      return;
    }
    final seen = <int>{};
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      final level = item is num ? item.toInt() : null;
      if (level == null || level < 1 || level > 20) {
        errors.add(
          ContentValidationError(
            path: '$path[$index]',
            message: 'progression 等级必须是 1..20 的整数：$item（invalidTable）',
          ),
        );
      } else if (!seen.add(level)) {
        errors.add(
          ContentValidationError(
            path: '$path[$index]',
            message: 'progression 等级不能重复：$level（invalidTable）',
          ),
        );
      }
    }
  }

  /// `invalidAutoGrant` 的**唯一产生点**（§5.1，决策 D1）。
  ///
  /// 判据与运行时**同源**：字符串简写能否推断 grants 完全由
  /// [RuleChoiceSemantics.autoGrantsFor] 决定（返回 `null` = 无法推断）。调用方
  /// 有两处，但都只是"哪个 optionType/选项要走这条路"的入口，判据与错误构造
  /// 只有这里一份：
  /// - `_validateRawChoice`：**条目类型**的字符串元素（决策 D1 的落点）；
  /// - `_validateValueChoiceCandidates`：值类型候选**没有显式 grants** 时（例如
  ///   `ability` 选项写了非正整数的 `data.value`）。
  ({List<RuleGrantDefinition>? grants, ContentValidationError? error})
  _autoGrantsForOption({
    required String optionType,
    required String optionId,
    required Map<String, Object?> data,
    required String path,
  }) {
    final grants = RuleChoiceSemantics.autoGrantsFor(
      optionType: optionType,
      optionId: optionId,
      data: data,
    );
    if (grants != null) return (grants: grants, error: null);
    return (
      grants: null,
      error: ContentValidationError(
        path: path,
        message:
            'optionType "$optionType" 的选项 "$optionId" 缺少 grants，'
            '且无法自动推断（invalidAutoGrant）',
      ),
    );
  }

  /// 一条选择的形状/取值校验（§5.1），在**解析之前**对原始 JSON 执行，因此
  /// `repeatable` / `group` / `help` / 内联选项 `grants` 一律放行（它们已有真实
  /// 运行时语义）；这里只保留"声明了但取值/形状无效"的精确诊断：
  /// `unknownField`、`unknownOptionType`、`invalidChoiceRange`、
  /// `invalidValueOption`、`duplicateOptionId`、`invalidAutoGrant`、
  /// `invalidCountsToward`、`invalidRequires`（形状/取值）。
  void _validateRawChoice(
    Map<String, Object?> choice,
    String path,
    List<ContentValidationError> errors,
  ) {
    // §5.1 `unknownField`：字段名拼错（例如 `grup`）在解析期被静默忽略——解析层
    // 只读白名单键。这里在原始 JSON 上按 [kRuleChoiceFields]（选择对象字段全集）
    // 显式报错，path 精确到该键，不静默。
    for (final key in choice.keys) {
      if (kRuleChoiceFields.contains(key)) continue;
      errors.add(
        ContentValidationError(
          path: '$path.$key',
          message: '未知字段 $path.$key（unknownField）',
        ),
      );
    }

    final optionType = choice['optionType'];
    final isValueType = isValueOptionType(optionType);
    if (optionType is! String || !_knownOptionTypes.contains(optionType)) {
      errors.add(
        ContentValidationError(
          path: '$path.optionType',
          message:
              '未知选项类型 "$optionType"，条目类型见内容 schema，值类型：'
              '${kValueOptionTypes.join(' / ')}（unknownOptionType）',
        ),
      );
    }

    // 畸形输入（`"minimum": "2"` / `{}` / 显式 `null`）不得让这里抛 `_TypeError`：
    // `_validateRawEntryRules` 的调用点在解析 `try` 之外，UI 只接 `FormatException`，
    // 一次强转就会把导入变成未捕获异常。改为安全取值 + 精确到字段的诊断。
    final rawMinimum = choice['minimum'];
    final rawMaximum = choice['maximum'];
    if (choice.containsKey('minimum') && rawMinimum is! num) {
      errors.add(
        ContentValidationError(
          path: '$path.minimum',
          message: 'minimum 必须是数字：$rawMinimum（invalidChoiceRange）',
        ),
      );
    }
    if (choice.containsKey('maximum') && rawMaximum is! num) {
      errors.add(
        ContentValidationError(
          path: '$path.maximum',
          message: 'maximum 必须是数字：$rawMaximum（invalidChoiceRange）',
        ),
      );
    }
    final minimum = rawMinimum is num ? rawMinimum.toInt() : 1;
    final maximum = rawMaximum is num ? rawMaximum.toInt() : minimum;
    if (maximum < minimum) {
      errors.add(
        ContentValidationError(
          path: '$path.maximum',
          message: 'maximum 不能小于 minimum（invalidChoiceRange）',
        ),
      );
    } else if (minimum < 0) {
      errors.add(
        ContentValidationError(
          path: '$path.minimum',
          message: 'minimum 不能为负（invalidChoiceRange）',
        ),
      );
    }

    final rawEntryIds = choice['optionEntryIds'];
    final entryIds = rawEntryIds is List
        ? rawEntryIds.map((item) => '$item').toSet()
        : const <String>{};
    final rawTags = choice['optionTags'];
    final tags = rawTags is List
        ? rawTags.map((item) => '$item').toList(growable: false)
        : const <String>[];
    // §5.1 `invalidValueOption` 的两个方向里，这里只实现**值类型侧**：值类型
    // 只允许内联 `options`（§3.10.3-2），写 `optionEntryIds` / `optionTags` 或
    // 干脆没有 `options` 都算"声明了用不了"。
    //
    // **不**把"条目类型选择 `options` 与 `optionEntryIds` 同时为空"一律判错：
    // 条目类型可以靠 `optionTags`（法术选择）或 `relations`（子职选择，见
    // `RuleChoiceResolver._isSubclassOf`）拿候选，契约 §3.10.2 的
    // `equipmentBundle` 示例本身也没有任何候选载体——按字面实现会拒绝内置
    // 包里的 12 条子职选择。
    if (isValueType) {
      if (entryIds.isNotEmpty) {
        errors.add(
          ContentValidationError(
            path: '$path.optionEntryIds',
            message:
                '值类型选择不允许 optionEntryIds，候选必须写在 options'
                '（invalidValueOption）',
          ),
        );
      }
      if (tags.isNotEmpty) {
        errors.add(
          ContentValidationError(
            path: '$path.optionTags',
            message:
                '值类型选择不允许 optionTags，候选必须写在 options'
                '（invalidValueOption）',
          ),
        );
      }
      if (choice['options'] == null) {
        errors.add(
          ContentValidationError(
            path: '$path.options',
            message: '值类型选择必须用内联 options 声明候选（invalidValueOption）',
          ),
        );
      }
    }

    final rawOptions = choice['options'];
    if (rawOptions != null) {
      if (rawOptions is! List) {
        errors.add(
          ContentValidationError(
            path: '$path.options',
            message: 'options 必须是数组（invalidValueOption）',
          ),
        );
      } else {
        final seenIds = <String>{};
        for (var index = 0; index < rawOptions.length; index++) {
          final item = rawOptions[index];
          final itemPath = '$path.options[$index]';
          String? id;
          var idPath = itemPath;
          if (item is String) {
            final text = item.trim();
            if (text.isEmpty) {
              errors.add(
                ContentValidationError(
                  path: itemPath,
                  message: '选项不能为空（invalidValueOption）',
                ),
              );
              continue;
            }
            id = text;
            // §5.1 `invalidAutoGrant`（决策 D1）：**条目类型**的字符串元素没有
            // 可推断的 grants，作者必须写成对象显式给 grants。判据与运行时同源
            // （[RuleChoiceSemantics.autoGrantsFor] 返回 null）；值类型永远能推断
            // （`language` / `damageType` / `weaponMastery` / `value` 返回空列表，
            // 属"只记录选择"，不算无法推断）。
            if (optionType is String) {
              final inferred = _autoGrantsForOption(
                optionType: optionType,
                optionId: text,
                data: const <String, Object?>{},
                path: itemPath,
              );
              if (inferred.error != null) errors.add(inferred.error!);
            }
          } else if (item is Map) {
            final option = Map<String, Object?>.from(item);
            final rawId = option['id'];
            idPath = '$itemPath.id';
            if (rawId is! String || rawId.trim().isEmpty) {
              errors.add(
                ContentValidationError(
                  path: idPath,
                  message: '选项必须有非空 id（invalidValueOption）',
                ),
              );
            } else {
              id = rawId.trim();
            }
            if (option.containsKey('grants')) {
              // §3.10.2 内联选项的 grants 是**真实生效**的授予来源（
              // `RuleChoiceSemantics.grantsForSelection` 展开）；这里只做 kind 枚举
              // 校验，formula/属性键的校验在 `_validateGrantFormulas`。
              _validateRawGrantKinds(
                option['grants'],
                '$itemPath.grants',
                errors,
              );
            }
          } else {
            errors.add(
              ContentValidationError(
                path: itemPath,
                message: '选项必须是字符串或对象（invalidValueOption）',
              ),
            );
            continue;
          }
          if (id != null) {
            if (!seenIds.add(id)) {
              errors.add(
                ContentValidationError(
                  path: idPath,
                  message: '选项 id "$id" 重复（duplicateOptionId）',
                ),
              );
            } else if (entryIds.contains(id)) {
              errors.add(
                ContentValidationError(
                  path: idPath,
                  message:
                      '选项 id "$id" 与 optionEntryIds 冲突'
                      '（duplicateOptionId）',
                ),
              );
            }
          }
        }
      }
    }

    // `countsToward` 的取值校验（§5.1 `invalidCountsToward`）：合法值是具名额度池
    // 或省略。判据的唯一实现点是 [isCountsTowardPool]（解析层同源）。
    final countsToward = choice['countsToward'];
    if (!isCountsTowardPool(countsToward)) {
      errors.add(
        ContentValidationError(
          path: '$path.countsToward',
          message:
              'countsToward 必须是 ${kCountsTowardPools.join(' / ')} 或省略'
              '（invalidCountsToward）',
        ),
      );
    }

    // `requires` 的**形状/取值**校验（§5.1 `invalidRequires`）。判据本体是
    // [validateRuleRequiresJson]（解析层 `RuleRequiresDefinition.fromJson` 调用
    // **同一个**纯函数），这里只负责把 `issue.field` 拼成精确 path——两处因此
    // 不可能分叉。`ability` 形态缺 `minimum`、跨形态字段（choice 形态写 minimum /
    // ability 形态写 option）、未知字段都在这里报错，不再降级成解析层的
    // `$.entries[i]` + `invalid entry`。**引用**（`choice` / `option` 是否存在、
    // `ability` 键是否在档案内）在第二遍 [_validateRuleReferences] 里校验，那里有
    // 全部条目与 `relations` 祖先链。
    if (choice.containsKey('requires')) {
      final rawRequires = choice['requires'];
      if (rawRequires is! List) {
        errors.add(
          ContentValidationError(
            path: '$path.requires',
            message: 'requires 必须是数组（invalidRequires）',
          ),
        );
      } else {
        for (var index = 0; index < rawRequires.length; index++) {
          final item = rawRequires[index];
          final itemPath = '$path.requires[$index]';
          if (item is! Map) {
            errors.add(
              ContentValidationError(
                path: itemPath,
                message: 'requires 的元素必须是对象（invalidRequires）',
              ),
            );
            continue;
          }
          final issue = validateRuleRequiresJson(
            Map<String, Object?>.from(item),
          );
          if (issue == null) continue;
          final field = issue.field;
          errors.add(
            ContentValidationError(
              path: field == null ? itemPath : '$itemPath.$field',
              message: '${issue.message}（invalidRequires）',
            ),
          );
        }
      }
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
    required CharacterRuleDefinition? entryRuleDefinition,
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
        // 档案侧已提供 `spellcasting` 时条目不写它不是缺省（字段级继承，§3.6）。
        archiveSpellcasting: archiveRules?.spellcasting,
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
