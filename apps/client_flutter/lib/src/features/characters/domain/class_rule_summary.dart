import '../../content/domain/content_entry.dart';
import 'dnd5e_rules.dart';
import 'structured_class_rules.dart';

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
  static ({String? hitDie, String? savingThrows, String? skillChoice}) of(
    ContentEntry? entry,
  ) => (
    hitDie: _hitDie(entry),
    savingThrows: _savingThrows(entry),
    skillChoice: _skillChoice(entry),
  );

  /// `classRules.hitDie`（条目 ∪ 档案）→ `d<N>`；未声明为 `null`。
  static String? _hitDie(ContentEntry? entry) {
    final hitDie = StructuredClassRules.hitDie(entry);
    return hitDie == null ? null : 'd$hitDie';
  }

  /// `classRules.savingThrowAbilities` → 属性中文标签；空集为 `null`。
  static String? _savingThrows(ContentEntry? entry) =>
      _abilitySentence(StructuredClassRules.savingThrowAbilities(entry));

  /// 技能选择：必选项数 + 候选技能；没有 `optionType == 'skill'` 的选择时为 `null`。
  static String? _skillChoice(ContentEntry? entry) {
    final choice = StructuredClassRules.skillChoice(entry);
    if (choice.count <= 0) return null;
    if (choice.options.isEmpty) return '任选${choice.count}项（任意技能）';
    return '选择${choice.count}项：${choice.options.join('、')}';
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
