import 'package:dnd_table_client/src/features/characters/presentation/widgets/character_builder_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the compact step selector on a phone', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = -1;

    await tester.pumpWidget(
      _harness(onSelected: (index) => selected = index),
    );

    expect(find.byKey(const Key('builder-mobile-step-selector')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.byKey(const Key('builder-mobile-step-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. 属性').last);
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a rail and fixed summary on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = -1;

    await tester.pumpWidget(
      _harness(onSelected: (index) => selected = index),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('builder-mobile-step-selector')), findsNothing);
    expect(find.text('摘要内容'), findsOneWidget);
    await tester.tap(find.byKey(const Key('builder-step-1')));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}

Widget _harness({required ValueChanged<int> onSelected}) {
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
      selectedIndex: 0,
      onSelected: onSelected,
      editor: const Center(child: Text('编辑内容')),
      summary: const Center(child: Text('摘要内容')),
      bottomBar: const SizedBox(height: 56, child: Text('动作区')),
    ),
  );
}
