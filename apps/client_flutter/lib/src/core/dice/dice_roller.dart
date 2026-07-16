import 'dart:math';

import 'package:dart_dice_parser/dart_dice_parser.dart' hide DiceRoller;

typedef NextInt = int Function(int max);

class DiceRoll {
  const DiceRoll({required this.notation, required this.total});

  final String notation;
  final int total;

  String get label => '$notation = $total';
}

class DiceRoller {
  factory DiceRoller({NextInt? nextInt}) {
    final random = Random();
    final resolvedNextInt = nextInt ?? random.nextInt;
    return DiceRoller._(
      nextInt: resolvedNextInt,
      random: _NextIntRandom(resolvedNextInt),
    );
  }

  DiceRoller._({required NextInt nextInt, required Random random})
    : _nextInt = nextInt,
      _random = random;

  final NextInt _nextInt;
  final Random _random;

  DiceRoll rollD20() {
    return DiceRoll(notation: 'd20', total: _nextInt(20) + 1);
  }

  DiceRoll rollExpression(String expression) {
    final notation = expression.trim();
    if (notation.isEmpty) {
      throw const DiceRollException('Dice expression is required.');
    }

    try {
      final summary = DiceExpression.create(notation, _random).roll();
      return DiceRoll(notation: notation, total: summary.total);
    } on FormatException catch (error) {
      throw DiceRollException('Invalid dice expression: ${error.message}');
    }
  }
}

class DiceRollException implements Exception {
  const DiceRollException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _NextIntRandom implements Random {
  _NextIntRandom(this._nextInt);

  final NextInt _nextInt;

  @override
  bool nextBool() => _nextInt(2) == 0;

  @override
  double nextDouble() => _nextInt(1 << 32) / (1 << 32);

  @override
  int nextInt(int max) => _nextInt(max);
}
