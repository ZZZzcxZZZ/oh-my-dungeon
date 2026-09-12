// 诊断顺序约定（全库统一，见 §3.2 契约）：**进入子结构前先报该层未知键**。
// 顶层未知键在解析任何字段之前报出；`spellcasting` 与 `resources[i]` 这类子结构的
// 未知键，也在解析该结构的内容之前报出。diagnostics 顺序因此与"阅读顺序"一致。
import 'rule_diagnostic.dart';
import 'rule_values.dart';

const kDefaultAbilities = {'str', 'dex', 'con', 'int', 'wis', 'cha'};

// 技能清单**没有**生产常量：唯一权威是档案 `skills`（§3.1），运行期经
// `Dnd5eRules.skills` 派生（名字 + 属性键）。这里刻意不留第二份名字表，
// 否则清单会与档案漂移，`optionType: "skill"` 的选项与角色卡技能行对不上，
// 熟练会被静默丢弃。

/// `classRules.<slug>` 顶层允许的字段（§3.2）。
const kClassRuleFields = {
  'hitDie',
  'savingThrowAbilities',
  'spellcasting',
  'resources',
};

/// `progressions.<name>` 允许的字段（§3.1）。原型**只承载跨职业共享**的进阶量；
/// `prepared` / `cantrips` 逐职业不同，写在 `classRules.<slug>.spellcasting` 里。
/// 出现白名单之外的键在解析期就报 `unknownField`，不靠注释或测试兜底。
const kProgressionFields = {
  'slots',
  'slotLevel',
  'maximumSpellLevel',
  'minimumLevel',
};

/// `classRules.<slug>.spellcasting` 允许的字段（§3.3）。
const kSpellcastingFields = {
  'mode',
  'ability',
  'listTags',
  'archetype',
  'slots',
  'slotLevel',
  'prepared',
  'cantrips',
  'maximumSpellLevel',
};

/// `classRules.<slug>.resources[]` 允许的字段（§3.4）。
const kResourceFields = {
  'id',
  'name',
  'maximum',
  'recovery',
  'startsAtLevel',
  'description',
};

/// 标准生命骰骰面（§3.2）：生命骰只可能是这五种；d7/d9/d20 一律拒绝。
const kStandardHitDieFaces = {4, 6, 8, 10, 12};

/// 法术选择模型（§3.3）：契约魔法**不在这里**表示，唯一信号是
/// `spellcasting.archetype == 'pact'`。
const _modes = {'prepared', 'known', 'none'};
const _recoveries = {'shortRest', 'shortRestOne', 'longRest', 'none'};

void _addError(
  List<RuleDiagnostic> out,
  String path,
  String code,
  String message,
) => out.add(
  RuleDiagnostic(
    path: path,
    severity: RuleSeverity.error,
    code: code,
    message: message,
  ),
);

void _addWarning(
  List<RuleDiagnostic> out,
  String path,
  String code,
  String message,
) => out.add(
  RuleDiagnostic(
    path: path,
    severity: RuleSeverity.warning,
    code: code,
    message: message,
  ),
);

/// 报告 [raw] 中不在 [allowed] 里的键（顺序约定见文件头）。
/// [path] 是该结构自身的路径；[suggestion] 可为顶层键补"是否想写…"提示。
void _reportUnknownFields(
  Map<Object?, Object?> raw,
  Set<String> allowed,
  String path,
  List<RuleDiagnostic> diagnostics, {
  String Function(String key)? suggestion,
}) {
  for (final key in raw.keys) {
    final name = '$key';
    if (allowed.contains(name)) continue;
    _addError(
      diagnostics,
      '$path.$name',
      'unknownField',
      '未知字段 $name${suggestion?.call(name) ?? ''}',
    );
  }
}

/// `classRules.resources[]` 的一条资源（§3.4）。
class ClassResourceRule {
  const ClassResourceRule({
    required this.id,
    required this.name,
    required this.maximum,
    required this.recovery,
    this.recoveryTable,
    this.startsAtLevel = 1,
    this.description,
  });

  final String id;
  final String name;

  /// 可选的一句话说明（**档案里禁止出现**，见 §3.1；第三方包可用）。
  final String? description;

  final MaxSpec maximum;

  /// 常量恢复语义（未随等级变化时）。
  ///
  /// **表形态（[recoveryTable] != null）时为 null**：表在 `minLevel` 的值不是
  /// "该资源的恢复语义"，合成写回会让调用方拿到一个貌似权威的常量（§3.4 双表示
  /// 歧义）。读取一律走 [recoveryAt]；[recovery] 只在常量形态下有值。
  final String? recovery;

