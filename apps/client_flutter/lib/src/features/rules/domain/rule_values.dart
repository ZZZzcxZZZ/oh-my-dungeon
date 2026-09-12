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
///
/// "未声明"与"显式空"必须可区分（§3.12）：作者写了 `{}` 表示该等级有法术位表但
/// 一个法术位也没有；完全没有给这一环阶则是**未声明**，由 archetype 回退决定。
/// 因此未声明等级不入 [_levels]，也不进 [_byLevel]。
class SlotTable {
  const SlotTable._(this._byLevel, this._levels, this.minLevel, this.maxLevel);

  /// 仅含**已显式声明**的等级；值可以是空表（显式 `{}`）。未声明等级不在此表内。
  final Map<int, Map<String, int>> _byLevel;

  /// 已显式声明的等级，升序；构造后不再改变。
  final List<int> _levels;
  final int minLevel;
  final int maxLevel;

  static SlotTable? tryParse(Object? raw) {
    final byLevel = <int, Map<String, int>>{};
    if (raw is List) {
      if (raw.isEmpty || raw.length > 20) return null;
      for (var index = 0; index < raw.length; index++) {
        final parsed = _slots(raw[index]);
        if (parsed.invalid) return null;
        final slots = parsed.slots;
        if (slots != null) byLevel[index + 1] = slots; // null = 未声明
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final level = int.tryParse('${entry.key}');
        if (level == null || level < 1 || level > 20) return null; // 未知键一律拒绝
        final parsed = _slots(entry.value);
        if (parsed.invalid) return null;
        final slots = parsed.slots;
        if (slots != null) byLevel[level] = slots; // null = 未声明
      }
    } else {
      return null;
    }
    if (byLevel.isEmpty) return null;
    final levels = byLevel.keys.toList()..sort();
    return SlotTable._(byLevel, levels, levels.first, levels.last);
  }

  static _SlotsResult _slots(Object? raw) {
    if (raw == null) return const _SlotsResult.undeclared();
    if (raw is! Map) return const _SlotsResult.invalid();
    final slots = <String, int>{};
    for (final slot in raw.entries) {
      final slotLevel = int.tryParse('${slot.key}');
      final count = slot.value is num ? (slot.value! as num).toInt() : null;
      if (slotLevel == null || slotLevel < 1 || slotLevel > 9) {
        return const _SlotsResult.invalid();
      }
      if (count == null || count < 0) return const _SlotsResult.invalid();
      // 显式 0 也写入：0 表示"该环阶位存在但上限为 0"，与"不写该环阶"不同（§3.12）。
      slots['$slotLevel'] = count;
    }
    return _SlotsResult.declared(slots);
  }

  /// null = 该等级未声明（低于最早声明等级），交由 archetype 回退；
  /// `{}` = 该等级显式声明为空（无法术位）。两者不能混为一谈（§3.12）。
  Map<String, int>? at(int level) => _valueAt(_byLevel, _levels, level);
}

/// [`SlotTable._slots`] 的解析结果：三态必须可区分（§3.12）。
class _SlotsResult {
  const _SlotsResult._(this.slots, this.invalid);
  const _SlotsResult.undeclared() : this._(null, false);

  /// [slots] 可以是空表：空表表示"显式声明为空"。
  const _SlotsResult.declared(Map<String, int> slots) : this._(slots, false);
  const _SlotsResult.invalid() : this._(null, true);

  /// null = 该等级未声明。
  final Map<String, int>? slots;
  final bool invalid;
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
    // 已废弃的写法：只要出现 `value` 键一律拒绝，不与 formula/table 组合放行。
    if (raw.containsKey('value')) return null;
    final hasFormula = raw.containsKey('formula');
    final hasTable = raw.containsKey('table');
    final kinds = [hasFormula, hasTable].where((flag) => flag).length;
    if (kinds != 1) return null;
    if (hasFormula) {
      final formula = raw['formula'];
      if (formula is! String || !isSupportedFormula(formula)) return null;
      return MaxSpec._(formula: formula, minimum: minimum);
    }
    final table = IntTable.tryParse(raw['table']);
    if (table == null) return null;
    return MaxSpec._(table: table, minimum: minimum);
  }

  /// 返回 `int?`：表在该等级**未声明**时返回 null（调用方跳过），不静默变 0（§3.12）。
  int? resolve({required int level, required Map<String, int> abilities}) {
    final raw = switch (this) {
      MaxSpec(value: final v?) => v,
      MaxSpec(formula: final f?) => _evaluate(f, level, abilities),
      _ => table!.at(level),
    };
    if (raw == null) return null;
    return minimum == null || raw >= minimum! ? raw : minimum!;
  }
}

const _formulaPattern = r'^(level|ability:[a-z]{3}|(\d+)\*level|(\d+))$';

bool isSupportedFormula(String formula) =>
    RegExp(_formulaPattern).hasMatch(formula);

/// 从 `formula: "ability:<key>"` 里取出属性键；不是 ability 公式时返回 null。
///
/// 属性键是否**落在档案 `abilities` 内**的判据在导入期有两处调用：grant 的
/// `formula` 与 `classRules.resources[].maximum.formula`（§3.4、§3.12）。
/// 这是"从 formula 里取键"的**唯一实现点**：两处都读它，不得各写一份
/// `substring('ability:'.length)`，否则两种 formula 的位置口径会分叉。
String? abilityKeyInFormula(String formula) {
  const prefix = 'ability:';
  if (!formula.startsWith(prefix)) return null;
  return formula.substring(prefix.length);
}

int _evaluate(String formula, int level, Map<String, int> abilities) {
  if (formula == 'level') return level;
  // 取键走同一个 [abilityKeyInFormula]，不在运行期再写一份 substring。
  final abilityKey = abilityKeyInFormula(formula);
  if (abilityKey != null) {
    return abilityModifier(abilities[abilityKey] ?? 10);
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
