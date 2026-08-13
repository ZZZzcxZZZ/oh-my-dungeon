import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('character renders embedded spell snapshots without a library', (
    tester,
  ) async {
    final character = CharacterSheet.fromJson({
      ...CharacterSheet.local(id: 'character-1', name: '米拉', level: 1).toJson(),
      'data': {
        'contentRefs': {
          'features': <String>[],
          'spells': ['core:spell/shield'],
          'items': <String>[],
        },
        'ruleSnapshots': {
          'core:spell/shield': {
            'snapshotVersion': 1,
            'id': 'core:spell/shield',
            'type': 'spell',
            'slug': 'shield',
            'name': '护盾术',
            'summary': '反应施放，短暂提高护甲等级。',
            'body': [
              {'type': 'paragraph', 'text': '直到你的下一回合开始，AC 获得加值。'},
            ],
            'revision': 1,
            'structured': {'level': 1, 'school': 'abjuration'},
          },
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterDetailPage(character: character, initialTab: 'spells'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('护盾术'), findsOneWidget);
    expect(find.textContaining('资料库中不存在'), findsNothing);
  });
}
