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
    // 按**对象身份**去重：`levels` 是"同一批效果在多个等级重复生效"（契约 §3.5），
    // 一个步骤只能输出一次。旧的"level → step"映射会把 `levels: [4,8,12,16]`
    // 的步骤复制成 4 份（规则页重复渲染、同一 choice 出现多次）。
    final stepsByIdentity = <RuleProgressionDefinition, Set<int>>{};
    for (final step in existingRules.progression) {
      stepsByIdentity.putIfAbsent(step, () => <int>{}).addAll(step.levels);
    }

    // 旧版 `structured.features` 声明的等级要由"逐级特性步骤"接管：必须把这些等级
    // 从原步骤的 `levels` 里**摘掉**，只去重而不摘会让同一等级被两个步骤同时覆盖。
    final replacedLevels = grantsByLevel.keys.toSet();
    // 每个等级只能被一个步骤覆盖：先占先得，保证输出无重叠区间。
    final claimed = <int>{};
    final keptSteps = <_ProgressionStep>[];

    for (final entry in stepsByIdentity.entries) {
      final levels = entry.value
          .where((level) => !replacedLevels.contains(level))
          .toList()
        ..sort();
      final kept = <int>[];
      for (final level in levels) {
        if (claimed.add(level)) kept.add(level);
      }
      if (kept.isEmpty) continue;
      keptSteps.add(
        _ProgressionStep(
          levels: kept,
          grants: entry.key.grants,
          choices: entry.key.choices,
        ),
      );
    }

    for (final level in grantsByLevel.keys.toList()..sort()) {
      if (!claimed.add(level)) continue;
      final grants = <RuleGrantDefinition>[];
      final choices = <RuleChoiceDefinition>[];
      for (final entry in stepsByIdentity.entries) {
        if (!entry.value.contains(level)) continue;
        grants.addAll(entry.key.grants);
        choices.addAll(entry.key.choices);
      }
      grants.addAll(grantsByLevel[level]!);
      keptSteps.add(
        _ProgressionStep(levels: <int>[level], grants: grants, choices: choices),
      );
    }

    final sortedProgression = <RuleProgressionDefinition>[
      for (final step in keptSteps)
        RuleProgressionDefinition(
          levels: step.levels,
          grants: step.grants,
          choices: step.choices,
        ),
    ]..sort((left, right) => left.levels.first.compareTo(right.levels.first));

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

class _ProgressionStep {
  const _ProgressionStep({
    required this.levels,
    required this.grants,
    required this.choices,
  });

  final List<int> levels;
  final List<RuleGrantDefinition> grants;
  final List<RuleChoiceDefinition> choices;
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
