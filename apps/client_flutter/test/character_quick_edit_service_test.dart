import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_manual_overrides.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_profile.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_quick_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CharacterQuickEditService();

  test('quick edits preserve runtime, inventory, and unrelated data', () {
    final original = CharacterSheet.local(id: 'hero', name: 'Hero', level: 1)
        .copyWith(
          inventory: <Map<String, Object?>>[
            <String, Object?>{'name': 'Rope', 'quantity': 1},
          ],
          data: <String, Object?>{
            'runtime': <String, Object?>{'temporaryHp': 4},
            'futureField': <String, Object?>{'keep': true},
          },
        );

    final edited = service
        .addFeature(original, 'feature:observant')
        .let((value) => service.addSpell(value, 'spell:shield'))
        .let((value) => service.setSpellPrepared(value, 'spell:shield', true));

    expect(edited.runtimeMap, <String, Object?>{'temporaryHp': 4});
    expect(edited.inventory, original.inventory);
    expect(edited.dataMap['futureField'], <String, Object?>{'keep': true});
    final overrides = CharacterManualOverrides.fromCharacter(edited);
    expect(overrides.addedFeatureEntryIds, <String>['feature:observant']);
    expect(overrides.addedSpellEntryIds, <String>['spell:shield']);
    expect(overrides.preparedSpellEntryIds, <String>['spell:shield']);
  });

  test('profile update keeps legacy notes synchronized', () {
    final original = CharacterSheet.local(
      id: 'hero',
      name: 'Hero',
      level: 1,
      notes: 'Old note',
    );

    final edited = service.updateProfile(
      original,
      CharacterProfile.fromCharacter(original).copyWith(
        backstory: 'A quiet beginning.',
        privateNotes: 'New private note',
      ),
    );

    expect(edited.notes, 'New private note');
    expect(
      CharacterProfile.fromCharacter(edited).backstory,
      'A quiet beginning.',
    );
    expect(
      CharacterProfile.fromCharacter(edited).privateNotes,
      'New private note',
    );
  });

  test(
    'removing an automatic spell suppresses it without deleting rule data',
    () {
      final original = CharacterSheet.local(id: 'hero', name: 'Hero', level: 1)
          .copyWith(
            data: <String, Object?>{
              'contentRefs': <String, Object?>{
                'spells': <String>['spell:light'],
              },
            },
          );

      final edited = service.removeSpell(original, 'spell:light');

      expect((edited.dataMap['contentRefs'] as Map)['spells'], <String>[
        'spell:light',
      ]);
      expect(
        CharacterManualOverrides.fromCharacter(edited).removedSpellEntryIds,
        <String>['spell:light'],
      );
    },
  );

  // Spec §统一业务列表: 所有快速编辑必须经过 CharacterQuickEditService，
  // 不允许 widget 直接改写 data JSON。下面的用例补齐 service 的覆盖。
  group('feature overrides', () {
    test('addFeature then removeAddedFeature restores the overrides', () {
      final original = CharacterSheet.local(id: 'hero', name: 'Hero', level: 1);

      final added = service.addFeature(original, 'feature:great-weapon-master');
      final overrides = CharacterManualOverrides.fromCharacter(added);
      expect(overrides.addedFeatureEntryIds, <String>[
        'feature:great-weapon-master',
      ]);

      final removed = service.removeAddedFeature(
        added,
        'feature:great-weapon-master',
      );
      expect(
        CharacterManualOverrides.fromCharacter(removed).addedFeatureEntryIds,
        isEmpty,
      );
    });

    test('setGrantHidden toggles a grant key in the overrides', () {
      final original = CharacterSheet.local(id: 'hero', name: 'Hero', level: 1);

      final hidden = service.setGrantHidden(
        original,
        'class/fighter:action-surge',
        true,
      );
      expect(
        CharacterManualOverrides.fromCharacter(hidden).hiddenGrantKeys,
        <String>['class/fighter:action-surge'],
      );

      final restored = service.setGrantHidden(
        hidden,
        'class/fighter:action-surge',
        false,
      );
      expect(
        CharacterManualOverrides.fromCharacter(restored).hiddenGrantKeys,
        isEmpty,
      );
    });

    test(
      'addCustomFeature then removeCustomFeature manages the custom list',
      () {
        final original = CharacterSheet.local(
          id: 'hero',
          name: 'Hero',
          level: 1,
        );

        final added = service.addCustomFeature(
          original,
          name: '家园守护',
          description: '当盟友在身边倒下时获得 +2 攻击',
        );
        final customFeatures = CharacterManualOverrides.fromCharacter(
          added,
        ).customFeatures;
        expect(customFeatures, hasLength(1));
        expect(customFeatures.first['name'], '家园守护');
        expect(customFeatures.first['description'], contains('盟友'));

        final id = customFeatures.first['id'] as String;
        final removed = service.removeCustomFeature(added, id);
        expect(
          CharacterManualOverrides.fromCharacter(removed).customFeatures,
          isEmpty,
        );
      },
    );

    test('addCustomFeature with blank name is a no-op', () {
      final original = CharacterSheet.local(id: 'hero', name: 'Hero', level: 1);

      final edited = service.addCustomFeature(
        original,
        name: '   ',
        description: 'desc',
      );
      expect(
        CharacterManualOverrides.fromCharacter(edited).customFeatures,
        isEmpty,
      );
    });
  });

  group('custom actions', () {
    test('addCustomAction then removeCustomAction manages the action list', () {
      final original = CharacterSheet.local(id: 'hero', name: 'Hero', level: 1);

      final added = service.addCustomAction(
        original,
        name: '鼓舞',
        description: '盟友获得 1d4 鼓舞骰',
      );
      final actions = CharacterManualOverrides.fromCharacter(
        added,
      ).customActions;
      expect(actions, hasLength(1));
      expect(actions.first['name'], '鼓舞');
      expect(actions.first['description'], contains('鼓舞骰'));

      final id = actions.first['id'] as String;
      final removed = service.removeCustomAction(added, id);
      expect(
        CharacterManualOverrides.fromCharacter(removed).customActions,
        isEmpty,
      );
    });

    test('addCustomAction with blank name is a no-op', () {
      final original = CharacterSheet.local(id: 'hero', name: 'Hero', level: 1);

      final edited = service.addCustomAction(
        original,
        name: '',
        description: 'desc',
      );
      expect(
        CharacterManualOverrides.fromCharacter(edited).customActions,
        isEmpty,
      );
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}
