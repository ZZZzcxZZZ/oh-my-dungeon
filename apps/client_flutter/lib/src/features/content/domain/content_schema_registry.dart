import '../../characters/domain/class_rule_summary.dart';
import 'content_entry.dart';

enum ContentFieldValueKind { text, integer, decimal, boolean, stringList }

class ContentFieldSchema {
  const ContentFieldSchema({
    required this.key,
    required this.label,
    this.kind = ContentFieldValueKind.text,
    this.requiredForCreation = false,
    this.filterable = false,
    this.aliases = const <String>[],
    this.valueLabels = const <String, String>{},
    this.minimum,
    this.maximum,
  });

  final String key;
  final String label;
  final ContentFieldValueKind kind;
  final bool requiredForCreation;
  final bool filterable;
  final List<String> aliases;
  final Map<String, String> valueLabels;
  final num? minimum;
  final num? maximum;
}

class ContentTypeSchema {
  const ContentTypeSchema({
    required this.type,
    required this.label,
    required this.fields,
    this.visibleInLibrary = true,
    this.creatable = true,
  });

  final String type;
  final String label;
  final List<ContentFieldSchema> fields;
  final bool visibleInLibrary;
  final bool creatable;

  List<ContentFieldSchema> get facetFields =>
      fields.where((field) => field.filterable).toList(growable: false);
}

class ContentSchemaValidationResult {
  const ContentSchemaValidationResult({
    required this.normalizedType,
    required this.normalizedStructured,
    required this.errors,
  });

