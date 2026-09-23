import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../rules/domain/character_rule_definition.dart';

/// Edits the existing choices JSON in place; no parallel form model is kept.
/// Unknown fields and advanced option data survive edits to visible fields.
class HomebrewChoiceForm extends StatelessWidget {
  const HomebrewChoiceForm({
    required this.scope,
    required this.readRaw,
    required this.onChanged,
    super.key,
  });

  final String scope;
  final Object? Function() readRaw;
  final ValueChanged<List<Map<String, Object?>>> onChanged;

  static List<Map<String, Object?>>? _maps(Object? raw) {
    if (raw == null) return <Map<String, Object?>>[];
    if (raw is! List || raw.any((item) => item is! Map)) return null;
    return [for (final item in raw) Map<String, Object?>.from(item as Map)];
  }

  @override
  Widget build(BuildContext context) {
    final choices = _maps(readRaw());
    if (choices == null) {
      return const Text('选择数据形状不正确，请切到 JSON 修正。');
    }
    void patch(int index, String field, Object? value) {
      final current = _maps(readRaw());
      if (current == null || index >= current.length) return;
      final next = [...current];
      final item = Map<String, Object?>.from(next[index]);
      if (value == null) {
        item.remove(field);
      } else {
        item[field] = value;
      }
      next[index] = item;
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < choices.length; index++)
          _choice(context, choices, index, patch),
        OutlinedButton.icon(
          key: Key('homebrew-choice-$scope-add'),
          onPressed: () {
            final current = _maps(readRaw());
            if (current == null) return;
            final ids = {for (final choice in current) '${choice['id']}'};
            var number = current.length + 1;
            while (ids.contains('choice-$number')) {
              number++;
            }
            onChanged([
              ...current,
              {'id': 'choice-$number', 'label': '新选择', 'optionType': 'value'},
            ]);
          },
          icon: const Icon(Icons.add),
          label: const Text('添加选择'),
        ),
      ],
    );
  }

  Widget _choice(
    BuildContext context,
    List<Map<String, Object?>> choices,
    int index,
    void Function(int, String, Object?) patch,
  ) {
    final choice = choices[index];
    final prefix = 'homebrew-choice-$scope-$index';
    final options = choice['options'];
    final optionsValid =
        options == null ||
        (options is List &&
            options.every((item) => item is String || item is Map));
    final requires = _maps(choice['requires']);
    final textTheme = Theme.of(context).textTheme;
    Map<String, Object?>? currentChoice() {
      final current = _maps(readRaw());
      return current != null && index < current.length ? current[index] : null;
    }

    List<Object?>? currentOptions() {
      final value = currentChoice()?['options'];
      return value is List ? List<Object?>.from(value) : null;
    }

    return ExpansionTile(
      key: Key('$prefix-tile'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text(
        '${choice['label'] ?? choice['id'] ?? '选择'}',
        style: textTheme.titleSmall,
      ),
      trailing: IconButton(
        key: Key('$prefix-remove'),
        tooltip: '删除选择',
        icon: const Icon(Icons.delete_outline),
        onPressed: () {
          final current = _maps(readRaw());
          if (current == null || index >= current.length) return;
          onChanged([...current]..removeAt(index));
        },
      ),
      children: [
        _ChoiceTextField(
          fieldKey: Key('$prefix-id'),
          label: '选择 ID',
          value: '${choice['id'] ?? ''}',
          onChanged: (value) => patch(index, 'id', value.trim()),
        ),
        _ChoiceTextField(
          fieldKey: Key('$prefix-label'),
          label: '标题',
          value: '${choice['label'] ?? ''}',
          onChanged: (value) => patch(index, 'label', value),
        ),
        _ChoiceTextField(
          fieldKey: Key('$prefix-type'),
          label: '选项类型（如 subclass / spell / skill）',
          value: '${choice['optionType'] ?? ''}',
          onChanged: (value) => patch(index, 'optionType', value.trim()),
        ),
        Row(
          children: [
            Expanded(
              child: _numberField(
                '$prefix-minimum',
                '最少',
                choice['minimum'],
                (value) => patch(index, 'minimum', value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberField(
                '$prefix-maximum',
                '最多',
                choice['maximum'],
                (value) => patch(index, 'maximum', value),
              ),
            ),
          ],
        ),
        _ChoiceTextField(
          fieldKey: Key('$prefix-group'),
          label: '分组（可选）',
          value: '${choice['group'] ?? ''}',
          onChanged: (value) =>
              patch(index, 'group', value.isEmpty ? null : value),
        ),
        _ChoiceTextField(
          fieldKey: Key('$prefix-help'),
          label: '帮助说明（可选）',
          value: '${choice['help'] ?? ''}',
          onChanged: (value) =>
              patch(index, 'help', value.isEmpty ? null : value),
        ),
        _ChoiceDropdown(
          fieldKey: Key('$prefix-builder-step'),
          label: '创建向导步骤',
          value: '${choice['builderStep'] ?? ''}',
          values: ['', ...RuleChoiceDefinition.allowedBuilderSteps],
          onChanged: (value) =>
              patch(index, 'builderStep', value.isEmpty ? null : value),
        ),
        _ChoiceDropdown(
          fieldKey: Key('$prefix-counts-toward'),
          label: '计入数量池',
          value: '${choice['countsToward'] ?? ''}',
          values: ['', ...kCountsTowardPools],
          onChanged: (value) =>
              patch(index, 'countsToward', value.isEmpty ? null : value),
        ),
        SwitchListTile(
          key: Key('$prefix-repeatable'),
          contentPadding: EdgeInsets.zero,
          title: const Text('可重复选择'),
          value: choice['repeatable'] == true,
          onChanged: (value) => patch(index, 'repeatable', value ? true : null),
        ),
        _ChoiceDropdown(
          fieldKey: Key('$prefix-max-level'),
          label: '最高法术环位',
          value: '${choice['maximumOptionLevel'] ?? ''}',
          values: const ['', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
          onChanged: (value) => patch(
            index,
            'maximumOptionLevel',
            value.isEmpty ? null : int.parse(value),
          ),
        ),
        _stringList(
          '$prefix-entry-ids',
          '限定条目 ID',
          choice['optionEntryIds'],
          (value) => patch(index, 'optionEntryIds', value),
        ),
        _stringList(
          '$prefix-tags',
          '标签过滤',
          choice['optionTags'],
          (value) => patch(index, 'optionTags', value),
        ),
        _stringList(
          '$prefix-recommended',
          '推荐条目 ID',
          choice['recommendedEntryIds'],
          (value) => patch(index, 'recommendedEntryIds', value),
        ),
        const SizedBox(height: 8),
        Text('内联选项', style: textTheme.titleSmall),
        if (!optionsValid)
          const Text('选项形状不正确，请切到 JSON 修正。')
        else ...[
          for (
            var optionIndex = 0;
            optionIndex < (choice['options'] as List? ?? []).length;
            optionIndex++
          )
            _option(
              context,
              prefix,
              choice['options'] as List,
              optionIndex,
              currentOptions,
              (next) => patch(index, 'options', next.isEmpty ? null : next),
            ),
          TextButton.icon(
            key: Key('$prefix-add-option'),
            onPressed: () =>
                patch(index, 'options', [...?currentOptions(), '新选项']),
            icon: const Icon(Icons.add),
            label: const Text('添加内联选项'),
          ),
        ],
        const SizedBox(height: 8),
        Text('前置条件', style: textTheme.titleSmall),
        _requirements(
          prefix,
          requires,
          () => _maps(currentChoice()?['requires']),
          (next) => patch(index, 'requires', next.isEmpty ? null : next),
        ),
        const Divider(),
      ],
    );
  }

  Widget _option(
    BuildContext context,
    String prefix,
    List rawOptions,
    int optionIndex,
    List<Object?>? Function() readOptions,
    ValueChanged<List<Object?>> onOptionsChanged,
  ) {
    final raw = rawOptions[optionIndex];
    final optionPrefix = '$prefix-option-$optionIndex';
    void replace(Object? value) {
      final current = readOptions();
      if (current == null || optionIndex >= current.length) return;
      final next = <Object?>[...current];
      if (value == null) {
        next.removeAt(optionIndex);
      } else {
        next[optionIndex] = value;
      }
      onOptionsChanged(next);
    }

    if (raw is String) {
      return Row(
        children: [
          Expanded(
            child: _ChoiceTextField(
              fieldKey: Key('$optionPrefix-id'),
              label: '选项',
              value: raw,
              onChanged: replace,
            ),
          ),
          IconButton(
            key: Key('$optionPrefix-details'),
            tooltip: '编辑选项详情',
            icon: const Icon(Icons.tune),
            onPressed: () => replace({'id': raw, 'label': raw}),
          ),
          IconButton(
            key: Key('$optionPrefix-remove'),
            tooltip: '删除选项',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => replace(null),
          ),
        ],
      );
    }
    if (raw is! Map) return const Text('选项形状不正确，请切到 JSON 修正。');
    final option = Map<String, Object?>.from(raw);
    Map<String, Object?>? currentOption() {
      final current = readOptions();
      if (current == null ||
          optionIndex >= current.length ||
          current[optionIndex] is! Map) {
        return null;
      }
      return Map<String, Object?>.from(current[optionIndex] as Map);
    }

    void patchOption(String key, Object? value) {
      final next = currentOption();
      if (next == null) return;
      if (value == null) {
        next.remove(key);
      } else {
        next[key] = value;
      }
      replace(next);
    }

    return ExpansionTile(
      key: Key('$optionPrefix-tile'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text('${option['label'] ?? option['id'] ?? '选项'}'),
      trailing: IconButton(
        key: Key('$optionPrefix-remove'),
        tooltip: '删除选项',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => replace(null),
      ),
      children: [
        _ChoiceTextField(
          fieldKey: Key('$optionPrefix-id'),
          label: '选项 ID',
          value: '${option['id'] ?? ''}',
          onChanged: (value) => patchOption('id', value.trim()),
        ),
        _ChoiceTextField(
          fieldKey: Key('$optionPrefix-label'),
          label: '显示名称',
          value: '${option['label'] ?? ''}',
          onChanged: (value) => patchOption('label', value),
        ),
        _ChoiceTextField(
          fieldKey: Key('$optionPrefix-description'),
          label: '描述（可选）',
          value: '${option['description'] ?? ''}',
          onChanged: (value) =>
              patchOption('description', value.isEmpty ? null : value),
        ),
        Text('选项前置', style: Theme.of(context).textTheme.titleSmall),
        _requirements(
          optionPrefix,
          _maps(option['requires']),
          () => _maps(currentOption()?['requires']),
          (next) => patchOption('requires', next.isEmpty ? null : next),
        ),
        Text('选中后授予', style: Theme.of(context).textTheme.titleSmall),
        _grants(
          optionPrefix,
          _maps(option['grants']),
          () => _maps(currentOption()?['grants']),
          (next) => patchOption('grants', next.isEmpty ? null : next),
        ),
        if (option.containsKey('data'))
          Text(
            '自定义 data 保留原值；高级编辑请切到 JSON。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _requirements(
    String prefix,
    List<Map<String, Object?>>? items,
    List<Map<String, Object?>>? Function() readItems,
    ValueChanged<List<Map<String, Object?>>> onChanged,
  ) {
    if (items == null) return const Text('前置条件形状不正确，请切到 JSON 修正。');
    void patch(int index, Map<String, Object?> value) {
      final current = readItems();
      if (current == null || index >= current.length) return;
      final next = [...current]..[index] = value;
      onChanged(next);
    }

    void patchField(int index, String field, Object? value) {
      final current = readItems();
      if (current == null || index >= current.length) return;
      final next = Map<String, Object?>.from(current[index]);
      if (value == null) {
        next.remove(field);
      } else {
        next[field] = value;
      }
      patch(index, next);
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          () {
            final item = items[i];
            final key = '$prefix-requires-$i';
            final byChoice = item.containsKey('choice');
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceDropdown(
                        fieldKey: Key('$key-kind'),
                        label: '条件类型',
                        value: byChoice ? 'choice' : 'ability',
                        values: const ['ability', 'choice'],
                        onChanged: (value) => patch(
                          i,
                          value == 'choice'
                              ? {'choice': 'choice-id'}
                              : {'ability': 'str', 'minimum': 13},
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('$key-remove'),
                      tooltip: '删除条件',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final current = readItems();
                        if (current == null || i >= current.length) return;
                        onChanged([...current]..removeAt(i));
                      },
                    ),
                  ],
                ),
                if (byChoice) ...[
                  _ChoiceTextField(
                    fieldKey: Key('$key-choice'),
                    label: '依赖的选择 ID',
                    value: '${item['choice'] ?? ''}',
                    onChanged: (value) => patchField(i, 'choice', value.trim()),
                  ),
                  _ChoiceTextField(
                    fieldKey: Key('$key-option'),
                    label: '依赖的选项 ID（可选）',
                    value: '${item['option'] ?? ''}',
                    onChanged: (value) => patchField(
                      i,
                      'option',
                      value.trim().isEmpty ? null : value.trim(),
                    ),
                  ),
                ] else ...[
                  _ChoiceTextField(
                    fieldKey: Key('$key-ability'),
                    label: '属性（str/dex/con/int/wis/cha）',
                    value: '${item['ability'] ?? ''}',
                    onChanged: (value) =>
                        patchField(i, 'ability', value.trim()),
                  ),
                  _numberField('$key-minimum', '最低属性值', item['minimum'], (
                    value,
                  ) {
                    patchField(i, 'minimum', value);
                  }),
                ],
              ],
            );
          }(),
        TextButton.icon(
          key: Key('$prefix-add-requires'),
          onPressed: () {
            final current = readItems();
            if (current == null) return;
            onChanged([
              ...current,
              {'ability': 'str', 'minimum': 13},
            ]);
          },
          icon: const Icon(Icons.add),
          label: const Text('添加前置条件'),
        ),
      ],
    );
  }

  Widget _grants(
    String prefix,
    List<Map<String, Object?>>? items,
    List<Map<String, Object?>>? Function() readItems,
    ValueChanged<List<Map<String, Object?>>> onChanged,
  ) {
    if (items == null) return const Text('授予形状不正确，请切到 JSON 修正。');
    void patch(int index, String field, Object? value) {
      final current = readItems();
      if (current == null || index >= current.length) return;
      final next = [...current];
      final item = Map<String, Object?>.from(next[index]);
      if (value == null) {
        item.remove(field);
      } else {
        item[field] = value;
      }
      next[index] = item;
      onChanged(next);
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: _ChoiceTextField(
                  fieldKey: Key('$prefix-grant-$i-id'),
                  label: '授予 ID',
                  value: '${items[i]['id'] ?? ''}',
                  onChanged: (value) => patch(i, 'id', value.trim()),
                ),
              ),
              IconButton(
                key: Key('$prefix-grant-$i-remove'),
                tooltip: '删除授予',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  final current = readItems();
                  if (current == null || i >= current.length) return;
                  onChanged([...current]..removeAt(i));
                },
              ),
            ],
          ),
          _ChoiceDropdown(
            fieldKey: Key('$prefix-grant-$i-kind'),
            label: '授予类型',
            value: '${items[i]['kind'] ?? 'feature'}',
            values: [for (final kind in RuleGrantKind.values) kind.name],
            onChanged: (value) => patch(i, 'kind', value),
          ),
          for (final field in ['label', 'target', 'entryId', 'formula'])
            _ChoiceTextField(
              fieldKey: Key('$prefix-grant-$i-$field'),
              label: field,
              value: '${items[i][field] ?? ''}',
              onChanged: (value) =>
                  patch(i, field, value.isEmpty ? null : value),
            ),
          _ChoiceTextField(
            fieldKey: Key('$prefix-grant-$i-value'),
            label: 'value（可选）',
            value: '${items[i]['value'] ?? ''}',
            onChanged: (value) {
              if (value.isEmpty) {
                patch(i, 'value', null);
              } else {
                final parsed = num.tryParse(value);
                if (parsed != null) patch(i, 'value', parsed);
              }
            },
          ),
        ],
        TextButton.icon(
          key: Key('$prefix-add-grant'),
          onPressed: () {
            final current = readItems();
            if (current == null) return;
            onChanged([
              ...current,
              {'id': 'grant-${current.length + 1}', 'kind': 'feature'},
            ]);
          },
          icon: const Icon(Icons.add),
          label: const Text('添加授予'),
        ),
      ],
    );
  }

  Widget _numberField(
    String key,
    String label,
    Object? value,
    ValueChanged<int?> onChanged,
  ) => _ChoiceTextField(
    fieldKey: Key(key),
    label: label,
    value: value == null ? '' : '$value',
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    keyboardType: TextInputType.number,
    onChanged: (text) => onChanged(text.isEmpty ? null : int.tryParse(text)),
  );

  Widget _stringList(
    String key,
    String label,
    Object? raw,
    ValueChanged<List<String>?> onChanged,
  ) {
    if (raw != null && (raw is! List || raw.any((item) => item is! String))) {
      return Text('$label 的数据形状不正确，请切到 JSON 修正。');
    }
    final values = raw == null ? <String>[] : List<String>.from(raw as List);
    void write(List<String> next) => onChanged(next.isEmpty ? null : next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        for (var i = 0; i < values.length; i++)
          Row(
            children: [
              Expanded(
                child: _ChoiceTextField(
                  fieldKey: Key('$key-$i'),
                  label: label,
                  value: values[i],
                  onChanged: (text) {
                    final next = [...values]..[i] = text.trim();
                    write(next);
                  },
                ),
              ),
              IconButton(
                key: Key('$key-$i-remove'),
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => write([...values]..removeAt(i)),
              ),
            ],
          ),
        TextButton.icon(
          key: Key('$key-add'),
          onPressed: () => write([...values, '']),
          icon: const Icon(Icons.add),
          label: Text('添加$label'),
        ),
      ],
    );
  }
}

class _ChoiceDropdown extends StatelessWidget {
  const _ChoiceDropdown({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final Key fieldKey;
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final unknown = !values.contains(value);
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: fieldKey,
          isExpanded: true,
          value: value,
          items: [
            for (final item in values)
              DropdownMenuItem(
                value: item,
                child: Text(item.isEmpty ? '未设置' : item),
              ),
            if (unknown)
              DropdownMenuItem(
                value: value,
                child: Text('未知值：$value'),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _ChoiceTextField extends StatefulWidget {
  const _ChoiceTextField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
  });
  final Key fieldKey;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_ChoiceTextField> createState() => _ChoiceTextFieldState();
}

class _ChoiceTextFieldState extends State<_ChoiceTextField> {
  late final TextEditingController controller = TextEditingController(
    text: widget.value,
  );
  @override
  void didUpdateWidget(_ChoiceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != controller.text) controller.text = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: controller,
    keyboardType: widget.keyboardType,
    inputFormatters: widget.inputFormatters,
    decoration: InputDecoration(labelText: widget.label),
    onChanged: widget.onChanged,
  );
}
