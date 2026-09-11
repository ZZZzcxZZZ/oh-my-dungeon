import 'rule_math.dart';

/// `Table<int>`：长度 ≤20 的数组，或稀疏 `{"<等级>": 值}`（键 1..20）。
/// 取值语义（§3.12）：高于最后声明等级 → 沿用最后声明值；低于最早声明等级 → null（未声明）。
class IntTable {
  const IntTable._(this._byLevel, this._levels, this.minLevel, this.maxLevel);

  final Map<int, int> _byLevel;

  /// 已声明等级，升序；构造后不再改变。
  final List<int> _levels;
  final int minLevel;
  final int maxLevel;

  static IntTable? tryParse(Object? raw) {
    final byLevel = _expandInt(raw);
    if (byLevel == null || byLevel.isEmpty) return null;
    if (byLevel.values.any((value) => value < 0)) return null;
    final levels = byLevel.keys.toList()..sort();
    return IntTable._(byLevel, levels, levels.first, levels.last);
  }

  int? at(int level) => _valueAt(_byLevel, _levels, level);
}

/// `Table<{环阶: 数量}>`：法术位。整级替换语义 + §3.12 的两条取值规则。
class SlotTable {
  const SlotTable._(this._byLevel, this._levels, this.minLevel, this.maxLevel);

  final Map<int, Map<String, int>> _byLevel;

  /// 已声明等级，升序；构造后不再改变。
  final List<int> _levels;
  final int minLevel;
  final int maxLevel;

  static SlotTable? tryParse(Object? raw) {
    final byLevel = <int, Map<String, int>>{};
    if (raw is List) {
      if (raw.isEmpty || raw.length > 20) return null;
      for (var index = 0; index < raw.length; index++) {
        final parsed = _slots(raw[index], index + 1);
        if (parsed == null) return null;
        byLevel[index + 1] = parsed;
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final level = int.tryParse('${entry.key}');
        if (level == null || level < 1 || level > 20) return null; // 未知键一律拒绝
        final parsed = _slots(entry.value, level);
        if (parsed == null) return null;
        byLevel[level] = parsed;
      }
    } else {
      return null;
    }
    if (byLevel.isEmpty) return null;
    final levels = byLevel.keys.toList()..sort();
    return SlotTable._(byLevel, levels, levels.first, levels.last);
  }

  static Map<String, int>? _slots(Object? raw, int level) {
    if (raw == null) return const <String, int>{};
    if (raw is! Map) return null;
    final slots = <String, int>{};
    for (final slot in raw.entries) {
      final slotLevel = int.tryParse('${slot.key}');
      final count = slot.value is num ? (slot.value! as num).toInt() : null;
      if (slotLevel == null || slotLevel < 1 || slotLevel > 9) return null;
      if (count == null || count < 0) return null;
      if (count > 0) slots['$slotLevel'] = count;
    }
    return slots;
  }

  /// null = 该等级未声明（低于最早声明等级），交由 archetype 回退。
  Map<String, int>? at(int level) => _valueAt(_byLevel, _levels, level);
}

/// `Table<String>`：与 [IntTable] 同一套"常量或表"语义，用于随等级变化的枚举值（如 `recovery`）。
class StringTable {
  const StringTable._(this._byLevel, this._levels, this.minLevel, this.maxLevel);

  final Map<int, String> _byLevel;

  /// 已声明等级，升序；构造后不再改变。
  final List<int> _levels;
  final int minLevel;
  final int maxLevel;

  static StringTable? tryParse(Object? raw, Set<String> allowed) {
    final result = <int, String>{};
    if (raw is List) {
      if (raw.isEmpty || raw.length > 20) return null;
      for (var index = 0; index < raw.length; index++) {
        final value = '${raw[index]}'.trim();
        if (!allowed.contains(value)) return null;
        result[index + 1] = value;
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final level = int.tryParse('${entry.key}');
        final value = '${entry.value}'.trim();
        if (level == null || level < 1 || level > 20) return null;
        if (!allowed.contains(value)) return null;
        result[level] = value;
      }
    } else {
      return null;
    }
    if (result.isEmpty) return null;
    final levels = result.keys.toList()..sort();
    return StringTable._(result, levels, levels.first, levels.last);
  }

