import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../../rules/domain/character_rule_definition.dart';

/// Converts the early `structured.features` class format into executable rules.
class LegacyClassFeatureRulesMigrator {
  const LegacyClassFeatureRulesMigrator();

  List<ContentEntry> migrate(List<ContentEntry> entries) {
    final result = <ContentEntry>[];
    final reservedIds = entries.map((entry) => entry.id).toSet();
    for (final entry in entries) {
      final migrated = _migrateClass(entry, reservedIds);
      result.add(migrated.classEntry);
      result.addAll(migrated.features);
    }
    return result;
  }

  _MigratedClass _migrateClass(ContentEntry entry, Set<String> reservedIds) {
    if (entry.type != 'class' || _hasFeatureProgression(entry.rules)) {
      return _MigratedClass(classEntry: entry);
    }
    final rawFeatures = entry.structured['features'];
    if (rawFeatures is! List) return _MigratedClass(classEntry: entry);

    final parsed = rawFeatures
        .whereType<String>()
        .map(_parseFeature)
        .whereType<_LegacyFeature>()
        .toList(growable: false);
    if (parsed.isEmpty) return _MigratedClass(classEntry: entry);

    final features = <ContentEntry>[];
    final grantsByLevel = <int, List<RuleGrantDefinition>>{};
    final levelOrdinals = <int, int>{};
    for (final feature in parsed) {
      final ordinal = (levelOrdinals[feature.level] ?? 0) + 1;
      levelOrdinals[feature.level] = ordinal;
      final id = _availableFeatureId(
        entry,
        feature.level,
        ordinal,
        reservedIds,
      );
      reservedIds.add(id);
      final slug = id.substring(id.indexOf(':class-feature/') + 15);
      features.add(
        ContentEntry(
          id: id,
          type: 'classFeature',
          slug: slug,
          name: feature.name,
          summary: feature.description,
          body: [ParagraphBlock(text: feature.description)],
          structured: {
            'classId': entry.id,
            'className': entry.name,
            'level': feature.level,
          },
          tags: {...entry.tags, 'class-feature'}.toList(growable: false),
          source: entry.source,
          relations: [ContentRelation(type: 'featureOf', targetId: entry.id)],
          revision: entry.revision,
        ),
      );
      grantsByLevel
          .putIfAbsent(feature.level, () => [])
          .add(
            RuleGrantDefinition(
              id: 'feature-${feature.level}-$ordinal',
              kind: RuleGrantKind.feature,
              label: feature.name,
              entryId: id,
            ),
          );
    }

    final existingRules = entry.rules ?? const CharacterRuleDefinition();
    final progression = <int, RuleProgressionDefinition>{
      for (final step in existingRules.progression) step.level: step,
    };
    for (final level in grantsByLevel.keys) {
      final existing = progression[level];
      progression[level] = RuleProgressionDefinition(
        level: level,
        grants: [...?existing?.grants, ...grantsByLevel[level]!],
        choices: existing?.choices ?? const [],
      );
    }
    final sortedProgression = progression.values.toList()
      ..sort((left, right) => left.level.compareTo(right.level));

    return _MigratedClass(
      classEntry: ContentEntry(
        id: entry.id,
        type: entry.type,
        slug: entry.slug,
        name: entry.name,
        body: entry.body,
        revision: entry.revision,
        aliases: entry.aliases,
        summary: entry.summary,
        structured: entry.structured,
        tags: entry.tags,
        source: entry.source,
        origin: entry.origin,
        relations: entry.relations,
        rules: CharacterRuleDefinition(
          grants: existingRules.grants,
          choices: existingRules.choices,
          progression: sortedProgression,
        ),
      ),
      features: features,
    );
  }

  bool _hasFeatureProgression(CharacterRuleDefinition? rules) {
    return rules?.progression.any(
          (step) =>
              step.grants.any((grant) => grant.kind == RuleGrantKind.feature),
        ) ==
        true;
  }

  _LegacyFeature? _parseFeature(String value) {
    final match = RegExp(r'^(\d{1,2})级[：:]\s*(.+)$').firstMatch(value.trim());
    if (match == null) return null;
    final level = int.tryParse(match.group(1)!);
    if (level == null || level < 1 || level > 20) return null;
    final remainder = match.group(2)!.trim();
    final nameMatch = RegExp(
      r'^([\u4e00-\u9fff（）()一二三四五六七八九十、·]+)',
    ).firstMatch(remainder);
    final name = nameMatch?.group(1)?.trim();
    if (name == null || name.isEmpty) return null;
    return _LegacyFeature(level: level, name: name, description: remainder);
  }

  String _availableFeatureId(
    ContentEntry classEntry,
    int level,
    int ordinal,
    Set<String> reservedIds,
  ) {
    final packageId = classEntry.id.split(':').first;
    final base = '$packageId:class-feature/${classEntry.slug}-$level-$ordinal';
    if (!reservedIds.contains(base)) return base;
    var suffix = 2;
    while (reservedIds.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }
}

class _MigratedClass {
  const _MigratedClass({required this.classEntry, this.features = const []});

  final ContentEntry classEntry;
  final List<ContentEntry> features;
}

class _LegacyFeature {
  const _LegacyFeature({
    required this.level,
    required this.name,
    required this.description,
  });

  final int level;
  final String name;
  final String description;
}
