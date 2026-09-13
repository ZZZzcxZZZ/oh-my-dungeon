// S3 决策 D3：跨包职业规则声明的索引（对齐键 = 条目 id 末段，与内置档案同一套）。
import '../../content/domain/content_entry.dart';
import '../../content/domain/content_entry_id.dart';
import '../../rules/domain/class_rule_set.dart';
import '../../rules/domain/rule_diagnostic.dart';
import '../../rules/domain/rule_override_declaration.dart';
import '../../rules/domain/rule_override_priority.dart';

/// 跨包职业规则声明的索引（契约 S3、决策 D3）。
///
/// 按**对齐键**（条目 id 末段，与 `Dnd5eRules.resolveClassSlug` 同一口径）分组，
/// 让"一条只改 spellcasting.prepared 的勘误"能作用于**已指向别的包条目**的角色。
///
/// 只含"有 `structured.classRules` 的 `type: class` 条目"；未声明规则块的条目
/// 不参与（导入期已用 `builtinSlugRequiresExplicitRules` / `unresolvedClassRule`
/// 处理过它们）。
class RuleOverrideIndex {
  const RuleOverrideIndex(this._bySlug);

  static const empty = RuleOverrideIndex(
    <String, List<RuleOverrideDeclaration>>{},
  );

  final Map<String, List<RuleOverrideDeclaration>> _bySlug;

  /// 唯一构建点。[packagePriorities] 键 = packageId，缺省 0（= tier 100）。
  ///
  /// 运行期不重复导入期的校验（导入期已把坏声明挡在库外），诊断因此丢弃；
  /// 但 `parse` 万一抛异常也不能拖垮索引构建，按"跳过该条目"处理（parse 目前
  /// 不抛，这里是防御）。
  static RuleOverrideIndex fromEntries(
    Iterable<ContentEntry> entries,
    Map<String, int> packagePriorities,
  ) {
    final bySlug = <String, List<RuleOverrideDeclaration>>{};
    for (final entry in entries) {
      if (entry.type != 'class') continue;
      final raw = entry.structured['classRules'];
      if (raw is! Map) continue;
      final slug = contentEntryAlignmentKey(entry.id);
      if (slug.isEmpty) continue;
      final ClassRuleSet rules;
      try {
        rules = ClassRuleSet.parse(
          Map<String, Object?>.from(raw),
          path: r'$.structured.classRules',
          diagnostics: <RuleDiagnostic>[],
          abilities: kDefaultAbilities,
        );
      } catch (_) {
        continue;
      }
      // 统一到**规范 id**：战役视图的条目 id 带 `local:` / `campaign:<cid>:` 前缀，
      // 而用户的覆盖选择与角色自身条目身份必须跨视图一致（`canonicalContentEntryId`
      // 是唯一实现）。
      final canonicalId = canonicalContentEntryId(entry.id);
      final packageId = RuleOverrideDeclaration.packageIdOf(canonicalId);
      (bySlug[slug] ??= <RuleOverrideDeclaration>[]).add(
        RuleOverrideDeclaration.package(
          originId: canonicalId,
          packageId: packageId,
          priority: packagePriorities[packageId] ?? 0,
          rules: rules,
          entryId: canonicalId,
        ),
      );
    }
    return RuleOverrideIndex(bySlug);
  }

  /// 该对齐键上的**其它**包声明（已按优先级从高到低排好，**未做 `replace` 截断**）。
  ///
  /// 截断必须由调用方在"合入角色自身条目 / 内置档案"之后统一做
  /// （`RuleOverrideOrder.truncate`）：在这里先截断会漏掉"更高 tier 的 replace
  /// 截掉本索引 + 档案"的场景。
  ///
  /// [excludeEntryId] 是角色自己的条目（它由调用方作为 `entryRules` 传入，避免同一
  /// 来源出现两次）。**这里不再传 `characterEntryId` 给排序**：排除之后那个
  /// "角色自己的条目优先"的 tie-break 永远不可能触发，是死参；tie-break 由解析器
  /// 在合入自身条目后统一处理。
  List<RuleOverrideDeclaration> declarationsFor(
    String slug, {
    String? excludeEntryId,
  }) => RuleOverrideOrder.ordered(
    (_bySlug[slug.trim().toLowerCase()] ?? const <RuleOverrideDeclaration>[])
        .where((declaration) => declaration.originId != excludeEntryId),
  );
}
