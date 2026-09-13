import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../../rules/domain/character_rule_definition.dart';
import '../../../rules/domain/rule_override_declaration.dart';

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
    if (entry.type != 'class') return _MigratedClass(classEntry: entry);
    final rawFeatures = entry.structured['features'];
    if (rawFeatures is! List) return _MigratedClass(classEntry: entry);
    // 已经迁移过的条目（progression 里带 feature 授予）且**没有**待迁移的
    // `structured.features` 时原样放行。反过来：只要还有待迁移的旧版特性，
    // 即使 progression 里已有 feature 授予也要继续，否则重叠等级永远修不掉。
    if (_hasFeatureProgression(entry.rules) && rawFeatures.isEmpty) {
      return _MigratedClass(classEntry: entry);
    }

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

    // 旧版 `structured.features` 的等级：即使没有任何既有步骤覆盖，也要各自成一步。
    final featureLevels = grantsByLevel.keys.toSet();

    // 输出规则：每个等级**只产出一条步骤**，它的 grants / choices 是"所有来源"的
    // 并集（既有步骤的 grants/choices + 该等级的旧版逐级特性授予）。旧实现是
    // "先占先得"——两个既有步骤共享同一等级时后者整步被丢弃（`kept.isEmpty` 时连
    // grants 一起丢），属静默丢内容。
    //
    // 形状规则：**没有任何等级要单独成步的步骤保持原 `levels` 形状**
    // （`[4,8,12,16]` 里 8 被旧版特性接管后仍是 `[4,12,16]` 一条）；一旦步骤里有
    // 等级被旧版特性接管、或与别的步骤重叠，就退化成逐级输出，该等级的所有来源
    // 再并起来。
    final coverageByLevel = <int, int>{};
    for (final levels in stepsByIdentity.values) {
      for (final level in levels) {
        if (featureLevels.contains(level)) continue;
        coverageByLevel[level] = (coverageByLevel[level] ?? 0) + 1;
      }
    }

    final standalone = <_ProgressionStep>[];
    // 逐级输出：等级 → 该等级全部来源的 grants / choices 并集（含旧版逐级特性）。
    final grantsByOutputLevel = <int, List<RuleGrantDefinition>>{};
    final choicesByOutputLevel = <int, List<RuleChoiceDefinition>>{};
    for (final step in stepsByIdentity.entries) {
      final splitLevels = step.value
          .where(
            (level) =>
                featureLevels.contains(level) ||
                coverageByLevel[level]! > 1,
          )
          .toList()
        ..sort();
      if (splitLevels.isEmpty) {
        standalone.add(
          _ProgressionStep(
            levels: step.value.toList()..sort(),
            grants: step.key.grants,
            choices: step.key.choices,
          ),
        );
        continue;
      }
      for (final level in splitLevels) {
        grantsByOutputLevel.putIfAbsent(level, () => []).addAll(step.key.grants);
        choicesByOutputLevel
            .putIfAbsent(level, () => [])
            .addAll(step.key.choices);
      }
      // 没被拆分的等级保持原步骤形状：多等级语义（§3.5）不能莫名退化成逐级。
      final keptLevels = (step.value.toList()..sort())
          .where((level) => !splitLevels.contains(level))
          .toList(growable: false);
      if (keptLevels.isNotEmpty) {
        standalone.add(
          _ProgressionStep(
            levels: keptLevels,
            grants: step.key.grants,
            choices: step.key.choices,
          ),
        );
      }
    }
    for (final level in featureLevels) {
      grantsByOutputLevel.putIfAbsent(level, () => []);
      choicesByOutputLevel.putIfAbsent(level, () => []);
    }

    final keptSteps = <_ProgressionStep>[
      ...standalone,
      for (final level in grantsByOutputLevel.keys.toList()..sort())
        _ProgressionStep(
          levels: <int>[level],
          grants: <RuleGrantDefinition>[
            ...grantsByOutputLevel[level]!,
            // 旧版逐级特性的授予并进同一步（每级只加一次）。
            ...?grantsByLevel[level],
          ],
          choices: choicesByOutputLevel[level] ?? const <RuleChoiceDefinition>[],
        ),
    ];

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
        // 旧版 `structured.features` 已经被消费掉：从结构化字段里摘掉，
        // 否则同一份特性会被重复迁移出新的 `feature-<等级>-<序号>` 授予
        // （`_migrateClass` 每次都会重新解析并再加一遍）。
        structured: {...entry.structured}..remove('features'),
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
    // 包 id 派生只有 `RuleOverrideDeclaration.packageIdOf` 一处（按**最后一个** `:`
    // 切分，包 id 允许含 `:`）；这里不再 `split(':').first`。
    final packageId = RuleOverrideDeclaration.packageIdOf(classEntry.id);
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
