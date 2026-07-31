import 'package:dnd_table_client/src/features/characters/domain/equipment_cost.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes D&D denominations and quantities to copper', () {
    expect(EquipmentCost.parse('15 GP')?.copperPieces, 1500);
    expect(EquipmentCost.parse('2 sp')?.copperPieces, 20);
    expect(EquipmentCost.parse('5 CP')?.copperPieces, 5);
    expect(EquipmentCost.parse('1 PP')?.copperPieces, 1000);
    expect(EquipmentCost.parse('15 GP')! * 2, const EquipmentCost(3000));
  });

  test('formats totals readably and leaves unknown prices unpriced', () {
    expect(const EquipmentCost(1523).format(), '15 GP 2 SP 3 CP');
    expect(EquipmentCost.parse('价格待定'), isNull);
  });

  test('extracts the suggested gold budget from a class equipment choice', () {
    expect(
      EquipmentCost.suggestedBudget('选择A或B：(A) 长剑和盾牌；或(B) 150GP'),
      const EquipmentCost(15000),
    );
  });
}
