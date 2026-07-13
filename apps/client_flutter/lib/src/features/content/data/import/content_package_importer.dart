import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_import_report.dart';
import '../../domain/content_package_manifest.dart';
import '../local/content_repository.dart';

class ContentPackageImporter {
  ContentPackageImporter(this._repository);
  final ContentRepository _repository;

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
      errors.add(const ContentValidationError(
        path: r'$',
        message: 'Root must be a JSON object',
      ));
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
      errors.add(const ContentValidationError(
        path: r'$.formatVersion',
        message: 'formatVersion is required',
      ));
    } else if (formatVersionValue is! num || formatVersionValue.toInt() != 1) {
      errors.add(const ContentValidationError(
        path: r'$.formatVersion',
        message: 'formatVersion must be 1',
      ));
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

    // Validate entryCount
    final entryCountValue = json['entryCount'];
    var declaredEntryCount = -1;
    if (entryCountValue == null) {
      errors.add(const ContentValidationError(
        path: r'$.entryCount',
        message: 'entryCount is required',
      ));
    } else if (entryCountValue is! num) {
      errors.add(const ContentValidationError(
        path: r'$.entryCount',
        message: 'entryCount must be a number',
      ));
    } else {
      declaredEntryCount = entryCountValue.toInt();
    }

    // Parse and validate entries
    final entriesJson = json['entries'];
    final entries = <ContentEntry>[];
    final entryIds = <String>{};

    if (entriesJson is! List<Object?>) {
      errors.add(const ContentValidationError(
        path: r'$.entries',
        message: 'entries must be a list',
      ));
    } else {
      // Check entryCount match
      if (declaredEntryCount >= 0 &&
          declaredEntryCount != entriesJson.length) {
        errors.add(ContentValidationError(
          path: r'$.entryCount',
          message:
              'entryCount ($declaredEntryCount) does not match actual entries (${entriesJson.length})',
        ));
      }

      // First pass: parse entries and validate IDs
      final parsedEntries = <int, ContentEntry>{};

      for (var i = 0; i < entriesJson.length; i++) {
        final entryJson = entriesJson[i];
        final entryPath = '\$.entries[$i]';

        if (entryJson is! Map<String, Object?>) {
          errors.add(ContentValidationError(
            path: entryPath,
            message: 'entry must be a JSON object',
          ));
          continue;
        }

        // Validate entry ID prefix
        final entryId = entryJson['id'];
        if (entryId is String && packageId.isNotEmpty) {
          if (!entryId.startsWith('$packageId:')) {
            errors.add(ContentValidationError(
              path: '$entryPath.id',
              message:
                  'entry ID "$entryId" must start with "$packageId:"',
            ));
          }
          if (entryIds.contains(entryId)) {
            errors.add(ContentValidationError(
              path: '$entryPath.id.duplicate',
              message: 'duplicate entry ID: $entryId',
            ));
          } else {
            entryIds.add(entryId);
          }
        }

        // Parse the entry
        try {
          final entry = ContentEntry.fromJson(entryJson);
          parsedEntries[i] = entry;
          entries.add(entry);
        } catch (e) {
          errors.add(ContentValidationError(
            path: entryPath,
            message: 'invalid entry: $e',
          ));
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
              errors.add(ContentValidationError(
                path: '\$.entries[$i].body[$j].targetId',
                message:
                    'link target "${block.targetId}" does not exist in package',
              ));
            }
          }
        }
      }
    }

    return _buildReport(
      errors: errors,
      contentHash: contentHash,
      formatVersion: formatVersion,
      packageId: packageId,
      packageName: packageName,
      version: version,
      locale: locale,
      system: system,
      entryCount: entries.length,
      entries: entries,
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

  String? _validateNonEmptyString(
    Object? value,
    String path,
    List<ContentValidationError> errors,
  ) {
    if (value is! String || value.isEmpty) {
      errors.add(ContentValidationError(
        path: path,
        message: '$path must be a non-empty string',
      ));
      return null;
    }
    return value;
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
