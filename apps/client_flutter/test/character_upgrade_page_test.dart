import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('level-up page blocks apply until required choice is selected', (
    tester,
  ) async {
    CharacterSheet? applied;
    final entries = <ContentEntry>[
      _entry(
        id: 'class:fighter',
        type: 'class',
        name: '战士',
        structured: <String, Object?>{'hitDie': 10},
        rules: <String, Object?>{
          'progression': <Object?>[
            <String, Object?>{
              'level': 2,
              'grants': <Object?>[
                <String, Object?>{
                  'id': 'action-surge',
                  'kind': 'feature',
                  'label': '动作如潮',
                  'entryId': 'feature:action-surge',
                },
              ],
              'choices': <Object?>[
                <String, Object?>{
                  'id': 'style',
                  'label': '战斗风格',
                  'optionType': 'feat',
                  'minimum': 1,
                  'maximum': 1,
                },
              ],
            },
          ],
        },
      ),
      _entry(id: 'feature:action-surge', type: 'classFeature', name: '动作如潮'),
      _entry(id: 'feat:defense', type: 'feat', name: '防御'),
    ];
    final character =
        CharacterSheet.local(
          id: 'hero',
          name: '阿雅',
          level: 1,
          classSummary: '战士',
        ).copyWith(
          maxHp: 12,
          currentHp: 12,
          abilities: <String, int>{
            'str': 16,
            'dex': 12,
            'con': 14,
            'int': 10,
            'wis': 10,
            'cha': 8,
          },
          data: <String, Object?>{
            'build': <String, Object?>{
              'level': 1,
              'selections': <String, String>{'class': 'class:fighter'},
              'choices': <String, List<String>>{},
            },
          },
        );

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterUpgradePage(
          character: character,
          contentEntries: entries,
          onApply: (value) async {
            applied = value;
            return true;
          },
        ),
      ),
    );

    expect(find.text('1 → 2 级'), findsOneWidget);
    expect(find.text('动作如潮'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('apply-upgrade')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.widgetWithText(FilterChip, '防御'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('apply-upgrade')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('apply-upgrade')));
    await tester.pumpAndSettle();
    expect(applied?.level, 2);
  });
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?> structured = const <String, Object?>{},
  Map<String, Object?>? rules,
}) => ContentEntry.fromJson(<String, Object?>{
  'id': id,
  'type': type,
  'slug': id.replaceAll(':', '-'),
  'name': name,
  'body': <Object?>[],
  'revision': 1,
  'structured': structured,
  'rules': ?rules,
});
