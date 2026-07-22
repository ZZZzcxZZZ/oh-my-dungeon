import 'package:dnd_table_client/src/features/characters/presentation/widgets/character_sheet_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses a scrollable tab bar on a compact viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('动作'));
    await tester.pumpAndSettle();
    expect(find.text('动作内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a navigation rail and honors the initial id on desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(initialDestinationId: 'actions'));

    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('动作内容'), findsOneWidget);
    await tester.tap(find.byKey(const Key('character-sheet-destination-notes')));
    await tester.pumpAndSettle();
    expect(find.text('资料内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness({String initialDestinationId = 'overview'}) {
  return MaterialApp(
    home: CharacterSheetShell(
      title: '角色卡',
      header: const SizedBox(height: 52, child: Text('角色摘要')),
      initialDestinationId: initialDestinationId,
      destinations: const [
        CharacterSheetDestination(
          id: 'overview',
          label: '总览',
          icon: Icons.dashboard_outlined,
          child: Center(child: Text('总览内容')),
        ),
        CharacterSheetDestination(
          id: 'actions',
          label: '动作',
          icon: Icons.bolt_outlined,
          child: Center(child: Text('动作内容')),
        ),
        CharacterSheetDestination(
          id: 'notes',
          label: '角色资料',
          icon: Icons.notes_outlined,
          child: Center(child: Text('资料内容')),
        ),
      ],
    ),
  );
}
