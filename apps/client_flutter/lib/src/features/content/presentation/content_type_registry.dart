import 'package:flutter/material.dart';

import '../../characters/domain/class_rule_summary.dart';
import '../domain/content_entry.dart';
import '../domain/content_schema_registry.dart';
import '../domain/content_type_definition.dart';

class ContentTypeRegistry {
  const ContentTypeRegistry._(this._definitions);

  factory ContentTypeRegistry.defaults() =>
      const ContentTypeRegistry._(_defaults);

  static const Map<String, ContentTypeDefinition> _defaults = {
    'class': _ClassDefinition(),
    'subclass': _SubclassDefinition(),
    'classFeature': _ClassFeatureDefinition(),
    'species': _SpeciesDefinition(),
    'background': _BackgroundDefinition(),
    'feat': _FeatDefinition(),
    'spell': _SpellDefinition(),
    'equipment': _EquipmentDefinition(),
    'equipmentBundle': _EquipmentBundleDefinition(),
    'item': _ItemDefinition(),
    'condition': _ConditionDefinition(),
    'rule': _RuleDefinition(),
    'monster': _MonsterDefinition(),
    'custom': _CustomDefinition(),
  };

  final Map<String, ContentTypeDefinition> _definitions;

  ContentTypeDefinition definitionFor(String type) {
    final base = _definitions[type] ?? _definitions['custom']!;
    final schema = ContentSchemaRegistry.defaults.schemaFor(type);
    return _SchemaBackedDefinition(base: base, schema: schema);
  }
}

class _SchemaBackedDefinition implements ContentTypeDefinition {
  const _SchemaBackedDefinition({required this.base, required this.schema});

  final ContentTypeDefinition base;
  final ContentTypeSchema schema;

  @override
  String get type => schema.type;

  @override
  String get label => schema.label;

  @override
  IconData get icon => base.icon;

  @override
  List<ContentFieldDefinition> get searchableFields => schema.fields
      .map(
        (field) => ContentFieldDefinition(key: field.key, label: field.label),
      )
      .toList(growable: false);

  @override
  Widget buildSummary(BuildContext context, ContentEntry entry) =>
      base.buildSummary(context, entry);

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) =>
      _metadataRows(context, entry, searchableFields);
}

// --- Base ---

sealed class _BaseDefinition implements ContentTypeDefinition {
  const _BaseDefinition();

  @override
  Widget buildSummary(BuildContext context, ContentEntry entry) {
    return Text(entry.summary.isEmpty ? entry.name : entry.summary);
  }

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return const SizedBox.shrink();
  }
}

