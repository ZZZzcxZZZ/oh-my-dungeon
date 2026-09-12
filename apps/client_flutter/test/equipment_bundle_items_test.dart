import 'package:dnd_table_client/src/features/characters/domain/equipment_bundle_items.dart';
import 'package:flutter_test/flutter_test.dart';

// 任务 8 / 契约 §3.11 A2：`equipmentBundle.structured` 的唯一解析点。
void main() {
  test('structured.items = [{name, quantity}]，quantity 缺省 1，非法项跳过', () {
    final items = EquipmentBundleItems.from(const {
      'items': [
        {'name': '长剑', 'quantity': 1},
        {'name': '背包'},
        {'quantity': 3},
        'junk',
      ],
      'currency': {'gp': 10, 'sp': 5},
      'itemTemplate': {'ignored': true},
    });

    expect(items.items, [
      {'name': '长剑', 'quantity': 1},
      {'name': '背包', 'quantity': 1},
    ]);
    expect(items.currency, {'cp': 0, 'sp': 5, 'ep': 0, 'gp': 10, 'pp': 0});
  });

  test('无 items / 无 currency 一律返回空，不猜', () {
    final items = EquipmentBundleItems.from(const {});
    expect(items.items, isEmpty);
    expect(items.currency.values.every((v) => v == 0), isTrue);
  });

  test('itemTemplate 一律忽略（客户端不消费模板）', () {
    final items = EquipmentBundleItems.from(const {
      'itemTemplate': {
        'items': [
          {'name': '模板里的东西', 'quantity': 2},
        ],
        'currency': {'gp': 999},
      },
    });

    expect(items.items, isEmpty);
    expect(items.currency['gp'], 0);
  });

  test('非正整数 / 非法名称的元素跳过，不编造 entryId', () {
    final items = EquipmentBundleItems.from(const {
      'items': [
        {'name': '盾牌', 'quantity': 0},
        {'name': '长弓', 'quantity': -2},
        {'name': '短剑', 'quantity': '3'},
        {'name': '  '},
        {'name': '匕首', 'quantity': 2},
      ],
      'currency': {'cp': 12, 'ep': 'x', 'pp': 1.5},
    });

    expect(items.items, [
      {'name': '匕首', 'quantity': 2},
    ]);
    expect(items.items.single.containsKey('entryId'), isFalse);
    expect(items.currency, {'cp': 12, 'sp': 0, 'ep': 0, 'gp': 0, 'pp': 1});
  });
}
