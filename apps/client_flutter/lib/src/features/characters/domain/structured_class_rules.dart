import '../../content/domain/content_entry.dart';
import 'dnd5e_rules.dart';

class StructuredSkillChoice {
  const StructuredSkillChoice({required this.count, required this.options});

  static const empty = StructuredSkillChoice(count: 0, options: []);

  final int count;
  final List<String> options;
}

abstract final class StructuredClassRules {
  static Set<String> savingThrowAbilities(ContentEntry? entry) {
    final structured = entry?.structured;
    if (structured == null) return const <String>{};
    final normalized = structured['savingThrowAbilities'];
    if (normalized is Iterable) {
      return normalized
          .map((value) => _abilityKey('$value'))
          .whereType<String>()
          .toSet();
    }

    final legacy = '${structured['savingThrows'] ?? ''}';
    return {
      for (final ability in Dnd5eRules.abilityLabels.entries)
        if (legacy.contains(ability.value)) ability.key,
    };
  }

  static StructuredSkillChoice skillChoice(ContentEntry? entry) {
    final structured = entry?.structured;
    if (structured == null) return StructuredSkillChoice.empty;
    final normalized = structured['skillChoice'];
    if (normalized is Map) {
      final map = Map<String, Object?>.from(normalized);
      final options = _validSkills(map['options']);
      final count = (map['count'] as num?)?.toInt() ?? 0;
      return StructuredSkillChoice(
        count: count.clamp(0, options.length),
        options: options,
      );
    }

    final legacy = '${structured['skills'] ?? ''}'.trim();
    final freeChoice = RegExp(r'任选\s*(\d+)\s*项').firstMatch(legacy);
    if (freeChoice != null) {
      final options = Dnd5eRules.skills
          .map((skill) => skill.name)
          .toList(growable: false);
      final count = int.tryParse(freeChoice.group(1) ?? '') ?? 0;
      return StructuredSkillChoice(
        count: count.clamp(0, options.length),
        options: options,
      );
    }
    final match = RegExp(
      r'选择\s*(\d+)\s*项\s*[：:]?\s*(.*)',
      dotAll: true,
    ).firstMatch(legacy);
    if (match == null) return StructuredSkillChoice.empty;
    final count = int.tryParse(match.group(1) ?? '') ?? 0;
    final options = _validSkills(
      (match.group(2) ?? '').split(RegExp(r'[、，,；;]|或')),
    );
    return StructuredSkillChoice(
      count: count.clamp(0, options.length),
      options: options,
    );
  }

  static String? _abilityKey(String value) {
    final normalized = value.trim().toLowerCase();
    if (Dnd5eRules.abilityLabels.containsKey(normalized)) return normalized;
    for (final ability in Dnd5eRules.abilityLabels.entries) {
      if (normalized == ability.value.toLowerCase()) return ability.key;
    }
    return null;
  }

  static List<String> _validSkills(Object? raw) {
    if (raw is! Iterable) return const [];
    final known = Dnd5eRules.skills.map((skill) => skill.name).toSet();
    const aliases = <String, String>{
      '特技': '杂技',
      '体操': '杂技',
      '游说': '说服',
      '医疗': '医药',
      '生存': '求生',
    };
    return raw
        .map((value) => '$value'.trim())
        .map((value) => aliases[value] ?? value)
        .where(known.contains)
        .toSet()
        .toList(growable: false);
  }
}