Widget _metadataRows(
  BuildContext context,
  ContentEntry entry,
  List<ContentFieldDefinition> fields,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final structured = ContentSchemaRegistry.defaults.normalizeStructured(
    entry.type,
    entry.structured,
  );
  // 职业规则字段（生命骰 / 豁免熟练 / 技能选择）的值一律经 [ClassRuleSummary]
  // 这唯一口径；其余字段继续读 `structured`。
  final classRules = entry.type == 'class' ? ClassRuleSummary.of(entry) : null;
  final rows = <Widget>[];
  for (final field in fields) {
    final value = _metadataValue(structured, classRules, field.key);
    if (value == null) continue;
    rows.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                field.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
  if (rows.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
}

/// 元数据行的展示值。
///
/// 职业的规则字段（`hitDie` / `savingThrows` / `skills`）一律取
/// [ClassRuleSummary]（条目声明 ∪ 内置档案，唯一口径）：未声明即 `null`
/// ——**不回退**旧散文键、不显示 `0`。其余字段照旧读 `structured`。
String? _metadataValue(
  Map<String, Object?> structured,
  ({String? hitDie, String? savingThrows, String? skillChoice})? classRules,
  String key,
) {
  if (classRules != null) {
    switch (key) {
      case 'hitDie':
        return classRules.hitDie;
      case 'savingThrows':
        return classRules.savingThrows;
      case 'skills':
        return classRules.skillChoice;
    }
  }
  return _formatValue(structured[key]);
}

String? _formatValue(Object? value) {
  if (value == null) return null;
  if (value is List) {
    final items = value.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    if (items.isEmpty) return null;
    return items.join(', ');
  }
  if (value is bool) return value ? '是' : '否';
  final text = '$value';
  return text.isEmpty ? null : text;
}

// --- Definitions ---

class _ClassDefinition extends _BaseDefinition {
  const _ClassDefinition();

  @override
  String get type => 'class';

  @override
  String get label => '职业';

  @override
  IconData get icon => Icons.school_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'primaryAbility', label: '主属性'),
    ContentFieldDefinition(key: 'hitDie', label: '生命骰'),
    ContentFieldDefinition(key: 'savingThrows', label: '豁免熟练'),
    ContentFieldDefinition(key: 'skills', label: '技能选择'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _SubclassDefinition extends _BaseDefinition {
  const _SubclassDefinition();

  @override
  String get type => 'subclass';

  @override
  String get label => '子职';

  @override
  IconData get icon => Icons.school_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'parentClass', label: '父职业'),
    ContentFieldDefinition(key: 'level', label: '等级'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _ClassFeatureDefinition extends _BaseDefinition {
  const _ClassFeatureDefinition();

  @override
  String get type => 'classFeature';

  @override
  String get label => '职业特性';

  @override
  IconData get icon => Icons.auto_awesome_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'class', label: '职业'),
    ContentFieldDefinition(key: 'level', label: '等级'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _SpeciesDefinition extends _BaseDefinition {
  const _SpeciesDefinition();

  @override
  String get type => 'species';

  @override
  String get label => '种族';

  @override
  IconData get icon => Icons.face_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'size', label: '体型'),
    ContentFieldDefinition(key: 'speed', label: '速度'),
    ContentFieldDefinition(key: 'creatureType', label: '生物类型'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _BackgroundDefinition extends _BaseDefinition {
  const _BackgroundDefinition();

  @override
  String get type => 'background';

  @override
  String get label => '背景';

  @override
  IconData get icon => Icons.history_edu_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'skills', label: '技能'),
    ContentFieldDefinition(key: 'feature', label: '特性'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _FeatDefinition extends _BaseDefinition {
  const _FeatDefinition();

  @override
  String get type => 'feat';

  @override
  String get label => '专长';

  @override
  IconData get icon => Icons.star_outline;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'category', label: '类别'),
    ContentFieldDefinition(key: 'prerequisite', label: '先决'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _SpellDefinition extends _BaseDefinition {
  const _SpellDefinition();

  @override
  String get type => 'spell';

  @override
  String get label => '法术';

  @override
  IconData get icon => Icons.auto_fix_high_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'level', label: '环阶'),
    ContentFieldDefinition(key: 'school', label: '学派'),
    ContentFieldDefinition(key: 'castingTime', label: '施法时间'),
    ContentFieldDefinition(key: 'range', label: '距离'),
    ContentFieldDefinition(key: 'components', label: '成分'),
    ContentFieldDefinition(key: 'duration', label: '持续时间'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _EquipmentDefinition extends _BaseDefinition {
  const _EquipmentDefinition();

  @override
  String get type => 'equipment';

  @override
  String get label => '装备';

  @override
  IconData get icon => Icons.shield_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'category', label: '类别'),
    ContentFieldDefinition(key: 'cost', label: '价格'),
    ContentFieldDefinition(key: 'weight', label: '重量'),
    ContentFieldDefinition(key: 'damage', label: '伤害'),
    ContentFieldDefinition(key: 'armorClass', label: 'AC'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _ItemDefinition extends _BaseDefinition {
  const _ItemDefinition();

  @override
  String get type => 'item';

  @override
  String get label => '物品与装备';

  @override
  IconData get icon => Icons.inventory_2_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'category', label: '类别'),
    ContentFieldDefinition(key: 'cost', label: '价格'),
    ContentFieldDefinition(key: 'weight', label: '重量'),
    ContentFieldDefinition(key: 'damage', label: '伤害'),
    ContentFieldDefinition(key: 'armorClass', label: 'AC'),
    ContentFieldDefinition(key: 'rarity', label: '稀有度'),
    ContentFieldDefinition(key: 'attunement', label: '同调'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _EquipmentBundleDefinition extends _BaseDefinition {
  const _EquipmentBundleDefinition();

  @override
  String get type => 'equipmentBundle';

  @override
  String get label => '装备方案';

  @override
  IconData get icon => Icons.inventory_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'source', label: '来源'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _ConditionDefinition extends _BaseDefinition {
  const _ConditionDefinition();

  @override
  String get type => 'condition';

  @override
  String get label => '状态';

  @override
  IconData get icon => Icons.healing_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'duration', label: '持续时间'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _RuleDefinition extends _BaseDefinition {
  const _RuleDefinition();

  @override
  String get type => 'rule';

  @override
  String get label => '规则';

  @override
  IconData get icon => Icons.menu_book_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [];
}

class _MonsterDefinition extends _BaseDefinition {
  const _MonsterDefinition();

  @override
  String get type => 'monster';

  @override
  String get label => '怪物';

  @override
  IconData get icon => Icons.pets_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [
    ContentFieldDefinition(key: 'challengeRating', label: 'CR'),
    ContentFieldDefinition(key: 'type', label: '类型'),
    ContentFieldDefinition(key: 'alignment', label: '阵营'),
  ];

  @override
  Widget buildMetadata(BuildContext context, ContentEntry entry) {
    return _metadataRows(context, entry, searchableFields);
  }
}

class _CustomDefinition extends _BaseDefinition {
  const _CustomDefinition();

  @override
  String get type => 'custom';

  @override
  String get label => '自定义';

  @override
  IconData get icon => Icons.category_outlined;

  @override
  List<ContentFieldDefinition> get searchableFields => const [];
}