  final String normalizedType;
  final Map<String, Object?> normalizedStructured;
  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class ContentSchemaRegistry {
  const ContentSchemaRegistry._(this.schemas);

  static const defaults = ContentSchemaRegistry._(_schemas);

  final List<ContentTypeSchema> schemas;

  Iterable<ContentTypeSchema> get librarySchemas =>
      schemas.where((schema) => schema.visibleInLibrary);

  Iterable<ContentTypeSchema> get creatableSchemas =>
      schemas.where((schema) => schema.creatable);

  ContentTypeSchema schemaFor(String type) {
    final normalized = normalizeType(type);
    return schemas.firstWhere((schema) => schema.type == normalized);
  }

  String normalizeType(String type) {
    final value = type.trim();
    if (value == 'equipment') return 'item';
    if (schemas.any((schema) => schema.type == value)) return value;
    return 'custom';
  }

  bool isCreatableType(String type) {
    final value = type.trim();
    return schemas.any((schema) => schema.type == value && schema.creatable);
  }

  Map<String, Object?> normalizeStructured(
    String type,
    Map<String, Object?> structured,
  ) {
    final schema = schemaFor(type);
    final fieldByKey = <String, ContentFieldSchema>{};
    for (final field in schema.fields) {
      fieldByKey[field.key] = field;
      for (final alias in field.aliases) {
        fieldByKey[alias] = field;
      }
    }

    final result = <String, Object?>{};
    for (final entry in structured.entries) {
      final field = fieldByKey[entry.key];
      if (field == null) {
        result[entry.key] = entry.value;
        continue;
      }
      final normalized = _normalizeValue(field, entry.value);
      if (normalized != null) result[field.key] = normalized;
    }
    return result;
  }

  /// facet 值归一化。facet **计数**与**筛选**共用这一个函数，因此任何派生
  /// 规则只能写在这里。
  ///
  /// 职业生命骰是**唯一**的派生字段（新契约只在
  /// `structured.classRules.hitDie` 声明生命骰）：无论 `value` 是否存在，都经
  /// [ClassRuleSummary] 从规则值派生 `d<N>`。顶层 `structured.hitDie`（旧散文
  /// `'d10'`、整数 `10`、空串 `''`）**一律不读**——否则会出现"筛得出来、
  /// 卡片上没有"（展示层按契约不读这一行）。
  ///
  /// 其余字段照旧：`value == null` 视为"未声明"（空集），非 null 走 schema 归一化。
  Set<String> normalizeFacetValues(
    String type,
    String field,
    Object? value, {
    required ContentEntry entry,
  }) {
    if (type == 'class' && field == 'hitDie') {
      // 唯一派生点：未声明（`hitDie == null`）→ 空集，**绝不回退** raw。
      final hitDie = ClassRuleSummary.of(entry).hitDie;
      return hitDie == null ? const {} : <String>{hitDie};
    }
    if (value == null) return const {};
    final schema = schemaFor(type);
    final definition = schema.fields
        .where((candidate) => candidate.key == field)
        .firstOrNull;
    if (definition == null) {
      final values = value is Iterable ? value : <Object?>[value];
      return values.map((item) => '$item').toSet();
    }
    if (definition.key == 'type' && definition.valueLabels.isNotEmpty) {
      return _normalizeMonsterTypes(value, definition.valueLabels).toSet();
    }
    final normalized = _normalizeValue(definition, value);
    if (normalized is Iterable) {
      return normalized.map((item) => '$item').toSet();
    }
    return <String>{if (normalized != null) '$normalized'};
  }

  ContentSchemaValidationResult validateForCreation({
    required String type,
    required String name,
    required Map<String, Object?> structured,
  }) {
    final errors = <String>[];
    if (!isCreatableType(type)) errors.add('不支持的资料类型');
    if (name.trim().isEmpty) errors.add('名称不能为空');
    final normalizedType = normalizeType(type);
    final normalized = normalizeStructured(normalizedType, structured);
    final schema = schemaFor(normalizedType);
    for (final field in schema.fields.where(
      (field) => field.requiredForCreation,
    )) {
      final value = normalized[field.key];
      if (value == null || value == '' || value is List && value.isEmpty) {
        errors.add('${field.label}不能为空');
      }
    }
    for (final field in schema.fields) {
      final value = normalized[field.key];
      if (value == null || value == '') continue;
      final hasValidType = switch (field.kind) {
        ContentFieldValueKind.text => value is String,
        ContentFieldValueKind.integer => value is int,
        ContentFieldValueKind.decimal => value is num,
        ContentFieldValueKind.boolean => value is bool,
        ContentFieldValueKind.stringList => value is List<String>,
      };
      if (!hasValidType) {
        errors.add('${field.label}格式不正确');
        continue;
      }
      if (value is num &&
          ((field.minimum != null && value < field.minimum!) ||
              (field.maximum != null && value > field.maximum!))) {
        errors.add('${field.label}必须在 ${field.minimum} 到 ${field.maximum} 之间');
      }
      if (field.valueLabels.isNotEmpty) {
        final values = value is Iterable ? value : <Object?>[value];
        if (values.any((item) => !field.valueLabels.containsKey('$item'))) {
          errors.add('${field.label}不是有效选项');
        }
      }
    }
    return ContentSchemaValidationResult(
      normalizedType: normalizedType,
      normalizedStructured: normalized,
      errors: errors,
    );
  }

  Object? _normalizeValue(ContentFieldSchema field, Object? value) {
    if (value == null) return null;
    if (field.key == 'type' && field.valueLabels.isNotEmpty) {
      final types = _normalizeMonsterTypes(value, field.valueLabels);
      if (types.isEmpty) return value;
      return types.length == 1 ? types.single : types;
    }
    return switch (field.kind) {
      ContentFieldValueKind.text => '$value'.trim(),
      ContentFieldValueKind.integer =>
        value is num ? value.toInt() : int.tryParse('$value'.trim()) ?? value,
      ContentFieldValueKind.decimal =>
        value is num
            ? value.toDouble()
            : double.tryParse('$value'.trim()) ?? value,
      ContentFieldValueKind.boolean =>
        value is bool ? value : _normalizeBoolean(value),
      ContentFieldValueKind.stringList => _stringList(value),
    };
  }

  Object _normalizeBoolean(Object value) {
    final text = '$value'.trim().toLowerCase();
    if (const {'true', '1', '是', 'yes'}.contains(text)) return true;
    if (const {'false', '0', '否', 'no'}.contains(text)) return false;
    return value;
  }

  List<String> _stringList(Object value) {
    final source = value is Iterable ? value : <Object?>[value];
    return source
        .expand((item) => '$item'.split(RegExp(r'[,，、;；]')))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _normalizeMonsterTypes(
    Object value,
    Map<String, String> labels,
  ) {
    final source = value is Iterable ? value : <Object?>[value];
    final result = <String>{};
    for (final item in source) {
      final text = '$item'.trim();
      final lower = text.toLowerCase();
      for (final entry in labels.entries) {
        if (lower == entry.key || text.contains(entry.value)) {
          result.add(entry.key);
        }
      }
    }
    return result.toList(growable: false);
  }
}

const _monsterTypeLabels = <String, String>{
  'aberration': '异怪',
  'beast': '野兽',
  'celestial': '天族',
  'construct': '构装',
  'dragon': '龙类',
  'elemental': '元素',
  'fey': '妖精',
  'fiend': '邪魔',
  'giant': '巨人',
  'humanoid': '类人',
  'monstrosity': '怪兽',
  'ooze': '泥怪',
  'plant': '植物',
  'undead': '亡灵',
};

const _schemas = <ContentTypeSchema>[
  ContentTypeSchema(
    type: 'spell',
    label: '法术',
    fields: [
      ContentFieldSchema(
        key: 'level',
        label: '环位',
        kind: ContentFieldValueKind.integer,
        requiredForCreation: true,
        filterable: true,
        minimum: 0,
        maximum: 9,
        valueLabels: {
          '0': '戏法',
          '1': '1环',
          '2': '2环',
          '3': '3环',
          '4': '4环',
          '5': '5环',
          '6': '6环',
          '7': '7环',
          '8': '8环',
          '9': '9环',
        },
      ),
      ContentFieldSchema(key: 'school', label: '学派', filterable: true),
      ContentFieldSchema(
        key: 'classes',
        label: '可用职业',
        kind: ContentFieldValueKind.stringList,
        filterable: true,
      ),
      ContentFieldSchema(key: 'castingTime', label: '施法时间'),
      ContentFieldSchema(key: 'range', label: '距离'),
      ContentFieldSchema(
        key: 'components',
        label: '成分',
        kind: ContentFieldValueKind.stringList,
      ),
      ContentFieldSchema(key: 'duration', label: '持续时间'),
    ],
  ),
  ContentTypeSchema(
    type: 'item',
    label: '物品与装备',
    fields: [
      ContentFieldSchema(key: 'category', label: '类别', filterable: true),
      ContentFieldSchema(key: 'rarity', label: '稀有度', filterable: true),
      ContentFieldSchema(key: 'cost', label: '价格'),
      ContentFieldSchema(key: 'weight', label: '重量'),
      ContentFieldSchema(key: 'damage', label: '伤害'),
      ContentFieldSchema(key: 'armorClass', label: 'AC'),
      ContentFieldSchema(
        key: 'attunement',
        label: '同调',
        kind: ContentFieldValueKind.boolean,
      ),
    ],
  ),
  ContentTypeSchema(
    type: 'species',
    label: '种族',
    fields: [
      ContentFieldSchema(key: 'size', label: '体型', filterable: true),
      ContentFieldSchema(key: 'speed', label: '速度', filterable: true),
      ContentFieldSchema(key: 'creatureType', label: '生物类型'),
    ],
  ),
  ContentTypeSchema(
    type: 'class',
    label: '职业',
    // 这四项是**显示字段**，也是本类型字段列表的**唯一来源**
    // （`content_type_registry.dart` 里那份手工副本已删）。
    //
    // `primaryAbility` 读 `structured`；后三项是 §3.9 契约的职业规则值，
    // **`structured` 的同名散文键一律不读**：值只由 [ClassRuleSummary] 从
    // `structured.classRules` 派生（展示层经 `_metadataRows` 调用它）。
    // 登记它们只为让"职业卡片显示哪些行"与字段列表同源；旧散文
    // `structured.savingThrows` / `structured.skills` 只会在
    // `normalizeStructured` 里被归一化保存，**没有任何展示或筛选读取**。
    //
    // 只有 `primaryAbility` 是 `filterable`：职业的 facet **不经过**
    // `schema.fields`，资料库显式请求 `['hitDie']`，由 [normalizeFacetValues]
    // 走规则口径（不回退 `structured`）。`hitDie` 标 false 是刻意的：
    // 它是展示行 + 派生 facet，不是可以直接读 `structured` 的字段。
    fields: [
      ContentFieldSchema(key: 'primaryAbility', label: '主属性', filterable: true),
      ContentFieldSchema(key: 'hitDie', label: '生命骰'),
      ContentFieldSchema(key: 'savingThrows', label: '豁免熟练'),
      ContentFieldSchema(key: 'skills', label: '技能选择'),
    ],
  ),
  ContentTypeSchema(
    type: 'subclass',
    label: '子职',
    fields: [
      ContentFieldSchema(key: 'parentClass', label: '所属职业', filterable: true),
      ContentFieldSchema(
        key: 'level',
        label: '等级',
        kind: ContentFieldValueKind.integer,
      ),
    ],
  ),
  ContentTypeSchema(
    type: 'classFeature',
    label: '职业特性',
    fields: [
      ContentFieldSchema(key: 'class', label: '职业', filterable: true),
      ContentFieldSchema(
        key: 'level',
        label: '等级',
        kind: ContentFieldValueKind.integer,
        filterable: true,
      ),
    ],
  ),
  ContentTypeSchema(
    type: 'background',
    label: '背景',
    fields: [
      ContentFieldSchema(
        key: 'skills',
        label: '技能熟练',
        kind: ContentFieldValueKind.stringList,
        filterable: true,
        aliases: ['skillProficiencies'],
      ),
      ContentFieldSchema(key: 'feature', label: '特性'),
    ],
  ),
  ContentTypeSchema(
    type: 'feat',
    label: '专长',
    fields: [
      ContentFieldSchema(key: 'category', label: '类别', filterable: true),
      ContentFieldSchema(key: 'prerequisite', label: '先决条件', filterable: true),
    ],
  ),
  ContentTypeSchema(
    type: 'monster',
    label: '怪物',
    fields: [
      ContentFieldSchema(key: 'challengeRating', label: 'CR', filterable: true),
      ContentFieldSchema(
        key: 'type',
        label: '类型',
        requiredForCreation: true,
        filterable: true,
        valueLabels: _monsterTypeLabels,
      ),
      ContentFieldSchema(key: 'size', label: '体型'),
      ContentFieldSchema(key: 'alignment', label: '阵营'),
    ],
  ),
  ContentTypeSchema(
    type: 'condition',
    label: '状态',
    fields: [
      ContentFieldSchema(key: 'duration', label: '持续', filterable: true),
    ],
  ),
  ContentTypeSchema(type: 'custom', label: '自定义', fields: []),
  ContentTypeSchema(
    type: 'equipmentBundle',
    label: '装备方案',
    fields: [],
    visibleInLibrary: false,
    creatable: false,
  ),
  ContentTypeSchema(
    type: 'rule',
    label: '规则',
    fields: [],
    visibleInLibrary: false,
    creatable: false,
  ),
];