  /// 随等级变化的恢复语义（如诗人激励 1 级长休、5 级短休）。
  final StringTable? recoveryTable;

  final int startsAtLevel;

  /// 恢复语义的唯一读取口：常量形态返回该常量；表形态按等级取值，
  /// 低于表的最早声明等级（未声明）时回退到默认 `longRest`。
  String recoveryAt(int level) {
    final table = recoveryTable;
    if (table == null) return recovery ?? 'longRest';
    return table.at(level) ?? 'longRest';
  }

  /// 资源表声明到的最高等级；只有 formula 的资源不贡献等级。
  int? get declaredMaxLevel => maximum.table?.maxLevel;

  /// 资源表声明到的最早等级；只有 formula 的资源不贡献等级。
  int? get declaredMinLevel => maximum.table?.minLevel;
}

/// `classRules.spellcasting`（§3.3）。只做形状校验，原型是否存在由调用方校验。
class ClassSpellcasting {
  const ClassSpellcasting({
    required this.mode,
    this.ability,
    this.listTags = const [],
    this.archetype,
    this.slots,
    this.slotLevel,
    this.prepared,
    this.cantrips,
    this.maximumSpellLevel,
  });

  final String mode;
  final String? ability;
  final List<String> listTags;
  final String? archetype;
  final SlotTable? slots;
  final IntTable? slotLevel;
  final IntTable? prepared;
  final IntTable? cantrips;
  final IntTable? maximumSpellLevel;

  /// 各表声明到的最高等级（供 declaredMaxLevel 汇总）。
  List<int> get declaredMaxLevels => [
    if (slots != null) slots!.maxLevel,
    if (slotLevel != null) slotLevel!.maxLevel,
    if (prepared != null) prepared!.maxLevel,
    if (cantrips != null) cantrips!.maxLevel,
    if (maximumSpellLevel != null) maximumSpellLevel!.maxLevel,
  ];

  /// 各表声明到的最早等级（供 declaredMinLevel 汇总）。
  List<int> get declaredMinLevels => [
    if (slots != null) slots!.minLevel,
    if (slotLevel != null) slotLevel!.minLevel,
    if (prepared != null) prepared!.minLevel,
    if (cantrips != null) cantrips!.minLevel,
    if (maximumSpellLevel != null) maximumSpellLevel!.minLevel,
  ];
}

/// 职业规则块（§3.2，载体 A 档案 `classes.<slug>` 与载体 B
/// `structured.classRules` 同一形状）。
///
/// 只有 4 个"数值事实"字段：`hitDie` / `savingThrowAbilities` /
/// `spellcasting` / `resources`；技能与法术选择属于 `rules.choices`，
/// 不在此处（§3.2、§3.10）。
class ClassRuleSet {
  const ClassRuleSet({
    this.hitDie,
    this.savingThrowAbilities = const {},
    this.spellcasting,
    this.resources = const [],
    this.fields = const {},
  });

  final int? hitDie;
  final Set<String> savingThrowAbilities;
  final ClassSpellcasting? spellcasting;
  final List<ClassResourceRule> resources;

  /// 条目显式声明过的字段名，用于字段级合并。
  final Set<String> fields;

  bool declares(String field) => fields.contains(field);

  /// 该职业**自身**声明的最高等级（§3.12）：取 spellcasting 各表与资源表的最大声明等级。
  /// "只有 formula 的资源"与"没有随等级变化的表"都不贡献，返回 null。
  int? get declaredMaxLevel {
    final levels = <int>[
      ...?spellcasting?.declaredMaxLevels,
      ...resources.map((r) => r.declaredMaxLevel).whereType<int>(),
    ];
    return levels.isEmpty ? null : levels.reduce((a, b) => a > b ? a : b);
  }

  /// 该职业**自身**声明的最早等级（§3.12，声明范围 `{min, max}` 的 min）：
  /// 取 spellcasting 各表与资源表的最小声明等级；无表则 null。
  int? get declaredMinLevel {
    final levels = <int>[
      ...?spellcasting?.declaredMinLevels,
      ...resources.map((r) => r.declaredMinLevel).whereType<int>(),
    ];
    return levels.isEmpty ? null : levels.reduce((a, b) => a < b ? a : b);
  }

