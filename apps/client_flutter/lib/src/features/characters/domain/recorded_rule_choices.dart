import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_rule_definition.dart';
import 'character.dart';

/// 一条"角色选了什么"的记录（`data['choices']` 的读取结果）。
///
/// 只描述**用户的选择**，不参与任何数值派生：数值一律由规则引擎结算
/// （`rules_driven_character_builder.dart`）。存在的意义是让角色卡能显示
/// "记录型选择"——例如值选项（内联 `options`）与不产生 grant 的风格选择，
/// 否则用户在创建向导里做过的选择在角色卡上完全看不见。
class RecordedRuleChoice {
  const RecordedRuleChoice({
    required this.sourceEntryId,
    required this.choiceId,
    required this.choiceLabel,
    required this.optionIds,
    required this.optionLabels,
    this.sourceName,
    this.level,
  });

  /// 选择定义所属条目的 id（键的第一段）。
  final String sourceEntryId;

  /// 选择定义所属条目的展示名；条目不在当前资料库时为空（不猜）。
  final String? sourceName;

  /// 选择 id 与它生效的等级（键的 `#choiceId` / `#level` 段；没有等级段时为 null）。
  final String choiceId;
  final int? level;

  /// 选择定义的中文标签；定义缺失时退回 [choiceId]。
  final String choiceLabel;

  /// 选中的选项 id 与展示名（顺序 = 用户点击顺序 / 落库顺序）。
  final List<String> optionIds;
  final List<String> optionLabels;

  /// 一行展示文本（唯一实现，UI 不再各拼一份）。
  String get summary {
    final where = sourceName ?? sourceEntryId;
    final levelText = level == null ? '' : '（$level 级）';
    return '$where · $choiceLabel$levelText：${optionLabels.join('、')}';
  }
}

/// `data['choices']` 的**唯一读取方**（写入方是 `RulesDrivenCharacterBuilder` 的
/// `recordedChoices`：键 = 生效单元键 `{sourceEntryId}#{choiceId}[#level]`）。
///
/// 展示顺序：先按**来源条目的展示名**（跨来源稳定），同来源内按**等级**，再按选择在
/// 条目里的**声明序**（与创建向导的步骤顺序一致），最后用 `choiceId` 兜底保证确定性。
///
/// 标签解析顺序（绝不臆造）：
/// 1. 内联选项（`options[].label`）；
/// 2. `optionType: "skill"` → 选项 id 就是技能名；
/// 3. 同包内被引用的条目（`optionEntryIds` / 对齐键）→ 条目的 `name`；
/// 4. 都查不到 → 原样显示选项 id。
List<RecordedRuleChoice> recordedRuleChoices({
  required CharacterSheet character,
  required Iterable<ContentEntry> entries,
}) {
  final raw = character.dataMap['choices'];
  if (raw is! Map) return const <RecordedRuleChoice>[];
  final byId = <String, ContentEntry>{
    for (final entry in entries) entry.id: entry,
  };
  final result = <RecordedRuleChoice>[];
  // 声明顺序（条目里 choices 的出现序，与创建向导的步骤顺序一致）：展示顺序按它排，
  // 不用 id 字典序——否则用户看到的顺序与当初选它的顺序不同。
  final declarationOrder = <String, int>{};
  for (final entry in raw.entries) {
    final picked = <String>[
      if (entry.value is List)
        for (final value in entry.value as List)
          if ('$value'.trim().isNotEmpty) '$value'.trim(),
    ];
    if (picked.isEmpty) continue;
    final parsed = _parseChoiceKey('${entry.key}');
    final entry_ = byId[parsed.sourceEntryId];
    final definition = _choiceDefinition(entry_, parsed.choiceId);
    final orderKey = '${parsed.sourceEntryId}#${parsed.choiceId}';
    declarationOrder.putIfAbsent(
      orderKey,
      () => _declarationIndexOf(entry_, parsed.choiceId),
    );
    result.add(
      RecordedRuleChoice(
        sourceEntryId: parsed.sourceEntryId,
        sourceName: entry_?.name,
        choiceId: parsed.choiceId,
        level: parsed.level,
        choiceLabel: definition?.label ?? parsed.choiceId,
        optionIds: List<String>.unmodifiable(picked),
        optionLabels: List<String>.unmodifiable(<String>[
          for (final optionId in picked)
            _optionLabel(optionId, definition, byId),
        ]),
      ),
    );
  }
  result.sort((a, b) {
    final bySource = (a.sourceName ?? a.sourceEntryId).compareTo(
      b.sourceName ?? b.sourceEntryId,
    );
    if (bySource != 0) return bySource;
    final byLevel = (a.level ?? 0).compareTo(b.level ?? 0);
    if (byLevel != 0) return byLevel;
    final byDeclaration = (declarationOrder['${a.sourceEntryId}#${a.choiceId}'] ?? 1 << 30)
        .compareTo(declarationOrder['${b.sourceEntryId}#${b.choiceId}'] ?? 1 << 30);
    if (byDeclaration != 0) return byDeclaration;
    return a.choiceId.compareTo(b.choiceId);
  });
  return List<RecordedRuleChoice>.unmodifiable(result);
}

({String sourceEntryId, String choiceId, int? level}) _parseChoiceKey(
  String key,
) {
  final parts = key.split('#');
  return (
    sourceEntryId: parts.isNotEmpty ? parts[0].trim() : '',
    choiceId: parts.length > 1 ? parts[1].trim() : '',
    level: parts.length > 2 ? int.tryParse(parts[2].trim()) : null,
  );
}

/// 选择定义在条目里的**声明序**（`rules.choices` 先，再按 `progression` 的步骤顺序）；
/// 找不到时给一个很大的序号，让它排在已知项之后（不隐藏、只是靠后）。
int _declarationIndexOf(ContentEntry? entry, String choiceId) {
  final rules = entry?.rules;
  if (rules == null) return 1 << 30;
  var index = 0;
  for (final choice in rules.choices) {
    if (choice.id == choiceId) return index;
    index += 1;
  }
  for (final step in rules.progression) {
    for (final choice in step.choices) {
      if (choice.id == choiceId) return index;
      index += 1;
    }
  }
  return 1 << 30;
}

/// 选择定义可以写在 `rules.choices`（整块）或 `rules.progression[].choices`
/// （按等级）里的任一处，这里两处都找（判据与验证器一致）。
RuleChoiceDefinition? _choiceDefinition(ContentEntry? entry, String choiceId) {
  final rules = entry?.rules;
  if (rules == null) return null;
  for (final choice in rules.choices) {
    if (choice.id == choiceId) return choice;
  }
  for (final step in rules.progression) {
    for (final choice in step.choices) {
      if (choice.id == choiceId) return choice;
    }
  }
  return null;
}

String _optionLabel(
  String optionId,
  RuleChoiceDefinition? definition,
  Map<String, ContentEntry> byId,
) {
  for (final option in definition?.options ?? const <RuleChoiceOption>[]) {
    if (option.id == optionId) return option.label;
  }
  // 技能选项：`optionType: "skill"` 的选项 id 就是技能名。
  if (definition?.optionType == 'skill') return optionId;
  final entry = byId[optionId];
  if (entry != null) return entry.name;
  // 落库的选项 id 可能是条目 id，也可能只是对齐键（末段）：按末段回退匹配。
  final tail = optionId.contains('/') ? optionId.split('/').last : optionId;
  for (final candidate in byId.values) {
    if (candidate.id.split('/').last == tail) return candidate.name;
  }
  return optionId;
}
