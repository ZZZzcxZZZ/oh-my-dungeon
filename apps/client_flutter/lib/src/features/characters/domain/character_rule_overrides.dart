// S3 决策 D6：角色对"跨包规则覆盖"的选择的**唯一**读取 / 写入实现。
import '../../rules/domain/rule_override_declaration.dart';
import '../../rules/domain/rule_override_priority.dart';
import 'character.dart';

/// 角色数据 `data.ruleOverrides` 的唯一读写实现（契约 S3、决策 D6）。
///
/// - [disabledOriginIds]：用户显式关掉的覆盖来源（**条目 id 或包 id 命中都算**），
///   解析器据此把该来源从合并链里剔除，回退更低 tier（"关闭覆盖回退内置"）；
/// - [pinned]：用户为**某一列**显式选定的来源（键 = `RuleFieldPath` 的列路径，
///   值 = originId）。pin 是显式选择，语义上高于 priority，且**只影响该列**。
///
/// 页面**不得**直接读写 `dataMap['ruleOverrides']`：形状归一化（去重、排序、
/// 坏数据降级）只在这里一份，否则同一份用户选择会有第二种解释。
class CharacterRuleOverrides {
  const CharacterRuleOverrides({
    this.disabledOriginIds = const <String>{},
    this.pinned = const <String, String>{},
  });

  static const empty = CharacterRuleOverrides();

  /// 从角色数据的 `data.ruleOverrides` 读取；缺失 / 坏形状按"没有覆盖"处理。
  static CharacterRuleOverrides fromCharacter(CharacterSheet character) =>
      fromData(character.dataMap['ruleOverrides']);

  /// 形状归一化的**唯一**实现。
  ///
  /// 坏数据一律按"没有覆盖"处理：它只影响"用哪一份数值"，读不回来时按默认
  /// （条目 ∪ 档案）解析，绝不猜用户的意图。**键不是 String 也降级**（不抛）：
  /// 反序列化出来的 JSON map 允许任意键类型，`Map<String, Object?>.from` 会抛
  /// `TypeError` 并让整张角色卡打不开。
  static CharacterRuleOverrides fromData(Object? raw) {
    if (raw is! Map) return empty;
    return CharacterRuleOverrides(
      disabledOriginIds: _stringSet(raw['disabledOriginIds']),
      pinned: _stringMap(raw['pinned']),
    );
  }

  /// [fromData] 的兼容入口（旧调用点传 `Map<String, Object?>`）。
  static CharacterRuleOverrides fromJson(Object? raw) => fromData(raw);

  final Set<String> disabledOriginIds;
  final Map<String, String> pinned;

  bool get isEmpty => disabledOriginIds.isEmpty && pinned.isEmpty;

  /// 持久化形状：**只写非空键**（没有覆盖的老角色序列化后逐字不变），来源 id 去重
  /// 后排序、pin 按列路径排序——同样输入写出同样的 JSON，diff 与测试稳定。
  Map<String, Object?> toData() => <String, Object?>{
    if (disabledOriginIds.isNotEmpty)
      'disabledOriginIds': disabledOriginIds.toList()..sort(),
    if (pinned.isNotEmpty)
      'pinned': <String, String>{
        for (final key in pinned.keys.toList()..sort()) key: pinned[key]!,
      },
  };

  /// 该来源是否被关掉。[originId] 可以是条目 id 或包 id，三向匹配的**唯一实现**
  /// 在 [RuleOverrideOrder.isDisabled]（解析器剔除来源 / pin 豁免 disabled 走的是
  /// 同一份），本方法只是薄封装——绝不在这里再内联第二份匹配，否则同一条用户选择
  /// 会在页面与派生结果里得到不同解释。
  bool isDisabled(String originId) =>
      RuleOverrideOrder.isDisabled(disabledOriginIds, originId);

  /// 关闭一个覆盖来源（幂等）。[originId] 可以是条目 id 或包 id。
  CharacterRuleOverrides disable(String originId) {
    final trimmed = originId.trim();
    if (trimmed.isEmpty) return this;
    return CharacterRuleOverrides(
      disabledOriginIds: <String>{...disabledOriginIds, trimmed},
      pinned: pinned,
    );
  }

  /// 重新打开（幂等）：无论传的是条目 id 还是包 id，都清掉该来源（含它所属包的
  /// 全部条目）的禁用记录。
  CharacterRuleOverrides enable(String originId) => CharacterRuleOverrides(
    disabledOriginIds: <String>{...disabledOriginIds}
      ..removeWhere(
        (value) =>
            value == originId ||
            value == _packageId(originId) ||
            _packageId(value) == originId,
      ),
    pinned: pinned,
  );

  /// 为某一列显式选定来源（冲突选择的落库形状）。
  CharacterRuleOverrides pin(String field, String originId) {
    final trimmedField = field.trim();
    final trimmedOrigin = originId.trim();
    if (trimmedField.isEmpty || trimmedOrigin.isEmpty) return this;
    return CharacterRuleOverrides(
      disabledOriginIds: disabledOriginIds,
      pinned: <String, String>{...pinned, trimmedField: trimmedOrigin},
    );
  }

  /// 条目 id 所属包 id；与 `RuleOverrideDeclaration.packageIdOf` **同一口径**
  /// （按最后一个 `:` 切分，包 id 允许含 `:`），不复制第二份切分逻辑。
  static String _packageId(String originId) =>
      RuleOverrideDeclaration.packageIdOf(originId);
}

/// 坏数据降级为"没有禁用"（不猜一个来源 id）。
Set<String> _stringSet(Object? raw) => raw is List
    ? <String>{
        for (final value in raw)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      }
    : const <String>{};

/// 坏数据降级为"没有 pin"（不猜一个来源 id）；键不是 String 的一并丢弃。
Map<String, String> _stringMap(Object? raw) {
  if (raw is! Map) return const <String, String>{};
  final result = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || key.trim().isEmpty) continue;
    if (value is! String || value.trim().isEmpty) continue;
    result[key.trim()] = value.trim();
  }
  return result;
}
