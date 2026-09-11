import 'rule_diagnostic.dart';
import 'rule_values.dart';

const kDefaultAbilities = {'str', 'dex', 'con', 'int', 'wis', 'cha'};
const kDefaultSkills = {
  '杂技',
  '驯兽',
  '奥秘',
  '运动',
  '欺瞒',
  '历史',
  '洞悉',
  '威吓',
  '调查',
  '医药',
  '自然',
  '察觉',
  '表演',
  '说服',
  '宗教',
  '巧手',
  '隐匿',
  '求生',
};

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
  final String recovery;

  /// 随等级变化的恢复语义（如诗人激励 1 级长休、5 级短休）。
  final StringTable? recoveryTable;

  final int startsAtLevel;

  String recoveryAt(int level) => recoveryTable?.at(level) ?? recovery;

  /// 资源表声明到的最高等级；只有 formula 的资源不贡献等级。
  int? get declaredMaxLevel => maximum.table?.maxLevel;
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

  static const _knownFields = {
    'hitDie',
    'savingThrowAbilities',
    'spellcasting',
    'resources',
  };
  static const _spellcastingFields = {
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
  static const _resourceFields = {
    'id',
    'name',
    'maximum',
    'recovery',
    'startsAtLevel',
    'description',
  };
  static const _modes = {'prepared', 'known', 'pact', 'none'};
  static const _recoveries = {'shortRest', 'shortRestOne', 'longRest', 'none'};

  /// 标准骰面（生命骰只可能是这五种；d7/d9/d20 一律拒绝）
  static const _hitDieFaces = {4, 6, 8, 10, 12};

  static ClassRuleSet parse(
    Map<String, Object?> raw, {
    required String path,
    required List<RuleDiagnostic> diagnostics,
    Set<String> abilities = kDefaultAbilities,
  }) {
    void error(String code, String field, String message) => diagnostics.add(
      RuleDiagnostic(
        path: '$path.$field',
        severity: RuleSeverity.error,
        code: code,
        message: message,
      ),
    );
    void warn(String code, String field, String message) => diagnostics.add(
      RuleDiagnostic(
        path: '$path.$field',
        severity: RuleSeverity.warning,
        code: code,
        message: message,
      ),
    );

    final fields = <String>{};
    int? hitDie;
    if (raw.containsKey('hitDie')) {
      fields.add('hitDie');
      final value = raw['hitDie'];
      final parsed = value is int ? value : null;
      if (parsed == null || !_hitDieFaces.contains(parsed)) {
        error(
          'invalidHitDie',
          'hitDie',
          '生命骰只写整数且必须是标准骰面 4/6/8/10/12，例如 d10 写 10',
        );
      } else {
        hitDie = parsed;
      }
    } else {
      warn('missingCoreField', 'hitDie', '未声明生命骰，角色卡 HP 将按未声明处理');
    }

    final savingThrows = <String>{};
    if (raw.containsKey('savingThrowAbilities')) {
      fields.add('savingThrowAbilities');
      final value = raw['savingThrowAbilities'];
      if (value is! List) {
        error('unknownAbility', 'savingThrowAbilities', '必须是属性键数组');
      } else {
        for (final item in value) {
          final key = '$item'.trim().toLowerCase();
          if (!abilities.contains(key)) {
            error(
              'unknownAbility',
              'savingThrowAbilities',
              '未知属性键 "$item"，可用：${abilities.join(', ')}',
            );
          } else {
            savingThrows.add(key);
          }
        }
      }
    }

    ClassSpellcasting? spellcasting;
    if (raw.containsKey('spellcasting')) {
      fields.add('spellcasting');
      final value = raw['spellcasting'];
      if (value is! Map) {
        error('invalidSpellcastingMode', 'spellcasting', '必须是对象');
      } else {
        for (final key in value.keys) {
          if (_spellcastingFields.contains('$key')) continue;
          error('unknownField', 'spellcasting.$key', '未知字段 $key');
        }
        final mode = '${value['mode'] ?? 'none'}'.trim();
        if (!_modes.contains(mode)) {
          error(
            'invalidSpellcastingMode',
            'spellcasting.mode',
            'spellcasting.mode 必须是 prepared / known / pact / none',
          );
        }
        final abilityRaw = value['ability'];
        final ability = abilityRaw == null
            ? null
            : '$abilityRaw'.trim().toLowerCase();
        if (mode != 'none' &&
            (ability == null || !abilities.contains(ability))) {
          error('unknownAbility', 'spellcasting.ability', '施法属性非法或缺失');
        }
        final listTags = value['listTags'] is List
            ? (value['listTags']! as List)
                  .map((item) => '$item')
                  .toList(growable: false)
            : const <String>[];
        final archetype = value['archetype'] == null
            ? null
            : '${value['archetype']}';

        SlotTable? slots;
        IntTable? slotLevel, prepared, cantrips, maximumSpellLevel;
        final tables = {
          'slots': () => slots = SlotTable.tryParse(value['slots']),
          'slotLevel': () => slotLevel = IntTable.tryParse(value['slotLevel']),
          'prepared': () => prepared = IntTable.tryParse(value['prepared']),
          'cantrips': () => cantrips = IntTable.tryParse(value['cantrips']),
          'maximumSpellLevel': () =>
              maximumSpellLevel = IntTable.tryParse(value['maximumSpellLevel']),
        };
        for (final entry in tables.entries) {
          if (!value.containsKey(entry.key)) continue;
          entry.value();
          final parsed = switch (entry.key) {
            'slots' => slots,
            'slotLevel' => slotLevel,
            'prepared' => prepared,
            'cantrips' => cantrips,
            _ => maximumSpellLevel,
          };
          if (parsed == null) {
            error(
              'invalidTable',
              'spellcasting.${entry.key}',
              '${entry.key} 必须是 20 项数组或稀疏 {"等级": 值}',
            );
          }
        }
        spellcasting = ClassSpellcasting(
          mode: mode,
          ability: ability,
          listTags: listTags,
          archetype: archetype,
          slots: slots,
          slotLevel: slotLevel,
          prepared: prepared,
          cantrips: cantrips,
          maximumSpellLevel: maximumSpellLevel,
        );
      }
    }

    final resources = <ClassResourceRule>[];
    if (raw.containsKey('resources')) {
      fields.add('resources');
      final value = raw['resources'];
      if (value is! List) {
        error('invalidMaxSpec', 'resources', '必须是数组');
      } else {
        final seen = <String>{};
        for (var index = 0; index < value.length; index++) {
          final item = value[index];
          final itemPath = '$path.resources[$index]';
          if (item is! Map) {
            diagnostics.add(
              RuleDiagnostic(
                path: itemPath,
                severity: RuleSeverity.error,
                code: 'invalidMaxSpec',
                message: '资源必须是对象',
              ),
            );
            continue;
          }
          for (final key in item.keys) {
            if (_resourceFields.contains('$key')) continue;
            diagnostics.add(
              RuleDiagnostic(
                path: '$itemPath.$key',
                severity: RuleSeverity.error,
                code: 'unknownField',
                message: '未知字段 $key',
              ),
            );
          }
          final id = '${item['id'] ?? ''}'.trim();
          final name = '${item['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            diagnostics.add(
              RuleDiagnostic(
                path: itemPath,
                severity: RuleSeverity.error,
                code: 'invalidMaxSpec',
                message: '资源缺少 id 或 name',
              ),
            );
            continue;
          }
          if (!seen.add(id)) {
            diagnostics.add(
              RuleDiagnostic(
                path: '$itemPath.id',
                severity: RuleSeverity.error,
                code: 'duplicateResourceId',
                message: '资源 id "$id" 重复',
              ),
            );
            continue;
          }
          final recoveryRaw = item['recovery'] ?? 'longRest';
          var recovery = 'longRest';
          StringTable? recoveryTable;
          if (recoveryRaw is String) {
            recovery = recoveryRaw.trim();
            if (!_recoveries.contains(recovery)) {
              diagnostics.add(
                RuleDiagnostic(
                  path: '$itemPath.recovery',
                  severity: RuleSeverity.error,
                  code: 'invalidRecovery',
                  message:
                      'recovery 必须是 shortRest / shortRestOne / longRest / none',
                ),
              );
              continue;
            }
          } else if (recoveryRaw is Map && recoveryRaw['table'] != null) {
            recoveryTable = StringTable.tryParse(
              recoveryRaw['table'],
              _recoveries,
            );
            if (recoveryTable == null) {
              diagnostics.add(
                RuleDiagnostic(
                  path: '$itemPath.recovery.table',
                  severity: RuleSeverity.error,
                  code: 'invalidRecovery',
                  message:
                      'recovery 表的值必须是 shortRest / shortRestOne / longRest / none',
                ),
              );
              continue;
            }
            recovery = recoveryTable.at(recoveryTable.minLevel) ?? 'longRest';
          } else {
            diagnostics.add(
              RuleDiagnostic(
                path: '$itemPath.recovery',
                severity: RuleSeverity.error,
                code: 'invalidRecovery',
                message: 'recovery 只接受字符串或 {"table": …}',
              ),
            );
            continue;
          }
          final maximum = MaxSpec.tryParse(item['maximum']);
          if (maximum == null) {
            diagnostics.add(
              RuleDiagnostic(
                path: '$itemPath.maximum',
                severity: RuleSeverity.error,
                code: 'invalidMaxSpec',
                message: 'maximum 必须且只能使用 value / formula / table 之一',
              ),
            );
            continue;
          }
          final startsAt = item['startsAtLevel'] is num
              ? (item['startsAtLevel']! as num).toInt()
              : 1;
          if (startsAt < 1 || startsAt > 20) {
            diagnostics.add(
              RuleDiagnostic(
                path: '$itemPath.startsAtLevel',
                severity: RuleSeverity.error,
                code: 'invalidTable',
                message: 'startsAtLevel 必须为 1..20',
              ),
            );
            continue;
          }
          resources.add(
            ClassResourceRule(
              id: id,
              name: name,
              maximum: maximum,
              recovery: recovery,
              recoveryTable: recoveryTable,
              startsAtLevel: startsAt,
              description: item['description'] == null
                  ? null
                  : '${item['description']}',
            ),
          );
        }
      }
    }

    for (final key in raw.keys) {
      if (_knownFields.contains(key)) continue;
      diagnostics.add(
        RuleDiagnostic(
          path: '$path.$key',
          severity: RuleSeverity.error,
          code: 'unknownField',
          message: '未知字段 $key${_suggestion(key)}',
        ),
      );
    }

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
    const candidates = [
      'hitDie',
      'savingThrowAbilities',
      'spellcasting',
      'resources',
    ];
    final probe = key.toLowerCase();
    if (probe.length < 3) return '';
    final prefix = probe.substring(0, 3);
    for (final candidate in candidates) {
      if (candidate.toLowerCase().startsWith(prefix)) {
        return '，是否想写 $candidate？';
      }
    }
    return '';
  }
}