  String? at(int level) => _valueAt(_byLevel, _levels, level);
}

/// `Table<T>` 的唯一取值实现（§3.1 + §3.12），三种表共用，保证语义不会各自漂移：
/// 取"不超过 [level] 的最大已声明档位"的值；高于最后声明等级 → 沿用最后声明值；
/// 低于最早声明等级 → null（未声明，不借用更高等级的值）。
T? _valueAt<T>(Map<int, T> byLevel, List<int> declaredLevels, int level) {
  if (declaredLevels.isEmpty || level < declaredLevels.first) return null;
  var found = declaredLevels.first;
  for (final declared in declaredLevels) {
    if (declared > level) break;
    found = declared;
  }
  return byLevel[found];
}

/// 资源上限：整数，或 `{"formula": "…"}` / `{"table": <Table<int>>}`，对象形态可带 `minimum`。
class MaxSpec {
  const MaxSpec._({this.value, this.formula, this.table, this.minimum});

  final int? value;
  final String? formula;
  final IntTable? table;
  final int? minimum;

  static MaxSpec? tryParse(Object? raw) {
    if (raw is num) {
      final value = raw.toInt();
      return value < 0 ? null : MaxSpec._(value: value);
    }
    if (raw is! Map) return null;
    final minimum = raw['minimum'] is num ? (raw['minimum']! as num).toInt() : null;
    if (minimum != null && minimum < 0) return null;
    final hasFormula = raw.containsKey('formula');
    final hasTable = raw.containsKey('table');
    final kinds = [hasFormula, hasTable].where((flag) => flag).length;
    if (kinds != 1) return null;
    if (raw.containsKey('value')) return null; // 已废弃的写法，明确拒绝
    if (hasFormula) {
      final formula = raw['formula'];
      if (formula is! String || !isSupportedFormula(formula)) return null;
      return MaxSpec._(formula: formula, minimum: minimum);
    }
    final table = IntTable.tryParse(raw['table']);
    if (table == null) return null;
    return MaxSpec._(table: table, minimum: minimum);
  }

  int resolve({required int level, required Map<String, int> abilities}) {
    final raw = switch (this) {
      MaxSpec(value: final v?) => v,
      MaxSpec(formula: final f?) => _evaluate(f, level, abilities),
      _ => table!.at(level) ?? 0,
    };
    return minimum == null || raw >= minimum! ? raw : minimum!;
  }
}

const _formulaPattern = r'^(level|ability:[a-z]{3}|(\d+)\*level|(\d+))$';

bool isSupportedFormula(String formula) =>
    RegExp(_formulaPattern).hasMatch(formula);

int _evaluate(String formula, int level, Map<String, int> abilities) {
  if (formula == 'level') return level;
  if (formula.startsWith('ability:')) {
    return abilityModifier(abilities[formula.substring(8)] ?? 10);
  }
  if (formula.endsWith('*level')) {
    return int.parse(formula.substring(0, formula.length - 6)) * level;
  }
  return int.parse(formula);
}

/// 解析"长度 ≤20 的数组"或"稀疏 map"；非法输入返回 null。
Map<int, int>? _expandInt(Object? raw) {
  final result = <int, int>{};
  if (raw is List) {
    if (raw.isEmpty || raw.length > 20) return null;
    for (var index = 0; index < raw.length; index++) {
      final value = raw[index];
      if (value is! num) return null;
      result[index + 1] = value.toInt();
    }
    return result;
  }
  if (raw is Map) {
    for (final entry in raw.entries) {
      final level = int.tryParse('${entry.key}');
      if (level == null || level < 1 || level > 20) return null; // 未知键一律拒绝
      final value = entry.value;
      if (value is! num) return null;
      result[level] = value.toInt();
    }
    return result;
  }
  return null;
}
