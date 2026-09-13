// S3 任务 9：角色页消费 `classRuleSources`（来源徽标）与 `classRuleConflicts`
// （冲突横幅 + 选择对话框）；任务 10 的 `CharacterRuleOverrides` 读写形状。
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_overrides.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_upgrade_planner.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/rule_source_list.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_conflict.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleSourceChip', () {
    testWidgets('来源徽标把内置档案与包声明分开显示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RuleSourceChip(
              field: 'spellcasting.prepared',
              source: RuleFieldSource(
                field: 'spellcasting.prepared',
                originId: 'errata-pack:class/wizard',
                tier: 140,
              ),
              originLabels: {'errata-pack:class/wizard': '勘误包'},
            ),
          ),
        ),
      );
      expect(find.textContaining('准备法术上限'), findsOneWidget);
      expect(find.textContaining('勘误包'), findsOneWidget);
      expect(find.byIcon(Icons.extension_outlined), findsOneWidget);
    });

    testWidgets('内置档案来源不显示"覆盖"图标', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RuleSourceChip(
              field: 'hitDie',
              source: RuleFieldSource(
                field: 'hitDie',
                originId: 'builtin:dnd5e-2024',
                tier: 0,
              ),
              originLabels: {'builtin:dnd5e-2024': '内置档案'},
            ),
          ),
        ),
      );
      expect(find.textContaining('内置档案'), findsOneWidget);
      expect(find.byIcon(Icons.rule_outlined), findsOneWidget);
    });

    testWidgets('来源未知不猜成内置档案', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RuleSourceChip(
              field: RuleFieldPath.hitDie,
              source: null,
              originLabels: {},
            ),
          ),
        ),
      );
      expect(find.textContaining('来源未知'), findsOneWidget);
      expect(find.byIcon(Icons.extension_outlined), findsNothing);
    });
  });

  group('RuleOverrideConflictBanner', () {
    testWidgets('冲突横幅列出竞争来源并可打开选择对话框', (tester) async {
      const conflict = RuleOverrideConflict(
        field: 'spellcasting.prepared',
        tier: 110,
        originIds: ['alpha:class/wizard', 'zeta:class/wizard'],
        effectiveOriginId: 'alpha:class/wizard',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuleOverrideConflictBanner(
              conflicts: const [conflict],
              originLabels: const {
                'alpha:class/wizard': 'A 包',
                'zeta:class/wizard': 'Z 包',
              },
              onResolve: (conflicts) async {},
            ),
          ),
        ),
      );
      expect(find.textContaining('1 处'), findsOneWidget);
      await tester.tap(find.textContaining('处理'));
      await tester.pumpAndSettle();
      expect(find.text('覆盖冲突'), findsOneWidget);
      expect(find.text('A 包'), findsWidgets);
      expect(find.text('Z 包'), findsWidgets);
    });

    testWidgets('无冲突时横幅不占位', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuleOverrideConflictBanner(
              conflicts: const [],
              originLabels: const {},
              onResolve: (conflicts) async {},
            ),
          ),
        ),
      );
      expect(find.textContaining('处规则覆盖冲突'), findsNothing);
    });

    testWidgets('用户选择后 onResolve 收到替换过 effectiveOriginId 的冲突', (tester) async {
      const conflict = RuleOverrideConflict(
        field: 'spellcasting.prepared',
        tier: 110,
        originIds: ['alpha:class/wizard', 'zeta:class/wizard'],
        effectiveOriginId: 'alpha:class/wizard',
      );
      List<RuleOverrideConflict>? resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuleOverrideConflictBanner(
              conflicts: const [conflict],
              originLabels: const {
                'alpha:class/wizard': 'A 包',
                'zeta:class/wizard': 'Z 包',
              },
              onResolve: (conflicts) async => resolved = conflicts,
            ),
          ),
        ),
      );
      await tester.tap(find.textContaining('处理'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Z 包').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存选择'));
      await tester.pumpAndSettle();

      expect(resolved, isNotNull);
      expect(resolved!.single.effectiveOriginId, 'zeta:class/wizard');
      expect(resolved!.single.originIds, conflict.originIds);
    });
  });

  group('CharacterRuleOverrides', () {
    test('缺省为空：没有禁用、没有固定来源', () {
      const overrides = CharacterRuleOverrides.empty;
      expect(overrides.disabledOriginIds, isEmpty);
      expect(overrides.pinned, isEmpty);
      expect(overrides.isEmpty, isTrue);
    });

    test('toData 只写非空键：没有覆盖的角色数据逐字不变', () {
      expect(const CharacterRuleOverrides().toData(), isEmpty);
      expect(
        const CharacterRuleOverrides(
          disabledOriginIds: {'errata-pack:class/wizard'},
        ).toData().keys,
        ['disabledOriginIds'],
      );
    });

    test('往返序列化：形状与顺序稳定', () {
      const overrides = CharacterRuleOverrides(
        disabledOriginIds: {'errata-pack:class/wizard'},
        pinned: {'spellcasting.prepared': 'alpha:class/wizard'},
      );
      final data = overrides.toData();
      expect(data['disabledOriginIds'], ['errata-pack:class/wizard']);
      expect(data['pinned'], {'spellcasting.prepared': 'alpha:class/wizard'});
      final restored = CharacterRuleOverrides.fromData(data);
      expect(restored.disabledOriginIds, overrides.disabledOriginIds);
      expect(restored.pinned, overrides.pinned);
    });

    test('坏数据按"没有覆盖"处理，不抛异常（含非 String 键）', () {
      expect(
        CharacterRuleOverrides.fromData(
          {'disabledOriginIds': 'x'},
        ).disabledOriginIds,
        isEmpty,
      );
      expect(CharacterRuleOverrides.fromData({'pinned': {'a': 1}}).pinned, isEmpty);
      expect(
        CharacterRuleOverrides.fromData(<Object?, Object?>{
          'pinned': <Object?, Object?>{1: 'alpha'},
        }).pinned,
        isEmpty,
        reason: '非 String 键必须降级而不是 TypeError',
      );
      expect(CharacterRuleOverrides.fromData('nope').isEmpty, isTrue);
    });

    test('disable / enable 幂等，且按包 id 命中', () {
      final disabled = const CharacterRuleOverrides().disable(
        'errata-pack:class/wizard',
      );
      expect(disabled.isDisabled('errata-pack:class/wizard'), isTrue);
      expect(disabled.isDisabled('errata-pack'), isTrue, reason: '包 id 命中');
      expect(
        disabled.disable('errata-pack:class/wizard').disabledOriginIds,
        disabled.disabledOriginIds,
        reason: '重复 disable 幂等',
      );
      expect(disabled.enable('errata-pack').disabledOriginIds, isEmpty);
    });

    test('pin 落库列路径 → 来源，且不影响 disabled', () {
      final overrides = const CharacterRuleOverrides(
        disabledOriginIds: {'other'},
      ).pin('spellcasting.prepared', 'alpha:class/wizard');
      expect(overrides.pinned, {
        'spellcasting.prepared': 'alpha:class/wizard',
      });
      expect(overrides.disabledOriginIds, {'other'});
    });
  });

  // 0.4-1：关闭覆盖必须一路带到升级 / 快速创建，不能在再派生时被静默还原。
  group('关闭覆盖后升级再派生仍然关闭', () {
    final classEntry = _classEntry('base:class/wizard', {
      'hitDie': 6,
      'spellcasting': {
        'mode': 'prepared',
        'ability': 'int',
        'prepared': {'1': 2, '2': 3},
      },
    });
    final errata = _classEntry('errata:class/wizard', {
      'spellcasting': {
        'prepared': {'1': 9, '2': 9},
      },
    });
    final entries = <String, ContentEntry>{
      classEntry.id: classEntry,
      errata.id: errata,
    };
    final priorities = <String, int>{'errata': 40};

    CharacterSheet character({Set<String> disabled = const <String>{}}) =>
        CharacterSheet.local(
          id: 'wizard',
          name: '关闭覆盖的法师',
          level: 1,
          classSummary: '法师',
        ).copyWith(
          data: <String, Object?>{
            'build': <String, Object?>{
              'level': 1,
              'selections': <String, Object?>{'class': 'base:class/wizard'},
              'choices': <String, Object?>{},
            },
            if (disabled.isNotEmpty)
              'ruleOverrides': <String, Object?>{
                'disabledOriginIds': disabled.toList(),
              },
          },
        );

    CharacterUpgradePlanner planner({required Set<String> disabled}) =>
        CharacterUpgradePlanner(
          entries: entries,
          packagePriorities: priorities,
          disabledOriginIds: disabled,
        );

    test('升级 apply 后勘误不回来，来源快照也是关闭后的', () {
      final original = character(disabled: {'errata'});
      final withDisabled = planner(disabled: {'errata'});
      final applied = withDisabled.apply(original, withDisabled.plan(original));

      expect(applied.level, 2);
      expect(
        applied.dataMap['preparedSpellLimit'],
        3,
        reason: '勘误关闭后 2 级用职业自身条目（3），不是勘误的 9',
      );
      final sources = applied.dataMap['classRuleSources']! as Map;
      expect(
        (sources['spellcasting.prepared']! as Map)['originId'],
        'base:class/wizard',
      );
      expect(
        applied.dataMap['ruleOverrides'],
        original.dataMap['ruleOverrides'],
        reason: '用户状态原样保留',
      );
    });

    test('未关闭时勘误生效（对照组）', () {
      final original = character();
      final plain = planner(disabled: const <String>{});
      final applied = plain.apply(original, plain.plan(original));

      expect(applied.dataMap['preparedSpellLimit'], 9);
      final sources = applied.dataMap['classRuleSources']! as Map;
      expect(
        (sources['spellcasting.prepared']! as Map)['originId'],
        'errata:class/wizard',
      );
    });

    test('RulesDrivenCharacterBuilder 也带 disabledOriginIds（编辑器 / 快速创建）', () {
      final withDisabled = RulesDrivenCharacterBuilder(
        entries: entries,
        packagePriorities: priorities,
        disabledOriginIds: const {'errata'},
      ).build(
        name: '关闭覆盖的法师',
        build: const CharacterBuild(
          level: 1,
          selections: {'class': 'base:class/wizard'},
        ),
        abilities: Dnd5eRules.defaultAbilities,
      );
      expect(withDisabled.data['preparedSpellLimit'], 2);

      final plain = RulesDrivenCharacterBuilder(
        entries: entries,
        packagePriorities: priorities,
      ).build(
        name: '法师',
        build: const CharacterBuild(
          level: 1,
          selections: {'class': 'base:class/wizard'},
        ),
        abilities: Dnd5eRules.defaultAbilities,
      );
      expect(plain.data['preparedSpellLimit'], 9);
    });
  });

  // 任务 9 的 UI 接线：角色页必须真的**消费** data.classRuleSources /
  // data.classRuleConflicts，并且关闭覆盖 / 选择来源要经 onReapplyRules 落库。
  group('角色页接线（法术面板）', () {
    CharacterSheet wizard({Map<String, Object?>? extra}) =>
        CharacterSheet.local(
          id: 'wizard',
          name: '接线法师',
          level: 5,
          classSummary: '法师',
        ).copyWith(
          data: <String, Object?>{
            'classIdentity': <String, Object?>{
              'entryId': 'base:class/wizard',
              'slug': 'wizard',
              'declared': true,
            },
            'spellSlots': <String, Object?>{'1': 4, '2': 3},
            'spellcastingAbility': 'int',
            'preparedSpellLimit': 9,
            ...?extra,
          },
        );

    testWidgets('来源徽标消费 classRuleSources；关闭覆盖经 onReapplyRules 落库', (tester) async {
      CharacterSheet? reapplied;
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            initialTab: 'spells',
            character: wizard(
              extra: <String, Object?>{
                'classRuleSources': RuleFieldSourceMap.toData(
                  const <String, RuleFieldSource>{
                    'spellcasting.prepared': RuleFieldSource(
                      field: 'spellcasting.prepared',
                      originId: 'errata:class/wizard',
                      tier: 140,
                    ),
                  },
                ),
              },
            ),
            contentEntries: const [],
            packageNames: const {'errata': '勘误包'},
            onSaveCharacter: (character) async {
              reapplied = character;
              return true;
            },
            onReapplyRules: (character) async {
              reapplied = character;
              return character;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('准备法术上限'), findsOneWidget);
      expect(find.textContaining('勘误包'), findsOneWidget);

      await tester.tap(find.text('使用内置档案'));
      await tester.pumpAndSettle();

      expect(reapplied, isNotNull);
      expect(
        CharacterRuleOverrides.fromCharacter(reapplied!).disabledOriginIds,
        {'errata:class/wizard'},
        reason: '关闭覆盖必须写进 data.ruleOverrides 并触发再派生',
      );
    });

    testWidgets('冲突横幅消费 classRuleConflicts，选择来源后落库 pinned', (tester) async {
      CharacterSheet? reapplied;
      const conflict = RuleOverrideConflict(
        field: 'spellcasting.prepared',
        tier: 140,
        originIds: ['alpha:class/wizard', 'zeta:class/wizard'],
        effectiveOriginId: 'alpha:class/wizard',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            initialTab: 'spells',
            character: wizard(
              extra: <String, Object?>{
                'classRuleConflicts': RuleOverrideConflicts.toData(
                  const [conflict],
                ),
              },
            ),
            contentEntries: const [],
            packageNames: const {'alpha': 'A 包', 'zeta': 'Z 包'},
            onSaveCharacter: (character) async {
              reapplied = character;
              return true;
            },
            onReapplyRules: (character) async {
              reapplied = character;
              return character;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1 处'), findsOneWidget);
      await tester.tap(find.textContaining('处理'));
      await tester.pumpAndSettle();
      expect(find.text('覆盖冲突'), findsOneWidget);

      await tester.tap(find.text('Z 包').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存选择'));
      await tester.pumpAndSettle();

      expect(
        CharacterRuleOverrides.fromCharacter(
          reapplied!,
        ).pinned['spellcasting.prepared'],
        'zeta:class/wizard',
      );
    });
  });
}

ContentEntry _classEntry(String id, Map<String, Object?> classRules) =>
    ContentEntry.fromJson(<String, Object?>{
      'id': id,
      'type': 'class',
      'slug': 'wizard',
      'name': id,
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{'classRules': classRules},
    });
