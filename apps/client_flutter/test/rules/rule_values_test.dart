// test/rules/rule_values_test.dart
import 'package:dnd_table_client/src/features/rules/domain/rule_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntTable', () {
    test('完整 20 项数组', () {
      final table = IntTable.tryParse(List.generate(20, (i) => i + 1))!;
      expect(table.minLevel, 1);
      expect(table.maxLevel, 20);
      expect(table.at(1), 1);
      expect(table.at(20), 20);
    });

    test('短数组合法：只声明 1..3 级，4 级以上沿用最后值', () {
      final table = IntTable.tryParse([3, 4, 5])!;
      expect(table.at(1), 3);
      expect(table.at(3), 5);
      expect(table.at(9), 5, reason: '高于最后声明等级 → 沿用');
      expect(table.at(20), 5);
    });

    test('稀疏表：高于最后声明沿用，低于最早声明为未声明', () {
      final table = IntTable.tryParse({'5': 7, '9': 11})!;
      expect(table.at(4), isNull, reason: '低于最早声明 → 未声明（不借用 5 级的值）');
      expect(table.at(5), 7);
      expect(table.at(8), 7);
      expect(table.at(9), 11);
      expect(table.at(20), 11);
    });

    test('非法输入返回 null', () {
      expect(IntTable.tryParse([]), isNull);
      expect(IntTable.tryParse(List.filled(21, 1)), isNull);
      expect(IntTable.tryParse({'0': 1}), isNull);
      expect(IntTable.tryParse({'1': -1}), isNull);
      expect(IntTable.tryParse('nope'), isNull);
    });
  });

  group('SlotTable', () {
    test('稀疏表：未声明等级为 null，高于最后声明沿用', () {
      final table = SlotTable.tryParse({'5': {'1': 4, '2': 2}})!;
      expect(table.at(5), {'1': 4, '2': 2});
      expect(table.at(4), isNull, reason: '低于最早声明 → 未声明');
      expect(table.at(9), {'1': 4, '2': 2}, reason: '高于最后声明 → 沿用');
    });

    test('短数组合法', () {
      final table = SlotTable.tryParse([{'1': 2}, {'1': 3}, {'1': 3}])!;
      expect(table.at(1), {'1': 2});
      expect(table.at(3), {'1': 3});
      expect(table.at(20), {'1': 3});
    });

    test('非法环阶与负值返回 null', () {
      expect(SlotTable.tryParse({'1': {'0': 1}}), isNull);
      expect(SlotTable.tryParse({'1': {'10': 1}}), isNull);
      expect(SlotTable.tryParse({'1': {'1': -1}}), isNull);
      expect(SlotTable.tryParse({'21': {'1': 1}}), isNull);
    });

    test('中间等级取"不超过当前等级的最大已声明档位"', () {
      final table = SlotTable.tryParse({'2': {'1': 2}, '9': {'1': 9}})!;
      expect(table.at(7), {'1': 2}, reason: '7 级未声明，应沿用 2 级的值而不是 9 级');
    });
  });

  group('StringTable', () {
    const allowed = {'longRest', 'shortRest', 'shortRestOne', 'none'};

    test('短数组合法：高于最后声明沿用最后值', () {
      final table = StringTable.tryParse(['longRest', 'shortRest'], allowed)!;
      expect(table.minLevel, 1);
      expect(table.maxLevel, 2);
      expect(table.at(1), 'longRest');
      expect(table.at(2), 'shortRest');
      expect(table.at(20), 'shortRest');
    });

    test('稀疏表：中间沿用已声明档位，低于最早声明为未声明', () {
      final table = StringTable.tryParse(
        {'1': 'longRest', '5': 'shortRest'},
        allowed,
      )!;
      expect(table.at(1), 'longRest');
      expect(table.at(4), 'longRest', reason: '不超过当前等级的最大已声明档位');
      expect(table.at(5), 'shortRest');
      expect(table.at(20), 'shortRest');
      final onlyFive = StringTable.tryParse({'5': 'shortRest'}, allowed)!;
      expect(onlyFive.at(4), isNull, reason: '低于最早声明 → 未声明（不借用 5 级的值）');
    });

    test('非法枚举值、越界键与非法长度返回 null', () {
      expect(StringTable.tryParse(['longRest', 'sometimes'], allowed), isNull);
      expect(StringTable.tryParse({'1': 'sometimes'}, allowed), isNull);
      expect(StringTable.tryParse({'0': 'longRest'}, allowed), isNull);
      expect(StringTable.tryParse({'21': 'longRest'}, allowed), isNull);
      expect(StringTable.tryParse([], allowed), isNull);
      expect(StringTable.tryParse(List.filled(21, 'longRest'), allowed), isNull);
      expect(StringTable.tryParse(null, allowed), isNull);
    });
  });

  group('MaxSpec', () {
    const abilities = {'str': 8, 'dex': 10, 'con': 14, 'int': 12, 'wis': 16, 'cha': 20};

    test('整数固定值', () {
      expect(MaxSpec.tryParse(3)!.resolve(level: 5, abilities: abilities), 3);
      expect(MaxSpec.tryParse({'value': 3}), isNull, reason: '没有 {"value": n} 这种写法');
    });

    test('等级与系数×等级', () {
      expect(MaxSpec.tryParse({'formula': 'level'})!.resolve(level: 7, abilities: abilities), 7);
      expect(MaxSpec.tryParse({'formula': '5*level'})!.resolve(level: 4, abilities: abilities), 20);
    });

    test('属性调整值与 minimum 下限', () {
      final cha = MaxSpec.tryParse({'formula': 'ability:cha'})!;
      expect(cha.resolve(level: 1, abilities: abilities), 5);
      final wis = MaxSpec.tryParse({'formula': 'ability:wis', 'minimum': 1})!;
      expect(wis.resolve(level: 1, abilities: abilities), 3);
      final str = MaxSpec.tryParse({'formula': 'ability:str', 'minimum': 1})!;
      expect(str.resolve(level: 1, abilities: abilities), 1);
    });

    test('等级表：稀疏、短数组、向上沿用', () {
      final sparse = MaxSpec.tryParse({'table': {'1': 2, '17': 6}})!;
      expect(sparse.resolve(level: 10, abilities: abilities), 2);
      expect(sparse.resolve(level: 17, abilities: abilities), 6);
      expect(sparse.resolve(level: 20, abilities: abilities), 6);
      final short = MaxSpec.tryParse({'table': [2, 2, 3]})!;
      expect(short.resolve(level: 20, abilities: abilities), 3);
    });

    test('表未声明的等级返回 null 而不是 0（§3.12）', () {
      final sparse = MaxSpec.tryParse({'table': {'3': 1, '7': 2}})!;
      expect(sparse.resolve(level: 2, abilities: abilities), isNull,
          reason: '低于最早声明等级 → 未声明，不得成为 0 次');
      expect(sparse.resolve(level: 3, abilities: abilities), 1);
      // 显式写 0 与"未声明"语义不同：0 表示存在但上限为 0
      final zero = MaxSpec.tryParse({'table': {'1': 0, '5': 2}})!;
      expect(zero.resolve(level: 1, abilities: abilities), 0);
      expect(zero.resolve(level: 4, abilities: abilities), 0);
    });

    test('封闭语法之外一律拒绝', () {
      for (final bad in ['prof', 'level*2', 'ability', 'ability:luck', '1+1', '']) {
        expect(MaxSpec.tryParse({'formula': bad}), isNull, reason: bad);
      }
      expect(MaxSpec.tryParse({'formula': 'level', 'table': {'1': 1}}), isNull); // 同时给两种
      expect(MaxSpec.tryParse({'formula': 'level', 'minimum': -1}), isNull);
      expect(MaxSpec.tryParse(null), isNull);
    });
  });
}
