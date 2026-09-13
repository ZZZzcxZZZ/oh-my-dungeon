// S3 任务 9：角色页消费 `classRuleSources`（来源徽标）与 `classRuleConflicts`
// （冲突横幅 + 选择对话框）；任务 10 的 `CharacterRuleOverrides` 读写形状。
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_rule_overrides.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_upgrade_planner.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/recorded_rule_choices.dart';
import 'package:dnd_table_client/src/features/characters/domain/rule_override_index.dart';
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

    // C：角色**自身条目**不是"覆盖"（解析器无条件包含它、忽略对 entryId 的
    // disabled），因此不得给出点了没反应的关闭按钮。
    testWidgets('来源是角色自身条目时不显示关闭按钮，也按非覆盖样式渲染', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuleSourceChip(
              field: RuleFieldPath.spellcasting('prepared'),
              source: const RuleFieldSource(
                field: 'spellcasting.prepared',
                originId: 'base:class/wizard',
                tier: 100,
              ),
              originLabels: const {'base:class/wizard': '基础包 · 法师'},
              entryOriginId: 'base:class/wizard',
              onDisableOverride: (originId) async {},
            ),
          ),
        ),
      );
      expect(find.text('关闭该来源的覆盖'), findsNothing);
      expect(find.byIcon(Icons.extension_outlined), findsNothing);
      expect(find.byIcon(Icons.rule_outlined), findsOneWidget);
    });

    testWidgets('关闭按钮文案说明"会关闭该来源在所有列上的覆盖"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuleSourceChip(
              field: RuleFieldPath.spellcasting('prepared'),
              source: const RuleFieldSource(
                field: 'spellcasting.prepared',
                originId: 'errata-pack:class/wizard',
                tier: 140,
              ),
              originLabels: const {'errata-pack:class/wizard': '勘误包'},
              entryOriginId: 'base:class/wizard',
              onDisableOverride: (originId) async {},
            ),
          ),
        ),
      );
      expect(find.text('关闭该来源的覆盖'), findsOneWidget);
      expect(
        find.byTooltip('会关闭该来源在所有列上的覆盖'),
        findsOneWidget,
        reason: '按钮按列显示，但 disable(originId) 按整条来源生效',
      );
    });
  });

  group('RuleChoiceListCard', () {
    testWidgets('列出已记录的规则选择（含不产生数值的记录型选项）', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RuleChoiceListCard(
              choices: <RecordedRuleChoice>[
                RecordedRuleChoice(
                  sourceEntryId: 'astral-knight:class/astral-knight',
                  sourceName: '星界骑士',
                  choiceId: 'fighting-style',
                  level: 1,
                  choiceLabel: '选择一项战斗风格',
                  optionIds: <String>['astral-poise'],
                  optionLabels: <String>['星界之势'],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('规则选择'), findsOneWidget);
      expect(find.text('星界骑士 · 选择一项战斗风格（1 级）：星界之势'), findsOneWidget);
    });

    testWidgets('没有记录时给出空态而不是空白卡片', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RuleChoiceListCard(choices: <RecordedRuleChoice>[])),
        ),
      );
      expect(find.text('当前角色没有记录规则选择。'), findsOneWidget);
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

      await tester.tap(find.text('关闭该来源的覆盖'));
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

    // I：对话框默认把每一项选中为 `effectiveOriginId`，只改一列时其余列不得被
    // 静默 pin 上（pin 豁免 disabled 且抑制后续冲突提示，且没有撤销入口）。
    testWidgets('只改一列冲突 → pinned 只含该列（I）', (tester) async {
      CharacterSheet? reapplied;
      const preparedConflict = RuleOverrideConflict(
        field: 'spellcasting.prepared',
        tier: 140,
        originIds: ['alpha:class/wizard', 'zeta:class/wizard'],
        effectiveOriginId: 'alpha:class/wizard',
      );
      const hitDieConflict = RuleOverrideConflict(
        field: 'hitDie',
        tier: 140,
        originIds: ['beta:class/wizard', 'gamma:class/wizard'],
        effectiveOriginId: 'beta:class/wizard',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            initialTab: 'spells',
            character: wizard(
              extra: <String, Object?>{
                'classRuleConflicts': RuleOverrideConflicts.toData(
                  const [preparedConflict, hitDieConflict],
                ),
              },
            ),
            contentEntries: const [],
            packageNames: const {
              'alpha': 'A 包',
              'zeta': 'Z 包',
              'beta': 'B 包',
              'gamma': 'G 包',
            },
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

      expect(find.textContaining('2 处'), findsOneWidget);
      await tester.tap(find.textContaining('处理'));
      await tester.pumpAndSettle();

      // 只改 prepared 那一列；hitDie 保持默认（beta）。
      await tester.tap(find.text('Z 包').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存选择'));
      await tester.pumpAndSettle();

      expect(
        CharacterRuleOverrides.fromCharacter(reapplied!).pinned,
        {'spellcasting.prepared': 'zeta:class/wizard'},
        reason: '用户没动过的列不得被静默 pin',
      );
    });

    // C：关闭覆盖必须留下**恢复入口**（`CharacterRuleOverrides.enable` 的 UI）。
    testWidgets('已关闭的来源出现在「已关闭的来源」区且可恢复（C）', (tester) async {
      CharacterSheet? reapplied;
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            initialTab: 'profile',
            character: wizard(
              extra: <String, Object?>{
                'ruleOverrides': <String, Object?>{
                  'disabledOriginIds': <String>['errata'],
                },
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

      expect(find.text('已关闭的来源'), findsOneWidget);
      expect(find.byKey(const Key('disabled-origin-errata')), findsOneWidget);
      // 建议 10：恢复按钮与邻居"关闭该来源的覆盖"一致都带 Tooltip。
      expect(find.byTooltip('会恢复该来源在所有列上的覆盖'), findsOneWidget);

      await tester.ensureVisible(find.text('恢复'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复'));
      await tester.pumpAndSettle();

      expect(
        CharacterRuleOverrides.fromCharacter(reapplied!).disabledOriginIds,
        isEmpty,
        reason: '恢复必须真的清掉禁用记录并触发再派生',
      );
      expect(find.text('已关闭的来源'), findsNothing);
    });

    // A：`onUpgrade` 必须收到**详情页当前**的角色，而不是打开详情页时捕获的快照
    // ——否则用户在详情页刚做出的覆盖选择会在升级再派生时被静默还原。
    testWidgets('详情页关闭来源后立刻升级：升级回调的参数含该选择（A）', (tester) async {
      CharacterSheet? upgradeArgument;
      CharacterSheet? pageState;
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
            onSaveCharacter: (character) async => true,
            onReapplyRules: (character) async => character,
            onUpgrade: ([CharacterSheet? current]) async {
              // 无参调用的旧签名在这里会把 `current` 留空——正是本用例要抓的差异。
              upgradeArgument = current;
              return current;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      pageState = tester
          .widget<CharacterDetailPage>(find.byType(CharacterDetailPage))
          .character;

      await tester.tap(find.text('关闭该来源的覆盖'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('升级角色'));
      await tester.pumpAndSettle();

      expect(upgradeArgument, isNotNull, reason: 'onUpgrade 的参数必须是当前角色');
      expect(
        CharacterRuleOverrides.fromCharacter(upgradeArgument!).disabledOriginIds,
        {'errata:class/wizard'},
        reason: '升级必须看到详情页刚做出的"关闭来源"选择',
      );
      expect(pageState, isNotNull);
    });

    // L：短休的契约魔法判定必须走**带覆盖**的共享解析，否则"关闭声明
    // `archetype: pact` 的来源"只在数值路径生效、行为路径仍按旧规则恢复全部法术位。
    testWidgets('关闭声明 archetype: pact 的来源后短休不再清空法术位（L）', (tester) async {
      final updates = <Map<String, Object?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _warlock(disabled: {'errata'}),
            contentEntries: _warlockEntries(),
            packagePriorities: _warlockPriorities,
            onUpdateRuntime:
                ({
                  int? currentHp,
                  int? temporaryHp,
                  bool? inspiration,
                  List<String>? conditions,
                  int? deathSaveSuccesses,
                  int? deathSaveFailures,
                  Map<String, int>? spellSlotsUsed,
                  Map<String, int>? classResourcesUsed,
                }) async {
                  updates.add(<String, Object?>{'spellSlotsUsed': spellSlotsUsed});
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(FilledButton, '短休'));
      await tester.tap(find.widgetWithText(FilledButton, '短休'));
      await tester.pumpAndSettle();

      expect(updates, isNotEmpty, reason: '短休必须真的上报运行期更新');
      expect(
        updates.last,
        containsPair('spellSlotsUsed', null),
        reason: '来源已关闭 ⇒ 不再按契约魔法清空法术位（按档案语义保持已用法术位）',
      );
      // 判据本身也要可观察：否则"短路成 null"会让上面的断言假绿。
      expect(
        Dnd5eRules.resolveClassRules(
          entryId: 'base:class/mage',
          classSummary: 'mage',
          overrides: RuleOverrideIndex.fromEntries(
            _warlockEntries(),
            _warlockPriorities,
          ),
          disabledOriginIds: const {'errata'},
        ).usesPactMagic,
        isFalse,
        reason: '勘误关闭后 archetype 不再由勘误提供',
      );
      expect(
        Dnd5eRules.resolveClassRules(
          entryId: 'base:class/mage',
          classSummary: 'mage',
          overrides: RuleOverrideIndex.fromEntries(
            _warlockEntries(),
            _warlockPriorities,
          ),
        ).usesPactMagic,
        isTrue,
        reason: '勘误生效时 archetype 由 errata 提供（对照组前提）',
      );
    });

    testWidgets('未关闭该来源时短休按契约魔法清空法术位（对照组）', (tester) async {
      final updates = <Map<String, Object?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _warlock(),
            contentEntries: _warlockEntries(),
            packagePriorities: _warlockPriorities,
            onUpdateRuntime:
                ({
                  int? currentHp,
                  int? temporaryHp,
                  bool? inspiration,
                  List<String>? conditions,
                  int? deathSaveSuccesses,
                  int? deathSaveFailures,
                  Map<String, int>? spellSlotsUsed,
                  Map<String, int>? classResourcesUsed,
                }) async {
                  updates.add(<String, Object?>{'spellSlotsUsed': spellSlotsUsed});
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(FilledButton, '短休'));
      await tester.tap(find.widgetWithText(FilledButton, '短休'));
      await tester.pumpAndSettle();

      expect(updates, isNotEmpty);
      expect(
        updates.last,
        containsPair('spellSlotsUsed', <String, int>{}),
        reason: '勘误把施法进阶改成 pact（契约魔法）⇒ 短休恢复全部法术位',
      );
    });

    // P0-2.1：法术面板的两个派生快照消费点必须按**键是否存在**判断"是否已派生"。
    // 夹具让回退路径（档案 wizard）确有法术位与施法属性，因此"改回按类型 / 非空
    // 判断"会让下面的断言红。
    testWidgets('空法术位表 / null 施法属性不回退读回档案值（P0-2.1）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            initialTab: 'spells',
            character: CharacterSheet.local(
              id: 'wizard',
              name: '关闭来源后的法师',
              level: 1,
              classSummary: '法师',
            ).copyWith(
              data: <String, Object?>{
                'classIdentity': <String, Object?>{
                  'entryId': 'base:class/wizard',
                  'slug': 'wizard',
                  'declared': true,
                  'declaredLevels': <String, Object?>{'min': 1, 'max': 20},
                },
                // 已派生且"为空 / 未声明"——关闭声明 spellcasting 的来源后的正常结果。
                'spellSlots': <String, Object?>{},
                'spellcastingAbility': null,
              },
            ),
            contentEntries: const [],
            // 面板的早退分支（"暂无法术引用"）需要可编辑权限才会继续渲染。
            onSaveCharacter: (character) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('施法属性 无'),
        findsOneWidget,
        reason: '键存在且为 null = 未声明施法属性，不得回退档案（会显示"智力"）',
      );
      expect(find.text('施法属性 智力'), findsNothing);
      expect(
        find.text('暂无法术位'),
        findsOneWidget,
        reason: '键存在且为空表 = 无法术位，不得回退档案（会渲染 1/2 环法术位行）',
      );
    });
  });
}

/// 基础包只声明"会施法"，`archetype` 由勘误包补成 `pact`——关闭勘误即不再是
/// 契约魔法（L 的行为路径）。slug 故意取**内置档案里没有的职业**（`mage`），
/// 否则档案自己就会补上 `archetype: pact`，勘误开关将无法被观察到。
const _warlockPriorities = <String, int>{'errata': 40};

List<ContentEntry> _warlockEntries() => <ContentEntry>[
  _classEntry('base:class/mage', const {
    'spellcasting': {'mode': 'prepared'},
  }, slug: 'mage'),
  _classEntry('errata:class/mage', const {
    'spellcasting': {'archetype': 'pact'},
  }, slug: 'mage'),
];

/// 1 级邪术师（档案 `archetype: pact`）；[disabled] 写进 `data.ruleOverrides`。
CharacterSheet _warlock({Set<String> disabled = const <String>{}}) =>
    CharacterSheet.local(
      id: 'warlock',
      name: '契约试炼者',
      level: 1,
      classSummary: '邪术师',
    ).copyWith(
      data: <String, Object?>{
        'classIdentity': <String, Object?>{
          'entryId': 'base:class/mage',
          'slug': 'mage',
          'declared': true,
        },
        'runtime': <String, Object?>{
          'spellSlotsUsed': <String, Object?>{'1': 1},
        },
        if (disabled.isNotEmpty)
          'ruleOverrides': <String, Object?>{
            'disabledOriginIds': disabled.toList(),
          },
      },
    );

ContentEntry _classEntry(
  String id,
  Map<String, Object?> classRules, {
  String slug = 'wizard',
}) => ContentEntry.fromJson(<String, Object?>{
      'id': id,
      'type': 'class',
      'slug': slug,
      'name': id,
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{'classRules': classRules},
    });
