import 'package:dnd_table_client/src/features/characters/domain/ability_score_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard array spends exactly the 27 point-buy budget', () {
    final scores = {
      'str': 15,
      'dex': 14,
      'con': 13,
      'int': 12,
      'wis': 10,
      'cha': 8,
    };

    expect(AbilityScoreGenerator.pointBuySpent(scores), 27);
    expect(AbilityScoreGenerator.pointBuyRemaining(scores), 0);
  });

  test('point-buy costs follow the 2024 8 through 15 table', () {
    expect(
      [
        for (var score = 8; score <= 15; score++)
          AbilityScoreGenerator.pointBuyCost(score),
      ],
      [0, 1, 2, 3, 4, 5, 7, 9],
    );
    expect(AbilityScoreGenerator.pointBuyCost(7), isNull);
    expect(AbilityScoreGenerator.pointBuyCost(16), isNull);
  });

  test('4d6 generation drops the lowest die for each score', () {
    final rolls = <int>[
      5,
      4,
      3,
      0,
      5,
      5,
      1,
      1,
      3,
      3,
      3,
      3,
      2,
      2,
      2,
      0,
      4,
      4,
      3,
      2,
      5,
      5,
      5,
      5,
    ].iterator;

    final scores = AbilityScoreGenerator.rollSix(
      nextInt: (_) {
        rolls.moveNext();
        return rolls.current;
      },
    );

    expect(scores, [15, 14, 12, 9, 14, 18]);
  });

  test('rolled scores are assigned by class priority', () {
    final assigned = AbilityScoreGenerator.assignByPriority(
      scores: [12, 18, 10, 15, 13, 8],
      priorities: const ['int', 'con', 'dex', 'wis', 'cha', 'str'],
    );

    expect(assigned, {
      'int': 18,
      'con': 15,
      'dex': 13,
      'wis': 12,
      'cha': 10,
      'str': 8,
    });
  });
}
