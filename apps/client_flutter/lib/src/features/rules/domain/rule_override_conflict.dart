// S3 决策 D6：同一 tier 的多个来源抢同一列时的冲突登记与持久化。
//
// 冲突**不是导入 error**（导入单个包时看不到别的包，冲突不是该包的错）：运行期
// 由 `RuleProfileResolver` 在列级合并时登记，写进角色数据 `data.classRuleConflicts`，
// 由角色页提示并由用户选择保留哪个来源（`CharacterRuleOverrides.pinned`）。
import 'rule_field_path.dart';

/// 同一 tier 的多个来源抢同一列时的记录（契约 S3、决策 D6）。
///
/// 生效值取 [RuleOverrideOrder]/`ordered` 排序首位（可复现），但**必须让用户
/// 看见**并能显式改选（`CharacterRuleOverrides.pinned`）——不许静默取一个了事。
class RuleOverrideConflict {
  const RuleOverrideConflict({
    required this.field,
    required this.tier,
    required this.originIds,
    required this.effectiveOriginId,
  });

  /// [RuleFieldPath] 的列级路径（唯一实现，不手拼）。
  final String field;

  /// 冲突所在的 tier（同 tier 才会冲突；不同 tier 只是覆盖）。
  final int tier;

  /// 同 tier 抢这一列的全部来源 id，按 [RuleOverrideOrder] 排序（长度 ≥ 2）。
  final List<String> originIds;

  /// 无用户选择时的确定性胜出者（`originIds.first`）。
  final String effectiveOriginId;

  /// 字段展示名（中文标签唯一实现在 [RuleFieldPath.labelFor]）。
  String get label => RuleFieldPath.labelFor(field);

  Map<String, Object?> toJson() => {
    'field': field,
    'tier': tier,
    'originIds': originIds,
    'effectiveOriginId': effectiveOriginId,
  };

  /// 坏数据返回 null：冲突是"附加信息"，读不回来时按"没有冲突"处理，
  /// 绝不猜一个来源（与 [RuleFieldSource.fromJson] 同一降级策略）。
  static RuleOverrideConflict? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final field = '${raw['field'] ?? ''}'.trim();
    final tier = raw['tier'];
    final effective = '${raw['effectiveOriginId'] ?? ''}'.trim();
    final rawOrigins = raw['originIds'];
    if (field.isEmpty ||
        tier is! int ||
        effective.isEmpty ||
        rawOrigins is! List) {
      return null;
    }
    final origins = [for (final origin in rawOrigins) '$origin'];
    if (origins.length < 2) return null;
    return RuleOverrideConflict(
      field: field,
      tier: tier,
      originIds: List<String>.unmodifiable(origins),
      effectiveOriginId: effective,
    );
  }

  @override
  String toString() =>
      'RuleOverrideConflict($field @tier $tier: $originIds → $effectiveOriginId)';
}

/// 冲突表的持久化（角色数据 `data.classRuleConflicts`）的**唯一**实现。
abstract final class RuleOverrideConflicts {
  static List<Object?> toData(Iterable<RuleOverrideConflict> conflicts) => [
    for (final conflict in conflicts) conflict.toJson(),
  ];

  static List<RuleOverrideConflict> fromData(Object? raw) {
    if (raw is! List) return const <RuleOverrideConflict>[];
    final result = <RuleOverrideConflict>[];
    for (final item in raw) {
      final conflict = RuleOverrideConflict.fromJson(item);
      if (conflict != null) result.add(conflict);
    }
    return List<RuleOverrideConflict>.unmodifiable(result);
  }
}
