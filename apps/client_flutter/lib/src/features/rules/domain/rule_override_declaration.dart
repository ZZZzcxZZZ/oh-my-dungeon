// S3 决策 D2 / D4 / D6：一条参与职业规则合并的声明。
//
// **这是合并链上唯一的声明类型**：解析器不再有第二套本地脚手架，
// 排序 / 截断只在 `RuleOverrideOrder`，`packageId` 派生只在 `packageIdOf`。
import 'class_rule_set.dart';
import 'rule_profile.dart';

/// 一条参与职业规则合并的声明（契约 S3）。
///
/// - [RuleOverrideDeclaration.package]：角色自己的职业条目与别的包的补丁 / 勘误
///   条目，`tier == kEntryTier + priority`（缺省 priority 0 ⇒ tier 恒为 100，
///   与引入 priority 之前行为一致）；
/// - [RuleOverrideDeclaration.builtin]：内置档案，`tier == kBuiltinTier`（0）。
class RuleOverrideDeclaration {
  const RuleOverrideDeclaration._({
    required this.originId,
    required this.packageId,
    required this.priority,
    required this.tier,
    required this.rules,
    this.entryId,
  });

  /// 包声明：`tier` 只由 [priority] 决定（决策 D2），不接受调用方直接给 tier——
  /// 否则"priority 生效"会有第二个入口。
  factory RuleOverrideDeclaration.package({
    required String originId,
    required String packageId,
    required ClassRuleSet rules,
    int priority = 0,
    String? entryId,
  }) => RuleOverrideDeclaration._(
    originId: originId,
    packageId: packageId,
    priority: priority,
    tier: kEntryTier + priority,
    rules: rules,
    entryId: entryId,
  );

  /// 内置档案（tier 0 的基准）。`priority` 固定为 [kBuiltinTier] - [kEntryTier]
  /// （负数）只是为了字段可读，**排序只看 [tier]**。
  factory RuleOverrideDeclaration.builtin(ClassRuleSet rules) =>
      RuleOverrideDeclaration._(
        originId: kBuiltinOriginId,
        packageId: '',
        priority: kBuiltinTier - kEntryTier,
        tier: kBuiltinTier,
        rules: rules,
        entryId: null,
      );

  /// 条目 id（如 `errata:class/wizard`）或 [kBuiltinOriginId]。
  final String originId;

  /// 条目所属包 id（[RuleOverrideDeclaration.packageIdOf]），用于"关闭整个包的
  /// 覆盖"；内置档案为空串。
  final String packageId;

  /// 包声明的 priority（0..1000）。内置档案为负数，不参与展示。
  final int priority;

  /// 生效 tier。**唯一排序键**：包声明 = [kEntryTier] + priority；内置 = [kBuiltinTier]。
  final int tier;

  /// `structured.classRules` 解析结果（含 `mode`）。
  final ClassRuleSet rules;

  /// 便于排序时判断"这是角色自己那条"（同 tier 同 mode 时它优先）。
  final String? entryId;

  /// 条目 id 前缀里的包 id（`<packageId>:<type>/<slug>` → `<packageId>`）；
  /// 没有 `:`、或 `:` 出现在最前时返回空串。
  ///
  /// **必须按最后一个 `:` 切分**：导入期只校验条目 id 以 `<packageId>:` 开头，
  /// 包 id 因此允许含 `:`；按第一个 `:` 切分会让 `packagePriorities()` 查不到键、
  /// priority 静默变 0。**唯一实现**：索引、解析器、UI 都调这里，不各自 `split(':')`。
  static String packageIdOf(String entryId) {
    final index = entryId.lastIndexOf(':');
    return index <= 0 ? '' : entryId.substring(0, index);
  }
}
