import '../../content/domain/content_entry.dart';
import 'character_build.dart';
import 'character_rule_definition.dart';
import 'rule_choice_resolver.dart';

class ResolvedRuleGrant {
  const ResolvedRuleGrant({
    required this.id,
    required this.kind,
    required this.label,
    required this.sourceEntryId,
    required this.sourceEntryName,
    required this.sourceLevel,
    this.target,
    this.entryId,
    this.value,
    this.formula,
    this.data = const <String, Object?>{},
  });

  final String id;
  final RuleGrantKind kind;
  final String label;
  final String sourceEntryId;
  final String sourceEntryName;
  final int? sourceLevel;
  final String? target;
  final String? entryId;
  final num? value;
  final String? formula;
  final Map<String, Object?> data;
}

class PendingRuleChoice {
  const PendingRuleChoice({
    required this.key,
    required this.choiceId,
    required this.label,
    required this.optionType,
    required this.minimum,
    required this.maximum,
    required this.selected,
    required this.sourceEntryId,
    required this.sourceLevel,
    this.invalidSelected = const <String>[],
  });

  final String key;
  final String choiceId;
  final String label;
  final String optionType;
  final int minimum;
  final int maximum;
  final List<String> selected;
  final String sourceEntryId;
  final int? sourceLevel;
  final List<String> invalidSelected;

  int get remaining => (minimum - selected.length).clamp(0, minimum);
}

class ActiveRuleChoice {
  const ActiveRuleChoice({
    required this.key,
    required this.definition,
    required this.selected,
    required this.invalidSelected,
    required this.sourceEntryId,
    required this.sourceEntryName,
    required this.sourceLevel,
  });

  final String key;
  final RuleChoiceDefinition definition;
  final List<String> selected;
  final List<String> invalidSelected;
  final String sourceEntryId;
  final String sourceEntryName;
  final int? sourceLevel;

  bool get isValid =>
      invalidSelected.isEmpty &&
      selected.length >= definition.minimum &&
      selected.length <= definition.maximum;
}

class CharacterGrantLedger {
  const CharacterGrantLedger({
    required this.grants,
    required this.pendingChoices,
    required this.missingEntryIds,
    required this.resolvedChoiceEntryIds,
    required this.resolvedChoices,
    required this.activeChoices,
  });

  final List<ResolvedRuleGrant> grants;
  final List<PendingRuleChoice> pendingChoices;
  final List<String> missingEntryIds;
  final List<String> resolvedChoiceEntryIds;
  final Map<String, List<String>> resolvedChoices;
  final List<ActiveRuleChoice> activeChoices;

  Iterable<ResolvedRuleGrant> grantsOfKind(RuleGrantKind kind) {
    return grants.where((grant) => grant.kind == kind);
  }
}

/// 一条"生效单元"的唯一键：`<条目 id>#<定义 id>`。
///
/// `progression[].levels` 声明的是"**同一批效果在多个等级重复生效**"（契约 §3.5）：
/// `levels: [4, 8, 12, 16]` 的属性提升到 16 级要累计 +4，而不是只 +1。因此每个已达
/// 等级都是**独立**的生效单元，键必须带上 [sourceLevel]；只有步骤级之外的条目级定义
/// （`rules.grants` / `rules.choices`，与等级无关）才不带等级。
///
/// 这是键格式的**唯一**实现点：引擎与编辑器（升级预览 diff、选择列表）都必须经过它，
/// 否则两侧对"本等级新增了什么"的判断会不一致。
String ruleUnitKey(String entryId, String definitionId, int? sourceLevel) {
  return sourceLevel == null
      ? '$entryId#$definitionId'
      : '$entryId#$definitionId#$sourceLevel';
}

/// `kind: action` 的**动作身份**键：`<条目 id>#<定义 id>`，**不带等级**。
///
/// 动作没有随等级变化的语义（同一个动作不会因为步骤覆盖 3 个等级就变成 3 个动作），
/// 而多等级步骤（§3.5）会把同一份动作定义逐级展开成 N 个生效单元。需要"每个动作只
/// 出现一次"的消费方（`data['actions']`、编辑器「自动获得」预览）都必须经过这里，
/// 否则两处会各自拼键、去重口径不一致。
String ruleActionKey(String entryId, String definitionId) =>
    '$entryId#$definitionId';

class CharacterRulesEngine {
  const CharacterRulesEngine({required this.entries});

  final Map<String, ContentEntry> entries;

