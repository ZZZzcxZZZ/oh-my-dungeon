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
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}
