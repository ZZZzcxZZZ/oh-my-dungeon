import 'dart:convert';

import 'package:flutter/material.dart';

import '../../rules/domain/character_rule_definition.dart';

/// 「职业规则」的**可视化表单**（S4）：`structured.classRules` + `rules.progression`。
///
/// 它**不持有状态**：唯一事实来源仍是上层的两段 JSON 文本，所以"表单 → JSON"与
/// "JSON → 表单"双向都不会出现两份账。文本不是合法对象时表单不渲染，只提示切回
/// JSON 修正——绝不把半截输入猜成值写回去。
///
/// 覆盖范围（契约 §3.2 / §3.6 里"字段少"的那部分）：
/// - `classRules`：`hitDie`、`savingThrowAbilities`、`mode`、`spellcasting.ability`；
/// - `resources[]`：`id` / `name` / 整数 `maximum` / `recovery` / `startsAtLevel`；
/// - `rules.progression[]`：等级集合 + `grants[]`（`kind` / `target` / `value`）。
///
/// **仍写 JSON**（形状是 `Table` / `MaxSpec` / 嵌套选择，表单不伪造字段类型）：
/// `spellcasting` 的 `slots` / `prepared` / `cantrips` / `maximumSpellLevel` /
/// `archetype` / `listTags`、`resources[].maximum` 的 `formula`/`table` 形态、
/// `rules.choices` 与条目级 `rules.grants`（见 §9.2.2 / §9.2.3）。
class HomebrewClassRuleForm extends StatelessWidget {
  const HomebrewClassRuleForm({
    required this.structuredJson,
    required this.rulesJson,
    required this.onChanged,
    super.key,
  });

  /// 当前 `structured` JSON 文本（`classRules` 就在里面）。
  final String Function() structuredJson;

  /// 当前 `rules` JSON 文本（`progression` 就在里面）。
  final String Function() rulesJson;

  /// 写回新的两段 JSON。调用方负责写进 controller 并 `setState`。
  final void Function(String structuredJson, String rulesJson) onChanged;

  /// 属性键与显示名。键集合与档案 `abilities` **同源**（§3.1）。
  static const Map<String, String> abilityLabels = <String, String>{
    'str': '力量',
    'dex': '敏捷',
    'con': '体质',
    'int': '智力',
    'wis': '感知',
    'cha': '魅力',
  };

  static const List<int> hitDice = <int>[6, 8, 10, 12];

  static const Map<String, String> recoveryLabels = <String, String>{
    'shortRest': '短休',
    'shortRestOne': '短休（1 次）',
    'longRest': '长休',
    'none': '不恢复',
  };

  /// 9 个 `kind` 的中文名（契约 §3.5）。取值集合的权威仍是 [RuleGrantKind]。
  static const Map<RuleGrantKind, String> grantKindLabels =
      <RuleGrantKind, String>{
        RuleGrantKind.feature: '特性',
        RuleGrantKind.proficiency: '熟练',
        RuleGrantKind.spell: '法术',
        RuleGrantKind.equipment: '装备',
        RuleGrantKind.action: '动作',
        RuleGrantKind.speed: '速度',
        RuleGrantKind.armorClass: '护甲等级',
        RuleGrantKind.hitPoints: '生命值',
        RuleGrantKind.ability: '属性',
      };

  static const int maxLevel = 20;