  CharacterGrantLedger evaluate(CharacterBuild build) {
    final grants = <String, ResolvedRuleGrant>{};
    final pendingChoices = <PendingRuleChoice>[];
    final missingEntryIds = <String>[];
    final resolvedChoiceEntryIds = <String>{};
    final resolvedChoices = <String, List<String>>{};
    final activeChoices = <ActiveRuleChoice>[];
    final queue = build.selections.values.toList(growable: true);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final entryId = queue.removeAt(0);
      if (!visited.add(entryId)) continue;
      final entry = entries[entryId];
      if (entry == null) {
        missingEntryIds.add(entryId);
        continue;
      }
      final rules = entry.rules;
      if (rules == null) continue;

      _resolveGrants(
        entry: entry,
        sourceLevel: null,
        definitions: rules.grants,
        target: grants,
      );
      _resolveChoices(
        build: build,
        entry: entry,
        sourceLevel: null,
        definitions: rules.choices,
        pending: pendingChoices,
        queue: queue,
        resolvedChoiceEntryIds: resolvedChoiceEntryIds,
        resolvedChoices: resolvedChoices,
        activeChoices: activeChoices,
      );

      for (final step in rules.progression) {
        // 一个步骤可覆盖多个等级（`levels`）：按每个已达等级分别展开，
        // `sourceLevel` 因此始终是"这一步在哪个等级生效"的单值。
        for (final stepLevel in step.levels) {
          if (stepLevel > build.level) continue;
          _resolveGrants(
            entry: entry,
            sourceLevel: stepLevel,
            definitions: step.grants,
            target: grants,
          );
          _resolveChoices(
            build: build,
            entry: entry,
            sourceLevel: stepLevel,
            definitions: step.choices,
            pending: pendingChoices,
            queue: queue,
            resolvedChoiceEntryIds: resolvedChoiceEntryIds,
            resolvedChoices: resolvedChoices,
            activeChoices: activeChoices,
          );
        }
      }
    }

    return CharacterGrantLedger(
      grants: grants.values.toList(growable: false),
      pendingChoices: pendingChoices,
      missingEntryIds: missingEntryIds,
      resolvedChoiceEntryIds: resolvedChoiceEntryIds.toList(growable: false),
      resolvedChoices: resolvedChoices,
      activeChoices: activeChoices,
    );
  }

  void _resolveGrants({
    required ContentEntry entry,
    required int? sourceLevel,
    required List<RuleGrantDefinition> definitions,
    required Map<String, ResolvedRuleGrant> target,
  }) {
    for (final definition in definitions) {
      // 键带生效等级：同一份定义在多个已达等级各生效一次（§3.5），
      // 后一个等级不能覆盖前一个等级的结算结果。
      final key = ruleUnitKey(entry.id, definition.id, sourceLevel);
      target[key] = ResolvedRuleGrant(
        id: definition.id,
        kind: definition.kind,
        label: definition.label,
        sourceEntryId: entry.id,
        sourceEntryName: entry.name,
        sourceLevel: sourceLevel,
        target: definition.target,
        entryId: definition.entryId,
        value: definition.value,
        formula: definition.formula,
        data: definition.data,
      );
    }
  }

  void _resolveChoices({
    required CharacterBuild build,
    required ContentEntry entry,
    required int? sourceLevel,
    required List<RuleChoiceDefinition> definitions,
    required List<PendingRuleChoice> pending,
    required List<String> queue,
    required Set<String> resolvedChoiceEntryIds,
    required Map<String, List<String>> resolvedChoices,
    required List<ActiveRuleChoice> activeChoices,
  }) {
    final resolver = RuleChoiceResolver(entries: entries);
    for (final definition in definitions) {
      // 选择与授予共用同一种多等级语义（§3.5）：每个已达等级都是一次独立的
      // 选择实例（16 级的 4 次属性提升各选一次），键同样带上生效等级。
      final key = ruleUnitKey(entry.id, definition.id, sourceLevel);
      // 兼容等级限定键之前写入的旧存档：只有不带等级的键时沿用它。
      final requested =
          build.choices[key] ??
          (sourceLevel == null
              ? const <String>[]
              : build.choices[ruleUnitKey(entry.id, definition.id, null)] ??
                    const <String>[]);
      final selected = requested
          .where(
            (entryId) =>
                resolver.allows(definition, entryId, sourceEntryId: entry.id),
          )
          .toList(growable: false);
      final invalidSelected = requested
          .where((entryId) => !selected.contains(entryId))
          .toList(growable: false);
      activeChoices.add(
        ActiveRuleChoice(
          key: key,
          definition: definition,
          selected: selected,
          invalidSelected: invalidSelected,
          sourceEntryId: entry.id,
          sourceEntryName: entry.name,
          sourceLevel: sourceLevel,
        ),
      );
      if (selected.length < definition.minimum ||
          selected.length > definition.maximum ||
          invalidSelected.isNotEmpty) {
        pending.add(
          PendingRuleChoice(
            key: key,
            choiceId: definition.id,
            label: definition.label,
            optionType: definition.optionType,
            minimum: definition.minimum,
            maximum: definition.maximum,
            selected: selected,
            sourceEntryId: entry.id,
            sourceLevel: sourceLevel,
            invalidSelected: invalidSelected,
          ),
        );
      }
      final accepted = selected
          .take(definition.maximum)
          .toList(growable: false);
      resolvedChoices[key] = accepted;
      resolvedChoiceEntryIds.addAll(accepted);
      queue.addAll(accepted);
    }
  }
}
