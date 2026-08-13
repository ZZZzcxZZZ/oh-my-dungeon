import 'dart:typed_data';

import 'local_backup_models.dart';

/// Service for exporting, previewing, and restoring local app data.
///
/// The archive is an `.ohmydungeon-backup` ZIP containing:
/// - `manifest.json` — format version, counts, total size, and SHA-256
/// - `database.json` — personal data (no tokens, no campaign cache)
/// - `assets/<packageId>/<relativePath>` — binary content assets
abstract interface class LocalDataArchiveService {
  /// Exports all personal data into a versioned archive.
  Future<Uint8List> exportArchive();

  /// Previews an archive, validating its structure and hash.
  Future<ArchivePreview> previewArchive(Uint8List bytes);

  /// Restores a previously-previewed archive atomically.
  Future<void> restoreArchive(ArchivePreview preview);

}
