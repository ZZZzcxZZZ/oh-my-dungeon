import '../../content/domain/content_entry.dart';
import 'dnd5e_rules.dart';
import 'structured_class_rules.dart';

/// [ClassRuleSummary.of] 的返回类型：**具名**记录，字段是"key → 记录成员"映射的
/// 唯一来源（`fieldValues` / `_pick` 的取值模板由它的字段集合决定）。
///
/// 具名 typedef 让"给 `of()` 加第 4 个字段"变成**编译错误**——以前展示层把记录
/// 类型**结构性重写**一遍，record 宽度子类型会让新字段被静默丢弃、卡片少一行，
/// 没人发现。
typedef ClassRuleSummaryValues = ({
  String? hitDie,
  String? savingThrows,
  String? skillChoice,
});

/// 职业条目的**规则摘要展示值**（纯展示字符串；未声明一律为 `null`）。
///
/// 这是职业规则值进入展示层的**唯一口径**：
/// - 生命骰 / 豁免熟练只经 [StructuredClassRules]（内部委托
///   [Dnd5eRules.resolveClassRules]，条目声明 ∪ 内置档案，字段级合并）；
/// - 技能选择只经 [StructuredClassRules.skillChoice]（`rules` 里
///   `optionType == 'skill'` 的选择）。
///
/// **不读散文键**：`structured.hitDie`（字符串）/ `structured.savingThrows` /
/// `structured.skills` 一律忽略，它们在新契约里已不存在。**未声明即不显示该行**：
/// 返回 `null`，不显示 `0`、不猜职业名、不回退旧键。
abstract final class ClassRuleSummary {
  static ClassRuleSummaryValues of(ContentEntry? entry) => (
    hitDie: _hitDie(entry),
    savingThrows: _savingThrows(entry),
    skillChoice: _skillChoice(entry),
  );

  /// 规则字段 key → 记录成员。**唯一映射点**：展示层（资料库卡片、创建向导
  /// 摘要）一律经它取规则值，不得再自己写 `switch (field)` 重列一遍成员名。
  ///
  /// 只包含**规则字段**的 key（`hitDie` / `savingThrows` / `skills`），未声明
  /// 的值为 `null` 但 key **保留**：调用方据此知道"该字段是规则字段，值只能来自
  /// `classRules`，未声明就是不显示该行，**不得**回退 `structured`"。
  ///
  /// "加字段忘映射"是编译错误而不是静默丢行：[ClassRuleSummaryValues] 是**具名
  /// typedef**，`of()` 的返回类型与 [_pick] 的参数都带显式标注，增删字段会让
  /// 它们编译失败；映射本身也只有 [_pick] 一处。
  static Map<String, String?> fieldValues(
    ClassRuleSummaryValues rules, {
    required Iterable<String> fields,
  }) {
    final values = <String, String?>{};
    for (final key in fields) {
      final picked = _pick(rules, key);
      if (picked != null) values[key] = picked.$2;
    }
    return values;
  }

  /// key → (展示 key, 记录成员) 的**唯一**取值模板（见 [fieldValues]）。
  static (String, String?)? _pick(ClassRuleSummaryValues rules, String key) =>
      switch ((rules, key)) {
        (
          ClassRuleSummaryValues(
            hitDie: final hitDie,
            savingThrows: final _,
            skillChoice: final _,
          ),
          'hitDie',
        ) =>
          ('hitDie', hitDie),
        (
          ClassRuleSummaryValues(
            hitDie: final _,
            savingThrows: final savingThrows,
            skillChoice: final _,
          ),
          'savingThrows',
        ) =>
          ('savingThrows', savingThrows),
        (
          ClassRuleSummaryValues(
            hitDie: final _,
            savingThrows: final _,
            skillChoice: final skillChoice,
          ),
          'skills',
        ) =>
          ('skills', skillChoice),
        _ => null,
      };

  /// `classRules.hitDie`（条目 ∪ 档案）→ `d<N>`；未声明为 `null`。
  static String? _hitDie(ContentEntry? entry) {
    final hitDie = StructuredClassRules.hitDie(entry);
    return hitDie == null ? null : 'd$hitDie';
  }

  /// `classRules.savingThrowAbilities` → 属性中文标签；空集为 `null`。
  static String? _savingThrows(ContentEntry? entry) =>
      _abilitySentence(StructuredClassRules.savingThrowAbilities(entry));

  /// 技能选择：必选项数 + 候选技能；没有 `optionType == 'skill'` 的选择时为 `null`。
  ///
  /// **只支持内联 `options`**（候选名字写在条目里）。用 `optionTags` /
  /// `optionEntryIds` 表达候选时（模型允许，§3.10.2）没有可列的名字：
  /// [StructuredSkillChoice.restricted] 为真时给中性文案"候选由条目规则给出"，
  /// **不**误标成"任意技能"——那会把"限定候选"说成"随便选"。
  static String? _skillChoice(ContentEntry? entry) {
    final choice = StructuredClassRules.skillChoice(entry);
    if (choice.count <= 0) return null;
    if (choice.options.isNotEmpty) {
      return '选择${choice.count}项：${choice.options.join('、')}';
    }
    return choice.restricted
        ? '任选${choice.count}项（候选由条目规则给出）'
        : '任选${choice.count}项（任意技能）';
  }

  /// 属性键集合 → 中文展示文案。两项用「与」（PHB 中文写作「力量与体质」），
  /// 三项及以上用顿号连接；空集为 `null`。
  ///
  /// 档案 / 条目未收录的属性键原样展示键名（资料库可能含自制属性），
  /// 不做"按名字猜标签"，也不丢弃——它不是规则数值的回退。
  static String? _abilitySentence(Set<String> abilities) {
    if (abilities.isEmpty) return null;
    final labels = abilities
        .map((ability) => Dnd5eRules.abilityLabels[ability] ?? ability)
        .toList(growable: false);
    return labels.length == 2 ? labels.join('与') : labels.join('、');
  }
}
