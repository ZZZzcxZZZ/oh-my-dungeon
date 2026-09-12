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

  // 任务 9 / 契约 §3.11 A3：`countsToward == null` 的显式法术选择额外记
  // `alwaysPreparedEntryIds`（仅用于"始终准备"展示标记）。
  test('alwaysPreparedEntryIds 往返且去重', () {
    const overrides = CharacterManualOverrides(
      preparedSpellEntryIds: ['a', 'b'],
      alwaysPreparedEntryIds: ['b', 'c', 'b'],
    );
    final restored = CharacterManualOverrides.fromJson(overrides.toJson());
    expect(restored.alwaysPreparedEntryIds, ['b', 'c']);
    expect(restored.preparedSpellEntryIds, ['a', 'b']);
    expect(restored, overrides);
  });

  test('copyWith 保留 alwaysPreparedEntryIds；copyWithSpellPicksFrom 是唯一合并点', () {
    const existing = CharacterManualOverrides(
      addedSpellEntryIds: ['manual-add'],
      preparedSpellEntryIds: ['old'],
      alwaysPreparedEntryIds: ['old'],
      customSpells: [
        {'id': 'custom', 'name': '星火束'},
      ],
    );
    const picks = CharacterManualOverrides(
      preparedSpellEntryIds: ['spark'],
      alwaysPreparedEntryIds: ['spark'],
    );

    final withCustom = existing.copyWith(customSpells: const []);
    expect(withCustom.alwaysPreparedEntryIds, ['old']);
    expect(withCustom.preparedSpellEntryIds, ['old']);

    final merged = existing.copyWithSpellPicksFrom(picks);
    expect(merged.preparedSpellEntryIds, ['spark']);
    expect(merged.alwaysPreparedEntryIds, ['spark']);
    // 其它字段（手动添加的法术、自定义法术）原样保留，不被"覆盖式合并"丢掉。
    expect(merged.addedSpellEntryIds, ['manual-add']);
    expect(merged.customSpells, hasLength(1));
  });

  test('resolver 只保留当前存在的法术上的 alwaysPrepared 标记', () {
    final character = CharacterSheet.local(id: 'hero', name: 'Hero', level: 2)
        .copyWith(
          data: <String, Object?>{
            'contentRefs': <String, Object?>{
              'spells': <String>['spell:spark'],
            },
            'manualOverrides': const CharacterManualOverrides(
              preparedSpellEntryIds: ['spell:spark', 'spell:gone'],
              alwaysPreparedEntryIds: ['spell:spark', 'spell:gone'],
            ).toJson(),
          },
        );

    final resolved = CharacterOverrideResolver.resolve(character);
    expect(resolved.preparedSpellEntryIds, ['spell:spark']);
    expect(resolved.alwaysPreparedSpellEntryIds, ['spell:spark']);
  });
}
