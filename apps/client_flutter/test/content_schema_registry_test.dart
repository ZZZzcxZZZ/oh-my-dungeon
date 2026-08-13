import 'package:dnd_table_client/src/features/content/domain/content_schema_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const registry = ContentSchemaRegistry.defaults;

  test('exposes the fixed library categories in product order', () {
    expect(registry.librarySchemas.map((schema) => schema.type), [
      'spell',
      'item',
      'species',
      'class',
      'subclass',
      'classFeature',
      'background',
      'feat',
      'monster',
      'condition',
      'custom',
    ]);
  });

  test(
    'normalizes compatibility types and rejects arbitrary creation types',
    () {
      expect(registry.normalizeType('equipment'), 'item');
      expect(registry.normalizeType('thirdPartyMystery'), 'custom');
      expect(registry.isCreatableType('thirdPartyMystery'), isFalse);
      expect(registry.isCreatableType('subclass'), isTrue);
    },
  );

  test('normalizes aliases and structured field value types', () {
    final spell = registry.normalizeStructured('spell', {
      'level': '3',
      'classes': '法师、术士',
    });
    final background = registry.normalizeStructured('background', {
      'skillProficiencies': '隐匿, 察觉',
    });

    expect(spell['level'], 3);
    expect(spell['classes'], ['法师', '术士']);
    expect(background['skills'], ['隐匿', '察觉']);
    expect(background.containsKey('skillProficiencies'), isFalse);
  });

  test('normalizes legacy monster subtypes into official broad types', () {
    expect(
      registry.normalizeStructured('monster', {'type': '亡灵（法师）'})['type'],
      'undead',
    );
    expect(
      registry.normalizeStructured('monster', {'type': '天族或邪魔（泰坦）'})['type'],
      ['celestial', 'fiend'],
    );
  });

  test('validates required creation fields without rejecting extensions', () {
    final invalid = registry.validateForCreation(
      type: 'spell',
      name: '',
      structured: const {'school': '塑能'},
    );
    final valid = registry.validateForCreation(
      type: 'spell',
      name: '火球术（自制）',
      structured: const {'level': 3, 'school': '塑能', 'homebrewDamage': '10d6'},
    );

    expect(invalid.errors, contains('名称不能为空'));
    expect(invalid.errors, contains('环位不能为空'));
    expect(valid.isValid, isTrue);
    expect(valid.normalizedStructured['homebrewDamage'], '10d6');
  });

  test('rejects invalid field types ranges and enum values', () {
    final spell = registry.validateForCreation(
      type: 'spell',
      name: '坏法术',
      structured: const {'level': 12},
    );
    final monster = registry.validateForCreation(
      type: 'monster',
      name: '坏怪物',
      structured: const {'type': '时空生物'},
    );

    expect(spell.errors, contains('环位必须在 0 到 9 之间'));
    expect(monster.errors, contains('类型不是有效选项'));
  });
}
