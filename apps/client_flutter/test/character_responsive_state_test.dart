import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/character_builder_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'character detail page preserves the selected section across width changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: CharacterDetailPage(character: _character)),
      );
      await tester.pumpAndSettle();

      // Select the equipment section in compact (TabBar) mode.
      await tester.tap(find.text('装备'));
      await tester.pumpAndSettle();
      expect(find.textContaining('长弓'), findsOneWidget);

      // Rotate to a desktop width; the section selection must persist.
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      // The equipment destination remains selected.
      expect(
        find.byKey(const Key('character-sheet-destination-equipment-selected')),
        findsOneWidget,
      );
      // Equipment section content is still rendered.
      expect(find.textContaining('长弓'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standard character builder preserves the wizard step and draft across '
    'width changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            onSubmit: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to step 3 (属性) and enter a name draft.
      await tester.tap(find.byKey(const Key('builder-step-3')));
      await tester.pumpAndSettle();
      expect(find.text('设置属性'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('standard-character-name-field')),
        '莱娅',
      );
      await tester.pumpAndSettle();

      // Shrink to a phone width; the step selection and draft must persist.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('builder-mobile-step-selector')),
        findsOneWidget,
      );
      expect(find.byType(NavigationRail), findsNothing);
      // Name draft preserved across the viewport change.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('standard-character-name-field')),
            )
            .controller
            ?.text,
        '莱娅',
      );
      // The mobile dropdown reflects the persisted step (4. 属性).
      expect(find.text('4. 属性'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'builder shell uses compact navigation below 900 and rail with summary '
    'at 900 and above',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_shellHarness(selectedIndex: 0));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('builder-mobile-step-selector')),
        findsOneWidget,
      );
      expect(find.byType(NavigationRail), findsNothing);
      // Summary column is hidden on compact layout.
      expect(find.text('摘要内容'), findsNothing);

      // At 900 the rail and fixed summary column must appear.
      tester.view.physicalSize = const Size(900, 1200);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        find.byKey(const Key('builder-mobile-step-selector')),
        findsNothing,
      );
      expect(find.text('摘要内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _shellHarness({required int selectedIndex}) {
  return MaterialApp(
    home: CharacterBuilderShell(
      title: '标准创建角色',
      destinations: const [
        CharacterBuilderDestination(
          id: 0,
          label: '职业',
          icon: Icons.shield_outlined,
        ),
        CharacterBuilderDestination(
          id: 1,
          label: '属性',
          icon: Icons.tune_outlined,
        ),
      ],
      selectedIndex: selectedIndex,
      onSelected: (_) {},
      editor: const Center(child: Text('编辑内容')),
      summary: const Center(child: Text('摘要内容')),
      bottomBar: const SizedBox(height: 56, child: Text('动作区')),
    ),
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
  ],
  currency: {'gp': 10},
  notes: '来自旧林地的游侠。',
  data: {},
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);
