import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_manual_overrides.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_override_resolver.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile and manual overrides survive a JSON round trip', () {
    const profile = CharacterProfile(
      alignment: 'Neutral Good',
      appearance: 'Silver hair',
      backstory: 'Raised by sages.',
      privateNotes: 'Trust the old map.',
      languages: <String>['Common', 'Elvish'],
    );
    const overrides = CharacterManualOverrides(
      addedFeatureEntryIds: <String>['feature:keen-mind'],
      hiddenGrantKeys: <String>['class:wizard:2:arcane-recovery'],
      addedSpellEntryIds: <String>['spell:shield'],
      removedSpellEntryIds: <String>['spell:light'],
      preparedSpellEntryIds: <String>['spell:shield'],
      customFeatures: <Map<String, Object?>>[
        <String, Object?>{'id': 'custom-feature', 'name': 'Field Training'},
      ],
    );

    expect(CharacterProfile.fromJson(profile.toJson()), profile);
    expect(CharacterManualOverrides.fromJson(overrides.toJson()), overrides);
  });

  test('resolver combines manual entries and can hide an automatic grant', () {
    final character = CharacterSheet.local(id: 'hero', name: 'Hero', level: 2)
        .copyWith(
          data: <String, Object?>{
            'contentRefs': <String, Object?>{
              'features': <String>['feature:auto', 'feature:always'],
              'spells': <String>['spell:light', 'spell:mage-hand'],
            },
            'resolvedGrants': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'auto-feature',
                'kind': 'feature',
                'entryId': 'feature:auto',
                'sourceEntryId': 'class:wizard',
                'sourceLevel': 2,
              },
            ],
            'manualOverrides': const CharacterManualOverrides(
              addedFeatureEntryIds: <String>['feature:manual'],
              hiddenGrantKeys: <String>['class:wizard:2:auto-feature'],
              addedSpellEntryIds: <String>['spell:shield'],
              removedSpellEntryIds: <String>['spell:light'],
              preparedSpellEntryIds: <String>['spell:shield'],
            ).toJson(),
          },
        );

    final resolved = CharacterOverrideResolver.resolve(character);

    expect(resolved.featureEntryIds, <String>[
      'feature:always',
      'feature:manual',
    ]);
    expect(resolved.spellEntryIds, <String>['spell:mage-hand', 'spell:shield']);
    expect(resolved.preparedSpellEntryIds, <String>['spell:shield']);
  });
}
