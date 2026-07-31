import '../../content/domain/content_entry.dart';

class SpellSelectionRules {
  const SpellSelectionRules({
    required this.configured,
    this.mode,
    this.ability,
    this.listTags = const [],
    this.maximumSpellLevel = -1,
    this.maximum,
    this.maximumCantrips,
    this.maximumLeveledSpells,
  });

  const SpellSelectionRules.unconfigured()
    : configured = false,
      mode = null,
      ability = null,
      listTags = const [],
      maximumSpellLevel = -1,
      maximum = null,
      maximumCantrips = null,
      maximumLeveledSpells = null;

  final bool configured;
  final String? mode;
  final String? ability;
  final List<String> listTags;
  final int maximumSpellLevel;
  final int? maximum;
  final int? maximumCantrips;
  final int? maximumLeveledSpells;
}

abstract final class SpellSelectionPolicy {
  static SpellSelectionRules rulesFor({
    required ContentEntry? classEntry,
    required int characterLevel,
  }) {
    final raw = classEntry?.structured['spellcasting'];
    if (raw is! Map) return const SpellSelectionRules.unconfigured();

    final spellcasting = Map<String, Object?>.from(raw);
    final progression = _mapList(spellcasting['progression']);
    final level = characterLevel.clamp(1, 20);
    Map<String, Object?>? activeRow;
    for (final row in progression) {
      final rowLevel = _intValue(row['level']);
      if (rowLevel == null || rowLevel > level) continue;
      if (activeRow == null ||
          rowLevel > (_intValue(activeRow['level']) ?? -1)) {
        activeRow = row;
      }
    }

    final maximumSpellLevel = _intValue(
      activeRow?['maximumSpellLevel'] ?? spellcasting['maximumSpellLevel'],
    );
    if (maximumSpellLevel == null) {
      return const SpellSelectionRules.unconfigured();
    }

    return SpellSelectionRules(
      configured: true,
      mode: _stringValue(spellcasting['mode']),
      ability: _stringValue(spellcasting['ability']),
      listTags: _stringList(spellcasting['listTags']),
      maximumSpellLevel: maximumSpellLevel,
      maximum: _intValue(activeRow?['maximum'] ?? spellcasting['maximum']),
      maximumCantrips: _intValue(
        activeRow?['maximumCantrips'] ?? spellcasting['maximumCantrips'],
      ),
      maximumLeveledSpells: _intValue(
        activeRow?['maximumLeveledSpells'] ??
            spellcasting['maximumLeveledSpells'],
      ),
    );
  }

  static List<ContentEntry> eligibleSpells({
    required Iterable<ContentEntry> entries,
    required SpellSelectionRules rules,
  }) {
    if (!rules.configured) return const [];

    final options = entries
        .where((entry) {
          if (entry.type != 'spell') return false;
          final level = spellLevel(entry);
          if (level == null || level > rules.maximumSpellLevel) return false;
          if (rules.listTags.isEmpty) return true;
          return entry.tags.any(rules.listTags.contains);
        })
        .toList(growable: false);

    return options..sort((left, right) {
      final byLevel = spellLevel(left)!.compareTo(spellLevel(right)!);
      return byLevel != 0 ? byLevel : left.name.compareTo(right.name);
    });
  }

  static int? spellLevel(ContentEntry entry) {
    return _intValue(entry.structured['level']);
  }

  static String spellSchool(ContentEntry entry) {
    return '${entry.structured['school'] ?? ''}'.trim();
  }

  static List<Map<String, Object?>> _mapList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static String? _stringValue(Object? value) {
    final result = '$value'.trim();
    return value == null || result.isEmpty ? null : result;
  }
}