  static ClassRuleSet parse(
    Map<String, Object?> raw, {
    required String path,
    required List<RuleDiagnostic> diagnostics,
    Set<String> abilities = kDefaultAbilities,
  }) {
    // 顺序约定：顶层未知键先报，再进入各子结构的解析（见文件头）。
    _reportUnknownFields(
      raw,
      kClassRuleFields,
      path,
      diagnostics,
      suggestion: _suggestion,
    );

    final fields = <String>{};
    final hitDie = _parseHitDie(
      raw,
      path: path,
      fields: fields,
      diagnostics: diagnostics,
    );
    final savingThrows = _parseSavingThrows(
      raw,
      path: path,
      fields: fields,
      abilities: abilities,
      diagnostics: diagnostics,
    );
    final spellcasting = _parseSpellcasting(
      raw,
      path: path,
      fields: fields,
      abilities: abilities,
      diagnostics: diagnostics,
    );
    final resources = _parseResources(
      raw,
      path: path,
      fields: fields,
      diagnostics: diagnostics,
    );

    return ClassRuleSet(
      hitDie: hitDie,
      savingThrowAbilities: savingThrows,
      spellcasting: spellcasting,
      resources: resources,
      fields: fields,
    );
  }

  /// 未知字段的最接近合法字段建议；键太短无法给出可靠建议时返回空串。
  static String _suggestion(String key) {
    final probe = key.toLowerCase();
    if (probe.length < 3) return '';
    final prefix = probe.substring(0, 3);
    for (final candidate in kClassRuleFields) {
      if (candidate.toLowerCase().startsWith(prefix)) {
        return '，是否想写 $candidate？';
      }
    }
    return '';
  }
}

int? _parseHitDie(
  Map<String, Object?> raw, {
  required String path,
  required Set<String> fields,
  required List<RuleDiagnostic> diagnostics,
}) {
  if (!raw.containsKey('hitDie')) {
    _addWarning(
      diagnostics,
      '$path.hitDie',
      'missingCoreField',
      '未声明生命骰，角色卡 HP 将按未声明处理',
    );
    return null;
  }
  fields.add('hitDie');
  final value = raw['hitDie'];
  final parsed = value is int ? value : null;
  if (parsed == null || !kStandardHitDieFaces.contains(parsed)) {
    _addError(
      diagnostics,
      '$path.hitDie',
      'invalidHitDie',
      '生命骰只写整数且必须是标准骰面 4/6/8/10/12，例如 d10 写 10',
    );
    return null;
  }
  return parsed;
}

Set<String> _parseSavingThrows(
  Map<String, Object?> raw, {
  required String path,
  required Set<String> fields,
  required Set<String> abilities,
  required List<RuleDiagnostic> diagnostics,
}) {
  final savingThrows = <String>{};
  if (!raw.containsKey('savingThrowAbilities')) return savingThrows;
  fields.add('savingThrowAbilities');
  final value = raw['savingThrowAbilities'];
  if (value is! List) {
    _addError(
      diagnostics,
      '$path.savingThrowAbilities',
      'unknownAbility',
      '必须是属性键数组',
    );
    return savingThrows;
  }
  for (final item in value) {
    final key = '$item'.trim().toLowerCase();
    if (!abilities.contains(key)) {
      _addError(
        diagnostics,
        '$path.savingThrowAbilities',
        'unknownAbility',
        '未知属性键 "$item"，可用：${abilities.join(', ')}',
      );
    } else {
      savingThrows.add(key);
    }
  }
  return savingThrows;
}

ClassSpellcasting? _parseSpellcasting(
  Map<String, Object?> raw, {
  required String path,
  required Set<String> fields,
  required Set<String> abilities,
  required List<RuleDiagnostic> diagnostics,
}) {
  if (!raw.containsKey('spellcasting')) return null;
  fields.add('spellcasting');
  final value = raw['spellcasting'];
  if (value is! Map) {
    _addError(
      diagnostics,
      '$path.spellcasting',
      'invalidSpellcastingMode',
      '必须是对象',
    );
    return null;
  }
  // 顺序约定：进入子结构前先报该层未知键。
  _reportUnknownFields(
    value,
    kSpellcastingFields,
    '$path.spellcasting',
    diagnostics,
  );

  final mode = _parseSpellcastingMode(
    value,
    path: path,
    diagnostics: diagnostics,
  );
  final ability = _parseSpellcastingAbility(
    value,
    path: path,
    mode: mode,
    abilities: abilities,
    diagnostics: diagnostics,
  );
  final listTags = _parseListTags(value, path: path, diagnostics: diagnostics);
  final tables = _parseSpellcastingTables(
    value,
    path: path,
    diagnostics: diagnostics,
  );

  return ClassSpellcasting(
    mode: mode,
    ability: ability,
    listTags: listTags,
    archetype: value['archetype'] == null ? null : '${value['archetype']}',
    slots: tables.slots,
    slotLevel: tables.slotLevel,
    prepared: tables.prepared,
    cantrips: tables.cantrips,
    maximumSpellLevel: tables.maximumSpellLevel,
  );
}

