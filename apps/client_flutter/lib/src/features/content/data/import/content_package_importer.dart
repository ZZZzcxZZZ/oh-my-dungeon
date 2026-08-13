import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_import_report.dart';
import '../../domain/content_package_manifest.dart';
import '../../domain/content_schema_registry.dart';
import '../../../rules/domain/character_rule_definition.dart';
import '../../../rules/domain/rule_choice_resolver.dart';
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

    // Validate formatVersion
    final formatVersionValue = json['formatVersion'];
    var formatVersion = 0;
    if (formatVersionValue == null) {
      errors.add(
        const ContentValidationError(
          path: r'$.formatVersion',
          message: 'formatVersion is required',
        ),
      );
    } else if (formatVersionValue is! num ||
        !const {1, 2}.contains(formatVersionValue.toInt())) {
      errors.add(
        const ContentValidationError(
          path: r'$.formatVersion',
          message: 'formatVersion must be 1 or 2',
        ),
      );
    } else {
      formatVersion = formatVersionValue.toInt();
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

        // Parse the entry
        try {
          final normalizedJson = Map<String, Object?>.from(entryJson);
          final sourceType = '${normalizedJson['type'] ?? ''}';
          final normalizedType = ContentSchemaRegistry.defaults.normalizeType(
            sourceType,
          );
          normalizedJson['type'] = normalizedType;
          final structured = normalizedJson['structured'];
          if (structured is Map) {
            normalizedJson['structured'] = ContentSchemaRegistry.defaults
                .normalizeStructured(
                  normalizedType,
                  Map<String, Object?>.from(structured),
                );
          }
          final entry = ContentEntry.fromJson(normalizedJson);
          parsedEntries[i] = entry;
          entries.add(entry);
        } catch (e) {
          errors.add(
            ContentValidationError(
              path: entryPath,
              message: 'invalid entry: $e',
            ),
          );
        }
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
      }
    }

    final migratedEntries = errors.isEmpty
        ? const LegacyClassFeatureRulesMigrator().migrate(entries)
        : entries;
    return _buildReport(
      errors: errors,
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

  ContentImportReport _buildReport({
    required List<ContentValidationError> errors,
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
      assets: assets,
      contentHash: contentHash,
    );
  }
}
