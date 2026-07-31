import 'package:dnd_table_client/src/features/content/presentation/content_type_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers every v1 content type', () {
    final registry = ContentTypeRegistry.defaults();
    for (final type in const [
      'class',
      'subclass',
      'classFeature',
      'species',
      'background',
      'feat',
      'spell',
      'equipment',
      'equipmentBundle',
      'item',
      'condition',
      'rule',
      'monster',
      'custom',
    ]) {
      expect(registry.definitionFor(type).type, type);
    }
  });

  test('falls back to custom definition for unknown type', () {
    final registry = ContentTypeRegistry.defaults();
    expect(registry.definitionFor('unknown-xyz').type, 'custom');
  });

  test('exposes a chinese label for every registered type', () {
    final registry = ContentTypeRegistry.defaults();
    expect(registry.definitionFor('class').label, '职业');
    expect(registry.definitionFor('subclass').label, '子职');
    expect(registry.definitionFor('classFeature').label, '职业特性');
    expect(registry.definitionFor('species').label, '种族');
    expect(registry.definitionFor('background').label, '背景');
    expect(registry.definitionFor('feat').label, '专长');
    expect(registry.definitionFor('spell').label, '法术');
    expect(registry.definitionFor('equipment').label, '装备');
    expect(registry.definitionFor('equipmentBundle').label, '装备方案');
    expect(registry.definitionFor('item').label, '物品与装备');
    expect(registry.definitionFor('condition').label, '状态');
    expect(registry.definitionFor('rule').label, '规则');
    expect(registry.definitionFor('monster').label, '怪物');
    expect(registry.definitionFor('custom').label, '自定义');
  });
}