String _parseSpellcastingMode(
  Map<Object?, Object?> value, {
  required String path,
  required List<RuleDiagnostic> diagnostics,
}) {
  final mode = '${value['mode'] ?? 'none'}'.trim();
  if (!_modes.contains(mode)) {
    _addError(
      diagnostics,
      '$path.spellcasting.mode',
      'invalidSpellcastingMode',
      'spellcasting.mode 必须是 prepared / known / none',
    );
  }
  return mode;
}

/// `ability` 的两条独立判断（§3.3）：
/// 1. `ability` 只要出现，就必须 ∈ `abilities`（与 `mode` 无关，`none` 也校验）；
/// 2. `mode != none` 时 `ability` 必填。
String? _parseSpellcastingAbility(
  Map<Object?, Object?> value, {
  required String path,
  required String mode,
  required Set<String> abilities,
  required List<RuleDiagnostic> diagnostics,
}) {
  final raw = value['ability'];
  final ability = raw == null ? null : '$raw'.trim().toLowerCase();
  if (ability != null && !abilities.contains(ability)) {
    _addError(
      diagnostics,
      '$path.spellcasting.ability',
      'unknownAbility',
      '未知属性键 "$raw"，可用：${abilities.join(', ')}',
    );
  }
  if (mode != 'none' && ability == null) {
    _addError(
      diagnostics,
      '$path.spellcasting.ability',
      'unknownAbility',
      'spellcasting.mode 非 none 时必须声明 ability',
    );
  }
  return ability;
}

List<String> _parseListTags(
  Map<Object?, Object?> value, {
  required String path,
  required List<RuleDiagnostic> diagnostics,
}) {
  // 类型不符不静默吞成 []：字符串等非 List 一律报 invalidTable。
  if (!value.containsKey('listTags')) return const [];
  final raw = value['listTags'];
  if (raw is! List) {
    _addError(
      diagnostics,
      '$path.spellcasting.listTags',
      'invalidTable',
      'listTags 必须是字符串数组',
    );
    return const [];
  }
  return raw.map((item) => '$item').toList(growable: false);
}

({
  SlotTable? slots,
  IntTable? slotLevel,
  IntTable? prepared,
  IntTable? cantrips,
  IntTable? maximumSpellLevel,
})
_parseSpellcastingTables(
  Map<Object?, Object?> value, {
  required String path,
  required List<RuleDiagnostic> diagnostics,
}) {
  final slots = SlotTable.tryParse(value['slots']);
  final slotLevel = IntTable.tryParse(value['slotLevel']);
  final prepared = IntTable.tryParse(value['prepared']);
  final cantrips = IntTable.tryParse(value['cantrips']);
  final maximumSpellLevel = IntTable.tryParse(value['maximumSpellLevel']);

  void check(String key, Object? parsed) {
    if (value.containsKey(key) && parsed == null) {
      _addError(
        diagnostics,
        '$path.spellcasting.$key',
        'invalidTable',
        '$key 必须是 20 项数组或稀疏 {"等级": 值}',
      );
    }
  }

  check('slots', slots);
  check('slotLevel', slotLevel);
  check('prepared', prepared);
  check('cantrips', cantrips);
  check('maximumSpellLevel', maximumSpellLevel);
  return (
    slots: slots,
    slotLevel: slotLevel,
    prepared: prepared,
    cantrips: cantrips,
    maximumSpellLevel: maximumSpellLevel,
  );
}

List<ClassResourceRule> _parseResources(
  Map<String, Object?> raw, {
  required String path,
  required Set<String> fields,
  required List<RuleDiagnostic> diagnostics,
}) {
  final resources = <ClassResourceRule>[];
  if (!raw.containsKey('resources')) return resources;
  fields.add('resources');
  final value = raw['resources'];
  if (value is! List) {
    _addError(diagnostics, '$path.resources', 'invalidMaxSpec', '必须是数组');
    return resources;
  }
  final seen = <String>{};
  for (var index = 0; index < value.length; index++) {
    final parsed = _parseResource(
      value[index],
      itemPath: '$path.resources[$index]',
      seen: seen,
      diagnostics: diagnostics,
    );
    if (parsed != null) resources.add(parsed);
  }
  return resources;
}

