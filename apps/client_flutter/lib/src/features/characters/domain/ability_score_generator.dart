enum AbilityScoreMethod { standardArray, pointBuy, rolled }

abstract final class AbilityScoreGenerator {
  static const List<int> standardArray = [15, 14, 13, 12, 10, 8];
  static const int pointBuyBudget = 27;
  static const Map<int, int> _pointBuyCosts = {
    8: 0,
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    13: 5,
    14: 7,
    15: 9,
  };

  static int? pointBuyCost(int score) => _pointBuyCosts[score];

  static int pointBuySpent(Map<String, int> scores) {
    var spent = 0;
    for (final score in scores.values) {
      final cost = pointBuyCost(score);
      if (cost == null) return pointBuyBudget + 1;
      spent += cost;
    }
    return spent;
  }

  static int pointBuyRemaining(Map<String, int> scores) =>
      pointBuyBudget - pointBuySpent(scores);

  static bool canSetPointBuyScore(
    Map<String, int> scores,
    String ability,
    int nextScore,
  ) {
    if (!_pointBuyCosts.containsKey(nextScore)) return false;
    final next = Map<String, int>.from(scores)..[ability] = nextScore;
    return pointBuyRemaining(next) >= 0;
  }

  static int rollOne({required int Function(int maximum) nextInt}) {
    final dice = List<int>.generate(4, (_) => nextInt(6) + 1)..sort();
    return dice.skip(1).fold(0, (total, die) => total + die);
  }

  static List<int> rollSix({required int Function(int maximum) nextInt}) =>
      List<int>.generate(6, (_) => rollOne(nextInt: nextInt));

  static Map<String, int> assignByPriority({
    required List<int> scores,
    required List<String> priorities,
  }) {
    if (scores.length != priorities.length) {
      throw ArgumentError('Scores and priorities must have equal length');
    }
    final sorted = [...scores]..sort((left, right) => right.compareTo(left));
    return {
      for (var index = 0; index < priorities.length; index++)
        priorities[index]: sorted[index],
    };
  }
}
