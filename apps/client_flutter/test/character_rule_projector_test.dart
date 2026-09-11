import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_projector.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects newly available feature rules without changing runtime state',
    () {
      final character =
          CharacterSheet.local(
            id: 'legacy-character',
            name: '旧角色',
            level: 2,
            classSummary: '战士',
          ).copyWith(
            currentHp: 7,
            maxHp: 20,
            inventory: [
              {'name': '长剑', 'quantity': 1},
            ],
            data: {
              'build': {
                'level': 1,
                'selections': {'class': 'test:class/fighter'},
                'choices': <String, List<String>>{},
              },
              'runtime': {
                'temporaryHp': 4,
                'conditions': ['倒地'],
              },
            },
          );
      final fighter = _entry(
        id: 'test:class/fighter',
        type: 'class',
        name: '战士',
        rules: {
          'progression': [
            {
              'level': 2,
              'grants': [
                {
                  'id': 'action-surge',
                  'kind': 'feature',
                  'label': '动作如潮',
                  'entryId': 'test:class-feature/action-surge',
                },
              ],
            },
          ],
        },
      );
      final feature = _entry(
        id: 'test:class-feature/action-surge',
        type: 'classFeature',
        name: '动作如潮',
      );

      final projected = CharacterRuleProjector(
        entries: {fighter.id: fighter, feature.id: feature},
      ).project(character);

      expect(projected.currentHp, 7);
      expect(projected.maxHp, 20);
      expect(projected.inventoryList.single, {'name': '长剑', 'quantity': 1});
      expect(projected.runtimeMap, {
        'temporaryHp': 4,
        'conditions': ['倒地'],
      });
      expect((projected.dataMap['build'] as Map)['level'], 2);
      expect(
        projected.dataMap['resolvedGrants'],
        contains(containsPair('label', '动作如潮')),
      );
      expect((projected.dataMap['contentRefs'] as Map)['features'], [
        'test:class-feature/action-surge',
      ]);
      expect(
        (projected.dataMap['ruleSnapshots'] as Map)[feature.id],
        containsPair('name', '动作如潮'),
      );
    },
  );

  test('回填职业身份：展示名精确匹配档案 slug（老角色没有 build 也能回填）', () {
    final legacy = CharacterSheet.local(
      id: 'legacy-bard',
      name: '旧吟游诗人',
      level: 1,
      classSummary: '吟游诗人',
    );

    final projected = const CharacterRuleProjector(
      entries: <String, ContentEntry>{},
    ).project(legacy);

    expect(projected.dataMap['classIdentity'], {
      'entryId': null,
      'slug': 'bard',
      'name': '吟游诗人',
      'declaredLevels': {'min': null, 'max': null},
      'declared': true,
    });
  });

  test('不认识的名字标记「未声明」，禁止裸子串回填', () {
    final astralRanger = CharacterSheet.local(
      id: 'legacy-astral-ranger',
      name: '星界游侠',
      level: 3,
      classSummary: '星界游侠',
    );

    final projected = const CharacterRuleProjector(
      entries: <String, ContentEntry>{},
    ).project(astralRanger);

    final identity = projected.dataMap['classIdentity'] as Map;
    expect(identity['slug'], isNull, reason: '星界游侠 不得命中 游侠（ranger）');
    expect(identity['entryId'], isNull);
    expect(identity['declared'], isFalse);
    expect(identity['name'], '星界游侠');
    expect(projected.classResources, isEmpty);
  });

  test('有 build.selections.class 条目时以条目身份为准（含声明范围）', () {
    final classEntry = ContentEntry.fromJson({
      'id': 'test:class/astral-knight',
      'type': 'class',
      'slug': 'astral-knight',
      'name': '星界骑士',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'structured': {
        'classRules': {
          'hitDie': 10,
          'spellcasting': {
            'mode': 'prepared',
            'ability': 'cha',
            'archetype': 'half-caster',
            'prepared': {'3': 4, '7': 6},
          },
        },
      },
    });
    final legacy =
        CharacterSheet.local(
          id: 'legacy-knight',
          name: '旧骑士',
          level: 3,
          classSummary: '星界骑士',
        ).copyWith(
          abilities: const <String, Object?>{
            'str': 14,
            'dex': 12,
            'con': 14,
            'int': 10,
            'wis': 10,
            'cha': 16,
          },
          data: <String, Object?>{
            'build': <String, Object?>{
              'level': 3,
              'selections': <String, Object?>{
                'class': 'test:class/astral-knight',
              },
              'choices': <String, Object?>{},
            },
          },
        );

    final projected = CharacterRuleProjector(
      entries: {classEntry.id: classEntry},
    ).project(legacy);

    final identity = projected.dataMap['classIdentity'] as Map;
    expect(identity['entryId'], 'test:class/astral-knight');
    expect(identity['slug'], 'astral-knight');
    expect(identity['declared'], isTrue);
    // 条目**自身**声明的等级范围：prepared 表 3..7。
    expect(identity['declaredLevels'], {'min': 3, 'max': 7});
    expect(projected.dataMap['hitDie'], 10);
    // 3 级半施法者法术位 + prepared 上限都进 data，供详情页/编辑器共用。
    expect(projected.dataMap['spellSlots'], {'1': 3});
    expect(projected.dataMap['preparedSpellLimit'], 4);
  });
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?>? rules,
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'rules': ?rules,
  });
}