ClassResourceRule? _parseResource(
  Object? raw, {
  required String itemPath,
  required Set<String> seen,
  required List<RuleDiagnostic> diagnostics,
}) {
  if (raw is! Map) {
    _addError(diagnostics, itemPath, 'invalidMaxSpec', '资源必须是对象');
    return null;
  }
  // 顺序约定：进入子结构前先报该层未知键。
  _reportUnknownFields(raw, kResourceFields, itemPath, diagnostics);

  final identity = _parseResourceIdentity(
    raw,
    itemPath: itemPath,
    seen: seen,
    diagnostics: diagnostics,
  );
  if (identity == null) return null;
  final recovery = _parseRecovery(
    raw,
    itemPath: itemPath,
    diagnostics: diagnostics,
  );
  if (recovery == null) return null;
  final maximum = MaxSpec.tryParse(raw['maximum']);
  if (maximum == null) {
    _addError(
      diagnostics,
      '$itemPath.maximum',
      'invalidMaxSpec',
      'maximum 必须且只能使用 value / formula / table 之一',
    );
    return null;
  }
  final startsAt = _parseStartsAtLevel(
    raw,
    itemPath: itemPath,
    diagnostics: diagnostics,
  );
  if (startsAt == null) return null;
  return ClassResourceRule(
    id: identity.id,
    name: identity.name,
    maximum: maximum,
    recovery: recovery.recovery,
    recoveryTable: recovery.table,
    startsAtLevel: startsAt,
    description: raw['description'] == null ? null : '${raw['description']}',
  );
}

class _ResourceIdentity {
  const _ResourceIdentity(this.id, this.name);

  final String id;
  final String name;
}

/// 校验资源对象缺一不可的 `id` / `name`，并把 [seen] 用作职业内唯一性判重。
_ResourceIdentity? _parseResourceIdentity(
  Map<Object?, Object?> raw, {
  required String itemPath,
  required Set<String> seen,
  required List<RuleDiagnostic> diagnostics,
}) {
  final id = '${raw['id'] ?? ''}'.trim();
  final name = '${raw['name'] ?? ''}'.trim();
  if (id.isEmpty || name.isEmpty) {
    _addError(diagnostics, itemPath, 'invalidMaxSpec', '资源缺少 id 或 name');
    return null;
  }
  if (!seen.add(id)) {
    _addError(
      diagnostics,
      '$itemPath.id',
      'duplicateResourceId',
      '资源 id "$id" 重复',
    );
    return null;
  }
  return _ResourceIdentity(id, name);
}

/// 解析 `recovery`：常量形态返回 `(recovery: 常量, table: null)`；
/// 表形态返回 `(recovery: null, table: 表)`（**不合成常量**，见 §3.4）。
({String? recovery, StringTable? table})? _parseRecovery(
  Map<Object?, Object?> raw, {
  required String itemPath,
  required List<RuleDiagnostic> diagnostics,
}) {
  final rawRecovery = raw['recovery'] ?? 'longRest';
  if (rawRecovery is String) {
    final recovery = rawRecovery.trim();
    if (!_recoveries.contains(recovery)) {
      _addError(
        diagnostics,
        '$itemPath.recovery',
        'invalidRecovery',
        'recovery 必须是 shortRest / shortRestOne / longRest / none',
      );
      return null;
    }
    return (recovery: recovery, table: null);
  }
  if (rawRecovery is Map && rawRecovery['table'] != null) {
    final table = StringTable.tryParse(rawRecovery['table'], _recoveries);
    if (table == null) {
      _addError(
        diagnostics,
        '$itemPath.recovery.table',
        'invalidRecovery',
        'recovery 表的值必须是 shortRest / shortRestOne / longRest / none',
      );
      return null;
    }
    return (recovery: null, table: table);
  }
  _addError(
    diagnostics,
    '$itemPath.recovery',
    'invalidRecovery',
    'recovery 只接受字符串或 {"table": …}',
  );
  return null;
}

/// `startsAtLevel` 不做静默强转：缺省为 1，但非整数（`'3'`、`2.7`、`true`、
/// 显式 `null`）或越界一律报 `invalidTable` 并精确到字段。
int? _parseStartsAtLevel(
  Map<Object?, Object?> raw, {
  required String itemPath,
  required List<RuleDiagnostic> diagnostics,
}) {
  if (!raw.containsKey('startsAtLevel')) return 1;
  final value = raw['startsAtLevel'];
  if (value is! int || value < 1 || value > 20) {
    _addError(
      diagnostics,
      '$itemPath.startsAtLevel',
      'invalidTable',
      'startsAtLevel 必须为 1..20 的整数',
    );
    return null;
  }
  return value;
}
