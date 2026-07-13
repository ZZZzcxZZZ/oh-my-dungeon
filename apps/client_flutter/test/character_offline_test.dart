import 'package:dnd_table_client/src/features/characters/data/character_repository.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/characters_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

Widget buildOfflineCharacterApp(CharacterRepository repository) {
  return MaterialApp(
    home: CharactersTabPage(
      controller: CharacterController(repository: repository),
    ),
  );
}

void main() {
  testWidgets('creates and edits a character without an auth session', (tester) async {
    final repository = MemoryCharacterRepository();
    await tester.pumpWidget(buildOfflineCharacterApp(repository));
    await tester.tap(find.widgetWithText(FloatingActionButton, '新角色'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('character-name')), 'Arannis');
    await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
    await tester.pumpAndSettle();
    expect(find.text('Arannis'), findsOneWidget);
    expect(await repository.getById('character-1'), isNotNull);
  });

  testWidgets('shows existing local characters without login', (tester) async {
    final repository = MemoryCharacterRepository(
      initial: [testCharacter(id: 'c1', name: 'Existing Hero')],
    );
    await tester.pumpWidget(buildOfflineCharacterApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('Existing Hero'), findsOneWidget);
  });
}
