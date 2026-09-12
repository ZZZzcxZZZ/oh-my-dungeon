import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/rule_profile.dart';
import 'dnd5e_rules.dart';

class StructuredSkillChoice {
  const StructuredSkillChoice({
    required this.count,
    required this.options,
    this.restricted = false,
  });

  static const empty = StructuredSkillChoice(count: 0, options: []);

  final int count;
  final List<String> options;

  /// 候选**不是**"任意技能"：选择用 `optionTags` / `optionEntryIds` 表达，
  /// 只是没有内联 `options` 可以列出名字。展示层据此给中性文案，
  /// 不能写成"任意技能"。
  final bool restricted;
}

/// 职业初始装备的选择上限。来自 class entry 的
/// `structured.startingEquipmentChoice.maximum`，用于角色创建向导"装备"步骤
/// 限制玩家自由挑选的装备数量。null 表示该职业不使用自由挑选模式
/// （全部由 equipmentBundle 授予）。
class StartingEquipmentChoice {
  const StartingEquipmentChoice({required this.maximum});

  final int maximum;
}

/// 职业规则的**只读过渡适配器**：从条目取 `structured` / `rules`，委托唯一解析
/// 入口，再转成调用方仍在用的旧返回类型。
///
/// 边界（契约 §3.2、§3.6、§3.10、§3.12）：
/// - `classRules` 的解析是 [RuleProfileResolver] / `ClassRuleSet.parse` 的职责，
///   本文件**不重复解析**，只调 [Dnd5eRules.resolveClassRules]；
/// - 技能选择只读 `entry.rules` 里 `optionType == 'skill'` 的选择，`minimum` 是
///   必选项数、内联 `options` 是候选值；
/// - **没有散文解析**：`structured.savingThrows` / `structured.skills` 一律忽略，
///   也不存在按属性中文标签的包含判断。
///
/// 旧签名全部保留（任务 8 迁移调用方后删除），因此本文件不得破坏构建。
abstract final class StructuredClassRules {
  /// 职业豁免熟练（属性键集合）。未声明即空集，不按职业名猜测。
  static Set<String> savingThrowAbilities(ContentEntry? entry) =>
      _resolved(entry).savingThrowAbilities;

  /// 职业生命骰；未声明返回 null（不按职业名猜）。
  static int? hitDie(ContentEntry? entry) => _resolved(entry).hitDie;

  /// 职业技能选择。唯一来源是 `entry.rules` 里**第一条**
  /// `optionType == 'skill'` 的选择（先看 `rules.choices`，再看
  /// `rules.progression[].choices`）：`minimum` 作 [StructuredSkillChoice.count]，
  /// 内联 `options` 的 `label`（字符串元素即其本身）作
  /// [StructuredSkillChoice.options]。没有这条选择就返回
  /// [StructuredSkillChoice.empty]——**不**回退中文散文，也不猜测全部技能。
  ///
  /// 模型允许用 `optionTags` / `optionEntryIds` 表达候选（§3.10.2）：
  /// 此时 `options` 为空但**候选不是"任意技能"**，[StructuredSkillChoice.restricted]
  /// 置位，展示层给中性文案而不是"任选N项（任意技能）"。
  static StructuredSkillChoice skillChoice(ContentEntry? entry) {
    final rules = entry?.rules;
    if (rules == null) return StructuredSkillChoice.empty;
    for (final choice in _choices(rules)) {
      if (choice.optionType != 'skill') continue;
      return StructuredSkillChoice(
        count: choice.minimum,
        options: choice.options
            .map((option) => option.label)
            .toList(growable: false),
        restricted:
            choice.options.isEmpty &&
            (choice.optionTags.isNotEmpty || choice.optionEntryIds.isNotEmpty),
      );
    }
    return StructuredSkillChoice.empty;
  }

  /// 准备法术数量上限：唯一来源是职业自身 `spellcasting.prepared` 逐级表
  /// （契约 §3.3，「未声明该等级」时按表语义向上沿用，短数组同理）。
  /// 职业未声明施法（`mode == 'none'`）或没有 `prepared` 表时返回 null。
  ///
  /// [abilities] 与 [level] 中，只有 [level] 参与计算：新契约的准备上限是职业级
  /// 数值表，与属性调整值无关（旧的"调整值 + 等级"公式已删除）。[abilities]
  /// 仅为保留旧签名而存在，任务 8 迁移完调用方后随本 shim 一起删除。
  static int? preparedSpellLimit(
    ContentEntry? entry, {
    required Map<String, int> abilities,
    required int level,
  }) => _resolved(entry).preparedLimit(level);

  /// 职业初始装备自由挑选上限。null 表示该职业未声明自由挑选模式。
  ///
  /// 这是**旧形状**（`structured.startingEquipmentChoice.maximum`），等装备选择
  /// （`optionType: "equipmentBundle"`）落地后再迁移，本任务保持原样。
  static StartingEquipmentChoice? startingEquipmentChoice(ContentEntry? entry) {
    final structured = entry?.structured;
    if (structured == null) return null;
    final raw = structured['startingEquipmentChoice'];
    if (raw is! Map) return null;
    final maximum = (raw['maximum'] as num?)?.toInt();
    if (maximum == null || maximum <= 0) return null;
    return StartingEquipmentChoice(maximum: maximum);
  }

  /// 条目声明 ∪ 内置档案（条目优先，字段级）。身份只认条目 id 的最后一段，
  /// `classSummary` 仅用于过渡期把老角色的散文展示名对齐到 slug。
  static ResolvedClassRules _resolved(ContentEntry? entry) {
    if (entry == null) {
      return Dnd5eRules.resolveClassRules(entryId: null, classSummary: '');
    }
    return Dnd5eRules.resolveClassRules(
      entryId: entry.id,
      classSummary: entry.name,
      structured: entry.structured,
    );
  }

  /// 条目自身声明的选择：`rules.choices` 在前，`rules.progression[].choices`
  /// 按声明顺序随后（契约 §3.10）。
  static Iterable<RuleChoiceDefinition> _choices(
    CharacterRuleDefinition rules,
  ) sync* {
    yield* rules.choices;
    for (final step in rules.progression) {
      yield* step.choices;
    }
  }
}
