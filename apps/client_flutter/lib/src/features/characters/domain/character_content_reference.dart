class CharacterContentReference {
  const CharacterContentReference({
    required this.slot,
    required this.entryKey,
    required this.sourceRevision,
    this.snapshot = const <String, Object?>{},
  });
  final String slot;
  final String entryKey;
  final int sourceRevision;
  final Map<String, Object?> snapshot;

  Map<String, Object?> toJson() => {
        'slot': slot,
        'entryKey': entryKey,
        'sourceRevision': sourceRevision,
        'snapshot': snapshot,
      };

  factory CharacterContentReference.fromJson(Map<String, Object?> json) {
    return CharacterContentReference(
      slot: json['slot']! as String,
      entryKey: json['entryKey']! as String,
      sourceRevision: (json['sourceRevision'] as num).toInt(),
      snapshot: json['snapshot'] is Map
          ? Map<String, Object?>.from(json['snapshot'] as Map)
          : const <String, Object?>{},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterContentReference &&
          slot == other.slot &&
          entryKey == other.entryKey &&
          sourceRevision == other.sourceRevision;

  @override
  int get hashCode => Object.hash(slot, entryKey, sourceRevision);
}