  // ------------------------------------------------------------------ 解析
  static Map<String, Object?>? _decode(String text) {
    final raw = text.trim();
    Object? decoded;
    try {
      decoded = jsonDecode(raw.isEmpty ? '{}' : raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  }

  static String _encode(Map<String, Object?> value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  static Map<String, Object?> _map(Object? raw) =>
      raw is Map ? Map<String, Object?>.from(raw) : <String, Object?>{};

  static List<Map<String, Object?>> _stepsOf(Map<String, Object?> rules) {
    final raw = rules['progression'];
    if (raw is! List) return <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final step in raw)
        if (step is Map) Map<String, Object?>.from(step),
    ];
  }

  static List<int> _levelsOf(Map<String, Object?> step) {
    final raw = step['levels'];
    if (raw is! List) return const <int>[];
    return <int>[
      for (final level in raw)
        if (level is int) level,
    ];
  }

  static List<Map<String, Object?>> _grantsOf(Map<String, Object?> step) {
    final raw = step['grants'];
    if (raw is! List) return <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final grant in raw)
        if (grant is Map) Map<String, Object?>.from(grant),
    ];
  }

  // ------------------------------------------------------------------ 写回
  void _patchStructured(
    Map<String, Object?> structured,
    Map<String, Object?> classRules,
  ) {
    final next = Map<String, Object?>.from(structured);
    if (classRules.isEmpty) {
      next.remove('classRules');
    } else {
      next['classRules'] = classRules;
    }
    onChanged(_encode(next), rulesJson());
  }

  void _patchClassRules(
    Map<String, Object?> structured,
    Map<String, Object?> classRules,
    String key,
    Object? value,
  ) {
    final next = Map<String, Object?>.from(classRules);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    _patchStructured(structured, next);
  }

  void _patchSpellcasting(
    Map<String, Object?> structured,
    Map<String, Object?> classRules,
    String key,
    Object? value,
  ) {
    final spellcasting = _map(classRules['spellcasting']);
    if (value == null) {
      spellcasting.remove(key);
    } else {
      spellcasting[key] = value;
    }
    _patchClassRules(
      structured,
      classRules,
      'spellcasting',
      spellcasting.isEmpty ? null : spellcasting,
    );
  }

  void _patchResources(
    Map<String, Object?> structured,
    Map<String, Object?> classRules,
    List<Map<String, Object?>> resources,
  ) {
    _patchClassRules(
      structured,
      classRules,
      'resources',
      resources.isEmpty ? null : resources,
    );
  }

  void _patchRules(
    Map<String, Object?> rules,
    List<Map<String, Object?>> steps,
  ) {
    final next = Map<String, Object?>.from(rules);
    if (steps.isEmpty) {
      next.remove('progression');
    } else {
      next['progression'] = steps;
    }
    onChanged(structuredJson(), _encode(next));
  }

  // ------------------------------------------------------------------ 构建
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final structured = _decode(structuredJson());
    final rules = _decode(rulesJson());
    if (structured == null || rules == null) {
      return Text(
        'JSON 当前不是合法对象：切到「JSON」修正后再用表单编辑。',
        key: const Key('homebrew-form-invalid-json'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    final classRules = _map(structured['classRules']);
    final steps = _stepsOf(rules);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(theme, '职业规则（structured.classRules）'),
        ..._classRuleFields(context, structured, classRules),
        const Divider(height: 28),
        _sectionTitle(theme, '等级步骤（rules.progression）'),
        if (steps.isEmpty)
          Text('还没有等级步骤：未声明即不猜，角色不会得到任何职业授予。',
              style: theme.textTheme.bodySmall),
        for (var index = 0; index < steps.length; index++)
          _stepCard(context, rules, steps, index),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const Key('homebrew-form-add-step'),
          onPressed: () => _addStep(rules, steps),
          icon: const Icon(Icons.add),
          label: const Text('添加等级步骤'),
        ),
        const SizedBox(height: 8),
        Text(
          '法术位 / 上限表（Table / MaxSpec）与 rules.choices 仍写 JSON：'
          '它们的形状不是扁平字段，表单不伪造字段类型。',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: theme.textTheme.titleSmall),
  );

  List<Widget> _classRuleFields(
    BuildContext context,
    Map<String, Object?> structured,
    Map<String, Object?> classRules,
  ) {
    final theme = Theme.of(context);
    final hitDie = classRules['hitDie'];
    final saves = _stringList(classRules['savingThrowAbilities']);
    final spellcasting = _map(classRules['spellcasting']);
    final resources = <Map<String, Object?>>[
      for (final resource in (classRules['resources'] as List? ?? const []))
        if (resource is Map) Map<String, Object?>.from(resource),
    ];
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _JsonDropdown(
              fieldKey: const Key('homebrew-form-hit-die'),
              value: hitDie is int ? '$hitDie' : '',
              label: '生命骰',
              items: <String, String>{
                '': '未声明',
                for (final die in hitDice) '$die': 'd$die',
              },
              onChanged: (value) => _patchClassRules(
                structured,
                classRules,
                'hitDie',
                value.isEmpty ? null : int.tryParse(value),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _JsonDropdown(
              fieldKey: const Key('homebrew-form-merge-mode'),
              value: '${classRules['mode'] ?? ''}',
              label: '合并模式（mode）',
              items: const <String, String>{
                '': '未声明（patch）',
                'patch': 'patch 逐列合并',
                'replace': 'replace 独占',
              },
              onChanged: (value) => _patchClassRules(
                structured,
                classRules,
                'mode',
                value.isEmpty ? null : value,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text('豁免熟练（恰好两个属性）', style: theme.textTheme.bodySmall),
      Wrap(
        spacing: 6,
        children: [
          for (final entry in abilityLabels.entries)
            FilterChip(
              key: Key('homebrew-form-save-${entry.key}'),
              label: Text(entry.value),
              selected: saves.contains(entry.key),
              onSelected: (selected) {
                final next = [...saves];
                if (selected) {
                  next.add(entry.key);
                } else {
                  next.remove(entry.key);
                }
                _patchClassRules(
                  structured,
                  classRules,
                  'savingThrowAbilities',
                  next,
                );
              },
            ),
        ],
      ),
      if (saves.isNotEmpty && saves.length != 2)
        Text(
          '当前声明了 ${saves.length} 项：2024 职业恰好两项，导入期会拦下。',
          key: const Key('homebrew-form-save-warning'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      const SizedBox(height: 12),
      _JsonDropdown(
        fieldKey: const Key('homebrew-form-spell-ability'),
        value: '${spellcasting['ability'] ?? ''}',
        label: '施法属性（spellcasting.ability）',
        items: <String, String>{
          '': '未声明 / 非施法者',
          ...abilityLabels,
        },
        onChanged: (value) => _patchSpellcasting(
          structured,
          classRules,
          'ability',
          value.isEmpty ? null : value,
        ),
      ),
      const SizedBox(height: 12),
      Text('职业资源（resources）', style: theme.textTheme.bodySmall),
      for (var index = 0; index < resources.length; index++)
        _resourceRow(context, structured, classRules, resources, index),
      TextButton.icon(
        key: const Key('homebrew-form-add-resource'),
        onPressed: () => _patchResources(structured, classRules, [
          ...resources,
          <String, Object?>{'id': _freeResourceId(resources), 'name': ''},
        ]),
        icon: const Icon(Icons.add),
        label: const Text('添加资源'),
      ),
    ];
  }

  static List<String> _stringList(Object? raw) => raw is List
      ? <String>[
          for (final item in raw)
            if (item is String) item,
        ]
      : const <String>[];

  static String _freeResourceId(List<Map<String, Object?>> resources) {
    final used = <String>{
      for (final resource in resources) '${resource['id'] ?? ''}',
    };
    var index = resources.length + 1;
    while (used.contains('resource-$index')) {
      index++;
    }
    return 'resource-$index';
  }

  Widget _resourceRow(
    BuildContext context,
    Map<String, Object?> structured,
    Map<String, Object?> classRules,
    List<Map<String, Object?>> resources,
    int index,
  ) {
    final theme = Theme.of(context);
    final resource = resources[index];
    final maximum = resource['maximum'];
    final recovery = resource['recovery'];
    void patch(String key, Object? value) {
      final next = <Map<String, Object?>>[...resources];
      final item = Map<String, Object?>.from(next[index]);
      if (value == null) {
        item.remove(key);
      } else {
        item[key] = value;
      }
      next[index] = item;
      _patchResources(structured, classRules, next);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _JsonTextField(
                    fieldKey: Key('homebrew-form-resource-$index-id'),
                    value: '${resource['id'] ?? ''}',
                    label: 'id',
                    onChanged: (value) =>
                        patch('id', value.trim().isEmpty ? null : value.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _JsonTextField(
                    fieldKey: Key('homebrew-form-resource-$index-name'),
                    value: '${resource['name'] ?? ''}',
                    label: '名称',
                    onChanged: (value) => patch(
                      'name',
                      value.trim().isEmpty ? null : value.trim(),
                    ),
                  ),
                ),
                IconButton(
                  key: Key('homebrew-form-resource-$index-remove'),
                  tooltip: '删除资源',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final next = <Map<String, Object?>>[...resources]
                      ..removeAt(index);
                    _patchResources(structured, classRules, next);
                  },
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _JsonTextField(
                    fieldKey: Key('homebrew-form-resource-$index-maximum'),
                    value: maximum is int ? '$maximum' : '',
                    label: '上限（整数）',
                    helperText: maximum is Map
                        ? '当前是 formula/table 形态：留空保留，输入整数会替换它'
                        : null,
                    onChanged: (value) {
                      final text = value.trim();
                      if (text.isEmpty) {
                        patch('maximum', null);
                      } else {
                        final parsed = int.tryParse(text);
                        if (parsed != null) patch('maximum', parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _JsonDropdown(
                    fieldKey: Key('homebrew-form-resource-$index-recovery'),
                    value: recovery is String &&
                            recoveryLabels.containsKey(recovery)
                        ? recovery
                        : 'longRest',
                    label: '恢复',
                    items: recoveryLabels,
                    onChanged: (value) => patch('recovery', value),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: _JsonTextField(
                    fieldKey: Key('homebrew-form-resource-$index-starts-at'),
                    value: '${resource['startsAtLevel'] ?? ''}',
                    label: '起始等级',
                    onChanged: (value) {
                      final text = value.trim();
                      if (text.isEmpty) {
                        patch('startsAtLevel', null);
                      } else {
                        final parsed = int.tryParse(text);
                        if (parsed != null) patch('startsAtLevel', parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (maximum is Map)
              Text(
                'maximum: ${jsonEncode(maximum)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  void _addStep(Map<String, Object?> rules, List<Map<String, Object?>> steps) {
    final used = <int>{for (final step in steps) ..._levelsOf(step)};
    var level = 1;
    while (used.contains(level) && level < maxLevel) {
      level++;
    }
    _patchRules(rules, [
      ...steps,
      <String, Object?>{'levels': <int>[level]},
    ]);
  }

  Widget _stepCard(
    BuildContext context,
    Map<String, Object?> rules,
    List<Map<String, Object?>> steps,
    int index,
  ) {
    final theme = Theme.of(context);
    final step = steps[index];
    final levels = _levelsOf(step);
    final grants = _grantsOf(step);
    void patchStep(String key, Object? value) {
      final next = <Map<String, Object?>>[...steps];
      final item = Map<String, Object?>.from(next[index]);
      if (value == null) {
        item.remove(key);
      } else {
        item[key] = value;
      }
      next[index] = item;
      _patchRules(rules, next);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    levels.isEmpty
                        ? '未选等级'
                        : '等级 ${(levels.toList()..sort()).join('、')}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: Key('homebrew-form-step-$index-remove'),
                  tooltip: '删除该步骤',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final next = <Map<String, Object?>>[...steps]
                      ..removeAt(index);
                    _patchRules(rules, next);
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var level = 1; level <= maxLevel; level++)
                  FilterChip(
                    key: Key('homebrew-form-step-$index-level-$level'),
                    label: Text('$level'),
                    selected: levels.contains(level),
                    onSelected: (selected) {
                      final next = [...levels];
                      if (selected) {
                        next.add(level);
                      } else {
                        next.remove(level);
                      }
                      next.sort();
                      patchStep('levels', next);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('授予（grants）', style: theme.textTheme.bodySmall),
            for (var grant = 0; grant < grants.length; grant++)
              _grantRow(context, patchStep, grants, grant),
            TextButton.icon(
              key: Key('homebrew-form-step-$index-add-grant'),
              onPressed: () {
                final used = <String>{
                  for (final item in grants) '${item['id'] ?? ''}',
                };
                var id = 'grant-${grants.length + 1}';
                while (used.contains(id)) {
                  id = 'grant-${grants.length + 1}-${used.length}';
                }
                patchStep('grants', [
                  ...grants,
                  <String, Object?>{'id': id, 'kind': 'proficiency'},
                ]);
              },
              icon: const Icon(Icons.add),
              label: const Text('添加授予'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grantRow(
    BuildContext context,
    void Function(String key, Object? value) patchStep,
    List<Map<String, Object?>> grants,
    int index,
  ) {
    final grant = grants[index];
    final kindName = '${grant['kind'] ?? 'feature'}';
    final kind = RuleGrantKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => RuleGrantKind.feature,
    );
    void patchGrant(String key, Object? value) {
      final next = <Map<String, Object?>>[...grants];
      final item = Map<String, Object?>.from(next[index]);
      if (value == null) {
        item.remove(key);
      } else {
        item[key] = value;
      }
      next[index] = item;
      patchStep('grants', next);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: _JsonDropdown(
              fieldKey: Key('homebrew-form-grant-$index-kind'),
              value: kind.name,
              label: 'kind',
              items: <String, String>{
                for (final entry in grantKindLabels.entries)
                  entry.key.name: entry.value,
              },
              onChanged: (value) => patchGrant('kind', value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _JsonTextField(
              fieldKey: Key('homebrew-form-grant-$index-target'),
              value: '${grant['target'] ?? ''}',
              label: 'target（如 skill:运动 / save:dex）',
              onChanged: (text) => patchGrant(
                'target',
                text.trim().isEmpty ? null : text.trim(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: _JsonTextField(
              fieldKey: Key('homebrew-form-grant-$index-value'),
              value: grant['value'] == null ? '' : '${grant['value']}',
              label: 'value',
              onChanged: (text) {
                if (text.trim().isEmpty) {
                  patchGrant('value', null);
                } else {
                  final parsed = int.tryParse(text.trim());
                  if (parsed != null) patchGrant('value', parsed);
                }
              },
            ),
          ),
          IconButton(
            key: Key('homebrew-form-grant-$index-remove'),
            tooltip: '删除授予',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              final next = <Map<String, Object?>>[...grants]..removeAt(index);
              patchStep('grants', next);
            },
          ),
        ],
      ),
    );
  }
}

/// 表单里的下拉框：**完全受控**（`value` 直接决定显示项），因此 JSON 标签页里改完
/// 切回表单立刻反映，不存在 `initialValue` 那种"只认第一次"的残留。
class _JsonDropdown extends StatelessWidget {
  const _JsonDropdown({
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final Key fieldKey;
  final String value;
  final String label;

  /// 取值 → 显示名。第一项是"未声明"时的兜底。
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: fieldKey,
        isExpanded: true,
        value: items.containsKey(value) ? value : items.keys.first,
        items: [
          for (final entry in items.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (selected) => onChanged(selected ?? ''),
      ),
    ),
  );
}

/// 表单里的文本字段：`value` 是**唯一事实来源**（上层 JSON 解出来的字符串）。
///
/// 打字时不变（父级重建给回的 `value` 与 controller 文本相同），外部改动
/// （JSON 标签页、删除中间一行导致的行位移）会把 controller 同步过来——既不会
/// 每次按键重置光标，也不会残留上一行的值。
class _JsonTextField extends StatefulWidget {
  const _JsonTextField({
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.onChanged,
    this.helperText,
  });

  final Key fieldKey;
  final String value;
  final String label;
  final String? helperText;
  final ValueChanged<String> onChanged;

  @override
  State<_JsonTextField> createState() => _JsonTextFieldState();
}

class _JsonTextFieldState extends State<_JsonTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_JsonTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: _controller,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helperText,
    ),
    onChanged: widget.onChanged,
  );
}
