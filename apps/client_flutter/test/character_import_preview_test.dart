import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_import_diff.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_import_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diff describes meaningful character changes', () {
    final before = CharacterSheet.local(id: 'hero', name: '旧名字', level: 2);
    final after = CharacterSheet.local(
      id: 'hero',
      name: '新名字',
      level: 3,
    ).copyWith(currentHp: 8, maxHp: 12);

    final diff = CharacterImportDiff.compare(before, after);

    expect(
      diff.changes.map((item) => item.label),
      containsAll(['名称', '等级', '生命值']),
    );
  });

  testWidgets('preview offers create, replace, and merge for a conflict', (
    tester,
  ) async {
    CharacterImportAction? selected;
    final existing = CharacterSheet.local(id: 'hero', name: '旧角色', level: 1);
    final imported = CharacterSheet.local(id: 'hero', name: '导入角色', level: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CharacterImportPreviewSheet(
            imported: imported,
            existing: existing,
            onSelected: (action) => selected = action,
          ),
        ),
      ),
    );

    expect(find.text('导入角色卡'), findsOneWidget);
    expect(find.text('另存为新角色'), findsOneWidget);
    expect(find.text('覆盖原角色'), findsOneWidget);
    expect(find.text('合并到原角色'), findsOneWidget);

    await tester.tap(find.text('合并到原角色'));
    expect(selected, CharacterImportAction.merge);
  });
}
