import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

Widget buildContentTestApp({required List<ContentEntry> entries}) {
  final repository = MemoryContentRepository(initialEntries: entries);
  return MaterialApp(
    home: ContentLibraryPage(
      controller: ContentLibraryController(repository: repository),
      onImportRequested: () {},
    ),
  );
}

void main() {
  testWidgets('shows an import action when the local library is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildContentTestApp(entries: const []));
    await tester.pumpAndSettle();
    expect(find.text('资料库还是空的'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '导入资料包'), findsOneWidget);
  });

  testWidgets('opens a narrow-screen entry in a floating detail card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildContentTestApp(entries: [testFighterEntry()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('战士'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('战士'), findsWidgets);
  });

  testWidgets('opens a wide-screen entry in a floating detail card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildContentTestApp(entries: [testFighterEntry()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('战士'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('filters favorites only when toggled', (tester) async {
    await tester.pumpWidget(buildContentTestApp(entries: [testFighterEntry()]));
    await tester.pumpAndSettle();
    expect(find.text('战士'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '收藏'));
    await tester.pumpAndSettle();
    expect(find.text('战士'), findsNothing);
  });

  testWidgets('spell type exposes level school and class filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final entries = [
      ContentEntry.fromJson({
        'id': 'example:spell/fireball',
        'type': 'spell',
        'slug': 'fireball',
        'name': '火球术',
        'body': <Map<String, Object?>>[],
        'structured': {
          'level': 3,
          'school': '塑能',
          'classes': ['术士', '法师'],
        },
        'revision': 1,
      }),
      ContentEntry.fromJson({
        'id': 'example:spell/fire-bolt',
        'type': 'spell',
        'slug': 'fire-bolt',
        'name': '火焰箭',
        'body': <Map<String, Object?>>[],
        'structured': {
          'level': 0,
          'school': '塑能',
          'classes': ['术士', '法师'],
        },
        'revision': 1,
      }),
    ];

    await tester.pumpWidget(buildContentTestApp(entries: entries));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('法术').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spell-level-filter')), findsOneWidget);
    expect(find.byKey(const Key('spell-school-filter')), findsOneWidget);
    expect(find.byKey(const Key('spell-class-filter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('spell-level-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3环').last);
    await tester.pumpAndSettle();

    expect(find.text('火球术'), findsOneWidget);
    expect(find.text('火焰箭'), findsNothing);
  });
  testWidgets('shows character grants and choices grouped by level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final fighter = ContentEntry.fromJson({
      'id': 'example:class/fighter',
      'type': 'class',
      'slug': 'fighter',
      'name': '战士',
      'body': <Map<String, Object?>>[],
      'revision': 1,
      'rules': {
        'progression': [
          {
            'level': 1,
            'grants': [
              {'id': 'second-wind', 'kind': 'feature', 'label': '回气'},
            ],
            'choices': [
              {
                'id': 'fighting-style',
                'label': '战斗风格',
                'optionType': 'feat',
                'minimum': 1,
                'maximum': 1,
              },
            ],
          },
        ],
      },
    });

    await tester.pumpWidget(buildContentTestApp(entries: [fighter]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('战士'));
    await tester.pumpAndSettle();

    expect(find.text('角色规则'), findsOneWidget);
    expect(find.text('等级 1'), findsOneWidget);
    expect(find.text('回气'), findsOneWidget);
    expect(find.text('战斗风格'), findsOneWidget);
  });
}
