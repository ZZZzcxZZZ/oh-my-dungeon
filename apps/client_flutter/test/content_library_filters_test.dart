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

List<ContentEntry> _spellEntries() => [
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
  ContentEntry.fromJson({
    'id': 'example:spell/fly',
    'type': 'spell',
    'slug': 'fly',
    'name': '飞行术',
    'body': <Map<String, Object?>>[],
    'structured': {
      'level': 3,
      'school': '变化',
      'classes': ['术士', '法师'],
    },
    'revision': 1,
  }),
];

void main() {
  group('compact filter system', () {
    testWidgets(
      'mobile first screen shows SearchBar and filter button, no large dropdowns',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildContentTestApp(entries: [testFighterEntry()]),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SearchBar), findsOneWidget);
        expect(find.byKey(const Key('content-filter-button')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SearchBar),
            matching: find.byKey(const Key('content-filter-button')),
          ),
          findsOneWidget,
        );
        // 不显示巨大的下拉框.
        expect(find.byType(DropdownMenu), findsNothing);
        expect(find.byType(FilterChip), findsNothing);
      },
    );

    testWidgets('tapping filter button opens bottom sheet with type options', (
      tester,
    ) async {
      await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      // 类型选项可见.
      expect(find.text('法术'), findsWidgets);
    });

    testWidgets(
      'type picker exposes class features and hides internal bundle types',
      (tester) async {
        await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('content-filter-button')));
        await tester.pumpAndSettle();

        expect(find.text('职业特性'), findsOneWidget);
        expect(find.text('装备方案'), findsNothing);
        expect(find.text('规则'), findsNothing);
      },
    );

    testWidgets(
      'selecting spell type exposes level school and class facets in bottom sheet',
      (tester) async {
        await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('content-filter-button')));
        await tester.pumpAndSettle();

        // 选择法术类型.
        await tester.tap(find.text('法术').last);
        await tester.pumpAndSettle();

        // 法术的结构化 facet 可见.
        expect(find.text('环位'), findsOneWidget);
        expect(find.text('学派'), findsOneWidget);
        expect(find.text('职业'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting a spell level facet shows a compact count and filters results',
      (tester) async {
        await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
        await tester.pumpAndSettle();

        // 打开筛选面板.
        await tester.tap(find.byKey(const Key('content-filter-button')));
        await tester.pumpAndSettle();

        // 选择法术类型.
        await tester.tap(find.text('法术').last);
        await tester.pumpAndSettle();

        // 选择 3 环. Task 2.2: facet chip 带计数后缀 (如 "3环 (2)"), 改用 textContaining.
        await tester.tap(find.textContaining('3环').last);
        await tester.pumpAndSettle();

        // 关闭面板.
        await tester.tap(find.byKey(const Key('content-filter-apply')));
        await tester.pumpAndSettle();

        // 结果被过滤: 只剩 3 环法术.
        expect(find.text('火球术'), findsOneWidget);
        expect(find.text('飞行术'), findsOneWidget);
        expect(find.text('火焰箭'), findsNothing);

        expect(find.byTooltip('筛选，已启用 2 项'), findsOneWidget);
        expect(find.byType(FilterChip), findsNothing);
      },
    );

    testWidgets('clear button in bottom sheet clears all filters', (
      tester,
    ) async {
      await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
      await tester.pumpAndSettle();

      // 设置筛选.
      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('法术').last);
      await tester.pumpAndSettle();
      // Task 2.2: facet chip 带计数后缀, 改用 textContaining.
      await tester.tap(find.textContaining('3环').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-apply')));
      await tester.pumpAndSettle();

      // 确认有筛选.
      expect(find.text('火焰箭'), findsNothing);

      // 打开面板并清除.
      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-apply')));
      await tester.pumpAndSettle();

      // 所有法术都可见.
      expect(find.text('火球术'), findsOneWidget);
      expect(find.text('火焰箭'), findsOneWidget);
      expect(find.text('飞行术'), findsOneWidget);
    });

    testWidgets('active filters are cleared from the compact filter sheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildContentTestApp(entries: _spellEntries()));
      await tester.pumpAndSettle();

      // 设置类型筛选.
      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('法术').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('筛选，已启用 1 项'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-filter-clear')));
      await tester.tap(find.byKey(const Key('content-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('筛选'), findsOneWidget);
    });
  });
}
