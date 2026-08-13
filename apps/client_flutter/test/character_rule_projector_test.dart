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
