import 'package:dnd_table_client/src/features/rooms/domain/dice_roller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rolls a d20 with a minimum result of 1', () {
    final roller = DiceRoller(nextInt: (_) => 0);

    final roll = roller.rollD20();

    expect(roll.notation, 'd20');
    expect(roll.total, 1);
    expect(roll.label, 'd20 = 1');
  });

  test('rolls a d20 with a maximum result of 20', () {
    final roller = DiceRoller(nextInt: (_) => 19);

    final roll = roller.rollD20();

    expect(roll.notation, 'd20');
    expect(roll.total, 20);
    expect(roll.label, 'd20 = 20');
  });

  test('rolls a dice expression with modifiers', () {
    final roller = DiceRoller(nextInt: (_) => 0);

    final roll = roller.rollExpression('1d6+4');

    expect(roll.notation, '1d6+4');
    expect(roll.total, 5);
    expect(roll.label, '1d6+4 = 5');
  });

  test('rejects a blank dice expression', () {
    final roller = DiceRoller();

    expect(
      () => roller.rollExpression('   '),
      throwsA(isA<DiceRollException>()),
    );
  });
}
