import 'dart:math';

typedef NextInt = int Function(int max);

class DiceRoll {
  const DiceRoll({required this.notation, required this.total});

  final String notation;
  final int total;

  String get label => '$notation = $total';
}

class DiceRoller {
  DiceRoller({NextInt? nextInt}) : _nextInt = nextInt ?? Random().nextInt;

  final NextInt _nextInt;

  DiceRoll rollD20() {
    return DiceRoll(notation: 'd20', total: _nextInt(20) + 1);
  }
}
