import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

Widget _buildApp(List<ContentEntry> entries) => MaterialApp(
  home: ContentLibraryPage(
    controller: ContentLibraryController(
      repository: MemoryContentRepository(initialEntries: entries),
    ),
    onImportRequested: () {},
  ),
);

ContentEntry _entry(
  String id,
  String type,
  String name,
  Map<String, Object?> structured,
) => ContentEntry.fromJson({
  'id': id,
  'type': type,
  'slug': id.split('/').last,
  'name': name,
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'structured': structured,
});

void main() {
  group('facet fields extension (Task 2.3)', () {
    testWidgets('species type exposes size and speed facets', (tester) async {
      await tester.pumpWidget(
        _buildApp([
          _entry('example:species/elf', 'species', '精灵', {
            'size': '中型',
            'speed': '30 尺',
          }),
          _entry('example:species/dwarf', 'species', '矮人', {
            'size': '中型',
            'speed': '25 尺',
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('种族').last);
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('体型')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('速度')),
        findsOneWidget,
      );
      // size 值带计数后缀.
      expect(
        find.descendant(of: sheet, matching: find.textContaining('中型')),
        findsWidgets,
      );
    });

    testWidgets('background reads legacy skillProficiencies via skills facet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp([
          _entry('example:background/sage', 'background', '贤者', {
            'skillProficiencies': ['奥秘', '历史'],
          }),
          _entry('example:background/acolyte', 'background', '侍僧', {
            'skillProficiencies': ['宗教', '洞察'],
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('背景').last);
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('技能熟练')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('奥秘')),
        findsWidgets,
      );
    });

    testWidgets('condition type exposes duration facet', (tester) async {
      await tester.pumpWidget(
        _buildApp([
          _entry('example:condition/prone', 'condition', '倒地', {
            'duration': '1 回合',
          }),
          _entry('example:condition/poisoned', 'condition', '中毒', {
            'duration': '1 分钟',
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('状态').last);
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('持续')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('1 回合')),
        findsWidgets,
      );
    });

    testWidgets('rule and equipment bundle are not exposed as categories', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp([
          _entry('example:rule/combat', 'rule', '战斗规则', {'category': '战斗'}),
          _entry('example:rule/magic', 'rule', '魔法规则', {'category': '魔法'}),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('content-filter-button')));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('规则')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('装备方案')),
        findsNothing,
      );
    });
  });
}
