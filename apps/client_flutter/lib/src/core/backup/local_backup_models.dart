import 'dart:typed_data';

/// Manifest embedded in the backup archive.
class LocalBackupManifest {
  const LocalBackupManifest({
    required this.formatVersion,
    required this.createdAt,
    required this.clientVersion,
    required this.serverProfileCount,
    required this.packageCount,
    required this.entryCount,
    required this.assetCount,
    required this.characterCount,
    required this.totalSize,
    required this.sha256,
  });

  final int formatVersion;
  final String createdAt;
  final String clientVersion;
  final int serverProfileCount;
  final int packageCount;
  final int entryCount;
  final int assetCount;
  final int characterCount;
  final int totalSize;
  final String sha256;

  Map<String, Object?> toJson() => {
        'formatVersion': formatVersion,
        'createdAt': createdAt,
        'clientVersion': clientVersion,
        'serverProfileCount': serverProfileCount,
        'packageCount': packageCount,
        'entryCount': entryCount,
        'assetCount': assetCount,
        'characterCount': characterCount,
        'totalSize': totalSize,
        'sha256': sha256,
      };

  factory LocalBackupManifest.fromJson(Map<String, Object?> json) {
    return LocalBackupManifest(
      formatVersion: json['formatVersion']! as int,
      createdAt: json['createdAt']! as String,
      clientVersion: json['clientVersion']! as String,
      serverProfileCount: json['serverProfileCount']! as int,
      packageCount: json['packageCount']! as int,
      entryCount: json['entryCount']! as int,
      assetCount: json['assetCount']! as int,
      characterCount: json['characterCount']! as int,
      totalSize: json['totalSize']! as int,
      sha256: json['sha256']! as String,
    );
  }
}

/// Preview of a backup archive, validated before restore.
class ArchivePreview {
  const ArchivePreview({
    required this.valid,
    required this.manifest,
    required this.bytes,
    this.error,
  });

  final bool valid;
  final LocalBackupManifest? manifest;
  final Uint8List bytes;
  final String? error;

  int get characterCount => manifest?.characterCount ?? 0;
  int get packageCount => manifest?.packageCount ?? 0;
  int get entryCount => manifest?.entryCount ?? 0;
  int get assetCount => manifest?.assetCount ?? 0;
  int get totalSize => manifest?.totalSize ?? 0;
}
