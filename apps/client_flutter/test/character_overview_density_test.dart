import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'character detail header renders without overflow across viewports',
    (tester) async {
      for (final size in const [
        Size(360, 800),
        Size(390, 844),
        Size(900, 1200),
        Size(1280, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: CharacterDetailPage(character: _character)),
        );
        await tester.pump();

        expect(find.byKey(const Key('character-detail-avatar')), findsOneWidget);
        expect(find.text('Arannis'), findsWidgets);
        expect(find.text('Elf / Ranger / Lv.3'), findsOneWidget);
        expect(find.text('HP 24/24'), findsOneWidget);
        expect(find.text('AC 15'), findsOneWidget);
        expect(find.text('先攻 +2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('a very long character name does not overflow the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longNamed = _character.copyWith(
      name: '阿兰尼斯·银叶·来自旧林地·游侠·第三纪元·长名测试角色',
    );
    await tester.pumpWidget(
      MaterialApp(home: CharacterDetailPage(character: longNamed)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('character-detail-avatar')), findsOneWidget);
    // AppBar title and header both render the name; the load-bearing assertion
    // is that no overflow exception is thrown at 360px.
    expect(find.textContaining('阿兰尼斯'), findsWidgets);
    expect(find.text('HP 24/24'), findsOneWidget);
    expect(find.text('AC 15'), findsOneWidget);
    expect(find.text('先攻 +2'), findsOneWidget);
  });

  testWidgets(
    'header only carries identity and combat summary, not saves or skills',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CharacterDetailPage(character: _character)),
      );

      // 总览 (overview) destination is the initial tab and must not include
      // 豁免/技能 sections — those live under the '属性' destination.
      expect(find.text('总览'), findsOneWidget);
      expect(find.text('属性'), findsOneWidget);
      expect(find.text('豁免'), findsNothing);
      expect(find.text('技能'), findsNothing);

      // Header combat summary is limited to HP/AC/initiative.
      expect(find.text('HP 24/24'), findsOneWidget);
      expect(find.text('AC 15'), findsOneWidget);
      expect(find.text('先攻 +2'), findsOneWidget);

      await tester.tap(find.text('属性'));
      await tester.pumpAndSettle();
      expect(find.text('豁免'), findsOneWidget);
      expect(find.text('技能'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the HP tile opens a direct numeric input sheet rather than only '
    ' incrementing',
    (tester) async {
      final updates = <Map<String, Object?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: _character,
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
                  updates.add({'currentHp': currentHp});
                },
          ),
        ),
      );

      // The HP status tile is the primary action surface — tapping it must
      // surface the numeric bottom sheet (not silently +/- 1).
      await tester.tap(find.byKey(const Key('runtime-hp-panel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hp-quick-value-field')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '受到伤害'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '恢复 HP'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('hp-quick-value-field')),
        '6',
      );
      await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
      await tester.pumpAndSettle();

      expect(find.text('当前 HP 18/24'), findsOneWidget);
      expect(updates.last['currentHp'], 18);

      // Direct heal path applies the typed value in one step.
      await tester.tap(find.byKey(const Key('runtime-hp-panel')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('hp-quick-value-field')),
        '4',
      );
      await tester.tap(find.widgetWithText(FilledButton, '恢复 HP'));
      await tester.pumpAndSettle();
      expect(find.text('当前 HP 22/24'), findsOneWidget);
      expect(updates.last['currentHp'], 22);
    },
  );
}

const _character = CharacterSheet(
  id: 'char-1',
  ownerUserId: 'user-1',
  name: 'Arannis',
  avatarUrl: null,
  system: 'dnd5e',
  level: 3,
  classSummary: 'Ranger',
  raceSummary: 'Elf',
  currentHp: 24,
  maxHp: 24,
  armorClass: 15,
  speed: 30,
  initiativeBonus: 2,
  abilities: {'str': 10, 'dex': 14, 'con': 12, 'int': 10, 'wis': 14, 'cha': 8},
  saves: {'dex': true, 'wis': true},
  skills: {'察觉': true, '隐匿': true},
  inventory: [
    {'name': '长弓', 'quantity': 1},
    {'name': '治疗药水', 'quantity': 2},
  ],
  currency: {'gp': 10},
  notes: '来自旧林地的游侠。',
  data: {
    'runtime': {
      'temporaryHp': 5,
      'inspiration': true,
      'conditions': ['中毒', '倒地'],
      'deathSaves': {'successes': 1, 'failures': 2},
    },
  },
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);
