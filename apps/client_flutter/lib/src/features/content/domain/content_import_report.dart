import 'dart:typed_data';

import 'content_entry.dart';

class ContentValidationError {
  final String path;
  final String message;
  const ContentValidationError({required this.path, required this.message});
}

class ContentImportReport {
  final bool valid;
  final int formatVersion;
  final String packageId;
  final String packageName;
  final String version;
  final String locale;
  final String system;
  final int entryCount;
  final List<ContentEntry> entries;
  final List<ContentValidationError> errors;
  final Map<String, Uint8List> assets;
  final String contentHash;
  const ContentImportReport({
    required this.valid,
    required this.formatVersion,
    required this.packageId,
    required this.packageName,
    required this.version,
    required this.locale,
    required this.system,
    required this.entryCount,
    required this.entries,
    required this.errors,
    required this.assets,
    required this.contentHash,
  });
}
