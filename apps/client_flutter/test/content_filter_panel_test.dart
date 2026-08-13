import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

List<ContentEntry> _spellPackage() => [
  ContentEntry.fromJson({
    'id': 'example:spell/fireball',
    'type': 'spell',
    'slug': 'fireball',
    'name': '火球术',
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'structured': {
      'level': 3,
      'school': '塑能',
      'classes': ['术士', '法师'],
    },
  }),
  ContentEntry.fromJson({
    'id': 'example:spell/lightning-bolt',
    'type': 'spell',
    'slug': 'lightning-bolt',
    'name': '闪电束',
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'structured': {
      'level': 3,
      'school': '塑能',
      'classes': ['术士', '法师'],
    },
  }),
  ContentEntry.fromJson({
    'id': 'example:spell/fly',
    'type': 'spell',
    'slug': 'fly',
    'name': '飞行术',
    'body': <Map<String, Object?>>[],
    'revision': 1,
    'structured': {
      'level': 3,
      'school': '变化',
      'classes': ['术士', '法师'],
    },
  }),
];

Widget _buildApp(List<ContentEntry> entries) => MaterialApp(
  home: ContentLibraryPage(
    controller: ContentLibraryController(
      repository: MemoryContentRepository(initialEntries: entries),
    ),
    onImportRequested: () {},
  ),
);

ContentEntry _backgroundEntry() => ContentEntry.fromJson({
  'id': 'example:background/urchin',
  'type': 'background',
  'slug': 'urchin',
  'name': '流浪儿',
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'structured': {
    'skills': ['隐匿', '巧手'],
  },
});

void main() {
  group('filter panel M3 refactor (Task 2.2)', () {
    testWidgets('facet chips show counts next to value', (tester) async {
      await tester.pumpWidget(_buildApp(_spellPackage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      // 选法术类型.
      await tester.tap(find.text('法术').last);
      await tester.pumpAndSettle();
      // facet 选项异步加载 (facetOptionsWithCounts), 显式 pump 确保完成.
      await tester.pump();
      await tester.pumpAndSettle();

      // 学派 facet 区块可见, 塑能 (2) 与 变化 (1).
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('学派')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('塑能')),
        findsOneWidget,
      );
      // 计数格式: "塑能 (2)" 或 "塑能 · 2", 关键是包含数字.
      final plasticChip = tester.widget<FilterChip>(
        find
            .ancestor(
              of: find.textContaining('塑能'),
              matching: find.byType(FilterChip),
            )
            .first,
      );
      final chipLabel = plasticChip.label as Text;
      expect(chipLabel.data, contains('2'));
      expect(
        find.descendant(of: sheet, matching: find.textContaining('变化')),
        findsOneWidget,
      );
    });

    testWidgets('type filters use ChoiceChip semantics (single-select)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_spellPackage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      // 初始选中 "全部".
      final allChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('全部'), matching: find.byType(ChoiceChip)),
      );
      expect(allChip.selected, isTrue);

      // 点击 "法术" 后, "全部" 应取消选中.
      await tester.tap(find.text('法术').last);
      await tester.pumpAndSettle();

      final allChipAfter = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('全部'), matching: find.byType(ChoiceChip)),
      );
      expect(allChipAfter.selected, isFalse);

      final spellChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('法术'), matching: find.byType(ChoiceChip)),
      );
      expect(spellChip.selected, isTrue);
    });

    testWidgets('facet section title shows leading icon', (tester) async {
      await tester.pumpWidget(_buildApp(_spellPackage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('法术').last);
      await tester.pumpAndSettle();
      // facet 选项异步加载, 显式 pump 确保完成.
      await tester.pump();
      await tester.pumpAndSettle();

      // 学派 facet 标题行应包含 Icon 子节点.
      // 用 widgetList<Row> 直接检查包含 "学派" 文字的所有 Row 祖先.
      final schoolRows = tester.widgetList<Row>(
        find.ancestor(of: find.text('学派'), matching: find.byType(Row)),
      );
      expect(schoolRows, isNotEmpty);
      expect(
        schoolRows.any((row) => row.children.any((child) => child is Icon)),
        isTrue,
      );
    });

    testWidgets('filter sheet is drag-resizable on small screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp(_spellPackage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      // DraggableScrollableSheet 提供 drag handle.
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('registry exposes custom type and canonical background facets', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp([_backgroundEntry()]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      expect(find.text('自定义'), findsOneWidget);
      await tester.tap(find.text('背景'));
      await tester.pumpAndSettle();

      expect(find.text('技能熟练'), findsOneWidget);
      expect(find.textContaining('隐匿'), findsOneWidget);
      expect(find.textContaining('巧手'), findsOneWidget);
    });
  });
}
