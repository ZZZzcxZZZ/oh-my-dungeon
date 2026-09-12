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

  // P1-1 反向回归：`preparedSpellEntryIds` 是**用户手动准备**的专属存储。选择派生
  // （`copyWithSpellPicksFrom`）只允许写 `alwaysPreparedEntryIds`——派生覆盖手动
  // 准备会让"打开详情页自动再派生 → 保存"把用户的操作持久化丢掉。
  test('copyWithSpellPicksFrom 只更新自动准备镜像，手动准备原样保留', () {
    const existing = CharacterManualOverrides(
      addedSpellEntryIds: ['manual-add'],
      preparedSpellEntryIds: ['old'],
      alwaysPreparedEntryIds: ['old'],
      customSpells: [
        {'id': 'custom', 'name': '星火束'},
      ],
    );
    // 派生结果里仍带旧口径的 `preparedEntryIds`（与 alwaysPrepared 不同）：
    // 合并必须**完全忽略**它，只取 alwaysPrepared。
    const picks = CharacterManualOverrides(
      preparedSpellEntryIds: ['legacy-derived-pick'],
      alwaysPreparedEntryIds: ['spark'],
    );

    final withCustom = existing.copyWith(customSpells: const []);
    expect(withCustom.alwaysPreparedEntryIds, ['old']);
    expect(withCustom.preparedSpellEntryIds, ['old']);

    final merged = existing.copyWithSpellPicksFrom(picks);
    expect(
      merged.preparedSpellEntryIds,
      ['old'],
      reason: '手动准备的法术必须原样保留，派生不得覆盖（反向回归）',
    );
    expect(
      merged.alwaysPreparedEntryIds,
      ['spark'],
      reason: '选择派生的自动准备镜像照常更新',
    );
    expect(
      merged.preparedSpellEntryIds,
      isNot(contains('legacy-derived-pick')),
      reason: '派生结果里的旧口径 preparedEntryIds 不得写进手动存储',
    );
    // 其它字段（手动添加的法术、自定义法术）原样保留，不被"覆盖式合并"丢掉。
    expect(merged.addedSpellEntryIds, ['manual-add']);
    expect(merged.customSpells, hasLength(1));
  });

  // P1-1 读取侧：界面判定"已准备"读**并集**（手动准备 + 选择派生的自动准备）。
  // 并集的唯一实现点是 `ResolvedCharacterOverrides.effectivePreparedSpellEntryIds`。
  test('已准备判定 = 手动准备 ∪ 选择派生的自动准备（只保留存在的法术）', () {
    final character = CharacterSheet.local(id: 'hero', name: 'Hero', level: 2)
        .copyWith(
          data: <String, Object?>{
            'contentRefs': <String, Object?>{
              'spells': <String>['spell:spark', 'spell:ward'],
            },
            'manualOverrides': const CharacterManualOverrides(
              preparedSpellEntryIds: ['spell:ward'],
              alwaysPreparedEntryIds: ['spell:spark', 'spell:gone'],
            ).toJson(),
          },
        );

    final resolved = CharacterOverrideResolver.resolve(character);
    expect(
      resolved.effectivePreparedSpellEntryIds,
      unorderedEquals(<String>['spell:ward', 'spell:spark']),
      reason: '两条来源都要算"已准备"；指向不存在法术的标记不算',
    );
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
