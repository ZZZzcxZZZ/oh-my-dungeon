class ContentPackageManifest {
  const ContentPackageManifest({
    required this.formatVersion,
    required this.id,
    required this.name,
    required this.version,
    required this.locale,
    required this.system,
    required this.entryCount,
    this.priority = 0,
    this.contentHash = '',
  });

  final int formatVersion;
  final String id;
  final String name;
  final String version;
  final String locale;
  final String system;
  final int entryCount;

  /// 规则覆盖优先级（S3 决策 D2）：0..1000，缺省 0。
  ///
  /// 生效 tier = `kEntryTier`(100) + priority。**缺省 0 保证旧包行为逐项不变**：
  /// 不写 priority 的包 tier 仍是 100，与引入该字段之前完全一致。
  final int priority;
  final String contentHash;

  factory ContentPackageManifest.fromJson(Map<String, Object?> json) {
    final formatVersion = json['formatVersion'];
    final id = json['id'];
    final name = json['name'];
    final version = json['version'];
    final locale = json['locale'];
    final system = json['system'];
    final entryCount = json['entryCount'];
    if (formatVersion == null ||
        id == null ||
        name == null ||
        version == null ||
        locale == null ||
        system == null ||
        entryCount == null) {
      throw FormatException(
        'Missing required ContentPackageManifest fields: $json',
      );
    }
    // 缺失 → 0（旧包）；类型不对抛 FormatException，**绝不**静默取默认值——那会
    // 让写了 "40" 的包以为自己的勘误生效了，实际排在内置档案之后。范围与整数性
    // 的精确校验（`$.priority` + `invalidPriority`）在导入器里，这里只做类型。
    final priority = json['priority'];
    if (priority != null && priority is! int) {
      throw FormatException(
        'Invalid ContentPackageManifest priority (must be an int): $priority',
      );
    }
    return ContentPackageManifest(
      formatVersion: (formatVersion as num).toInt(),
      id: id as String,
      name: name as String,
      version: version as String,
      locale: locale as String,
      system: system as String,
      entryCount: (entryCount as num).toInt(),
      priority: priority as int? ?? 0,
      contentHash: json['contentHash'] as String? ?? '',
    );
  }

  ContentPackageManifest copyWith({int? priority, String? contentHash}) {
    return ContentPackageManifest(
      formatVersion: formatVersion,
      id: id,
      name: name,
      version: version,
      locale: locale,
      system: system,
      entryCount: entryCount,
      priority: priority ?? this.priority,
      contentHash: contentHash ?? this.contentHash,
    );
  }

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'id': id,
    'name': name,
    'version': version,
    'locale': locale,
    'system': system,
    'entryCount': entryCount,
    // priority 始终写出（0 也写）：manifest 往返自洽，读回后 tier 不变。
    'priority': priority,
    if (contentHash.isNotEmpty) 'contentHash': contentHash,
  };
}
