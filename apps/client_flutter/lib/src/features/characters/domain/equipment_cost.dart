class EquipmentCost {
  const EquipmentCost(this.copperPieces);

  final int copperPieces;

  static const _rates = <String, int>{
    'CP': 1,
    'SP': 10,
    'EP': 50,
    'GP': 100,
    'PP': 1000,
  };

  static EquipmentCost? parse(Object? raw) {
    final text = '$raw'.trim();
    final matches = RegExp(
      r'(\d+(?:\.\d+)?)\s*(CP|SP|EP|GP|PP)',
      caseSensitive: false,
    ).allMatches(text);
    var copper = 0.0;
    var found = false;
    for (final match in matches) {
      final amount = double.tryParse(match.group(1) ?? '');
      final rate = _rates[(match.group(2) ?? '').toUpperCase()];
      if (amount == null || rate == null) continue;
      found = true;
      copper += amount * rate;
    }
    return found ? EquipmentCost(copper.round()) : null;
  }

  static EquipmentCost? suggestedBudget(Object? startingEquipment) {
    final text = '$startingEquipment';
    final optionB = RegExp(
      r'(?:B[\)）]|或\s*B).*?(\d+(?:\.\d+)?)\s*GP',
      caseSensitive: false,
    ).firstMatch(text);
    if (optionB != null) return parse('${optionB.group(1)} GP');
    final prices =
        RegExp(r'\d+(?:\.\d+)?\s*(?:CP|SP|EP|GP|PP)', caseSensitive: false)
            .allMatches(text)
            .map((match) => parse(match.group(0)))
            .whereType<EquipmentCost>();
    if (prices.isEmpty) return null;
    return prices.reduce(
      (left, right) => left.copperPieces >= right.copperPieces ? left : right,
    );
  }

  EquipmentCost operator *(int quantity) {
    return EquipmentCost(copperPieces * quantity);
  }

  EquipmentCost operator +(EquipmentCost other) {
    return EquipmentCost(copperPieces + other.copperPieces);
  }

  String format() {
    var remaining = copperPieces;
    final parts = <String>[];
    for (final denomination in const ['GP', 'SP', 'CP']) {
      final rate = _rates[denomination]!;
      final amount = remaining ~/ rate;
      if (amount > 0) {
        parts.add('$amount $denomination');
        remaining %= rate;
      }
    }
    return parts.isEmpty ? '0 CP' : parts.join(' ');
  }

  @override
  bool operator ==(Object other) {
    return other is EquipmentCost && other.copperPieces == copperPieces;
  }

  @override
  int get hashCode => copperPieces.hashCode;
}
