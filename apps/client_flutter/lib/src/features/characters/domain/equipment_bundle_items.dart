/// `equipmentBundle` 条目的物品与货币（契约 §3.11 A2）：
/// `structured.items = [{name, quantity}]`、`structured.currency = {cp,sp,ep,gp,pp}`。
///
/// `structured.itemTemplate` **一律忽略**（客户端不消费：模板合成不在本轮范围）。
///
/// 这是该结构的**唯一解析点**：builder（写 `inventory` / `currency`）与将来的详情页
/// 若要展示方案内容都必须调它，不得各自读 `structured` 字段名。
class EquipmentBundleItems {
  const EquipmentBundleItems({required this.items, required this.currency});

  /// 逐条库存行：`{'name': <非空名称>, 'quantity': <正整数>}`（值恒非空，因此类型是
  /// `Map<String, Object>`，可直接并入 `CharacterEditDraft.inventory`）。
  ///
  /// **不编造 `entryId`**：方案里的物品是名字而非条目引用（方案条目本身不是库存
  /// 物品）；非法元素（非对象 / 名称为空 / 数量非正）直接跳过，不猜。
  final List<Map<String, Object>> items;

  /// 货币合计的键集合固定为 [currencyKeys]，未声明的币种为 `0`（"没有"是 0 枚，
  /// 不是"未声明"——货币面板按 5 个币种显示）。
  final Map<String, int> currency;

  /// 货币币种的**唯一**键顺序（`cp → pp`，与 D&D 2025 角色卡一致）。
  static const currencyKeys = <String>['cp', 'sp', 'ep', 'gp', 'pp'];

  static EquipmentBundleItems from(Map<String, Object?> structured) {
    return EquipmentBundleItems(
      items: List<Map<String, Object>>.unmodifiable(_items(structured)),
      currency: Map<String, int>.unmodifiable(_currency(structured)),
    );
  }

  static List<Map<String, Object>> _items(Map<String, Object?> structured) {
    final raw = structured['items'];
    if (raw is! List) return const <Map<String, Object>>[];
    final items = <Map<String, Object>>[];
    for (final element in raw) {
      if (element is! Map) continue;
      final name = '${element['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final quantity = _quantity(element['quantity']);
      if (quantity == null) continue;
      items.add(<String, Object>{'name': name, 'quantity': quantity});
    }
    return items;
  }

  /// `quantity` 缺省 `1`；显式写了但不是正整数（0 / 负数 / 非数字）视为非法 → null。
  static int? _quantity(Object? value) {
    if (value == null) return 1;
    if (value is num && value.isFinite && value == value.toInt()) {
      final quantity = value.toInt();
      return quantity > 0 ? quantity : null;
    }
    return null;
  }

  static Map<String, int> _currency(Map<String, Object?> structured) {
    final raw = structured['currency'];
    final currency = <String, int>{for (final key in currencyKeys) key: 0};
    if (raw is! Map) return currency;
    for (final key in currencyKeys) {
      final value = raw[key];
      if (value is num && value.isFinite) {
        currency[key] = value.toInt();
      }
    }
    return currency;
  }
}
