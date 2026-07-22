import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_detail_page.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  group('read-only content library', () {
    testWidgets('empty library has no package management entry', (tester) async {
      final repository = MemoryContentRepository(initialEntries: const []);
      await tester.pumpWidget(
        MaterialApp(
          home: ContentLibraryPage(
            controller: ContentLibraryController(repository: repository),
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('资料库还是空的'), findsOneWidget);
      // 资料包管理 / 导入入口不出现在资料库浏览页.
      expect(find.widgetWithText(FilledButton, '导入资料包'), findsNothing);
      expect(find.byTooltip('导入资料包'), findsNothing);
    });

    testWidgets('search results list has no edit note or duplicate affordances',
        (tester) async {
      final repository = MemoryContentRepository(
        initialEntries: [testFighterEntry()],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ContentLibraryPage(
            controller: ContentLibraryController(repository: repository),
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('战士'), findsOneWidget);
      expect(find.byTooltip('编辑条目'), findsNothing);
      expect(find.byTooltip('复制条目'), findsNothing);
      expect(find.text('笔记'), findsNothing);
      expect(find.text('记录你的笔记…'), findsNothing);
    });

    testWidgets('detail reader has no edit duplicate or note entry',
        (tester) async {
      const entryKey = 'example:class/fighter';
      final repository = MemoryContentRepository(
        initialEntries: [testFighterEntry()],
      );
      final controller = ContentLibraryController(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ContentDetailPage(
            entryKey: entryKey,
            controller: controller,
            onOpenEntry: (_) {},
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('战士'), findsWidgets);
      expect(find.byTooltip('编辑条目'), findsNothing);
      expect(find.byTooltip('复制条目'), findsNothing);
      expect(find.text('笔记'), findsNothing);
      expect(find.text('记录你的笔记…'), findsNothing);
    });

    testWidgets('detail reader keeps the favorite bookmark toggle', (
      tester,
    ) async {
      const entryKey = 'example:spell/fireball';
      final repository = MemoryContentRepository(
        initialEntries: [
          ContentEntry.fromJson(const {
            'id': 'example:spell/fireball',
            'type': 'spell',
            'slug': 'fireball',
            'name': '火球术',
            'summary': '爆炸性火焰',
            'body': <Map<String, Object?>>[],
            'revision': 1,
          }),
        ],
      );
      final controller = ContentLibraryController(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: ContentDetailPage(
            entryKey: entryKey,
            controller: controller,
            onOpenEntry: (_) {},
            onImportRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 收藏是查阅辅助, 保留.
      expect(find.byTooltip('收藏'), findsOneWidget);
    });
  });
}
