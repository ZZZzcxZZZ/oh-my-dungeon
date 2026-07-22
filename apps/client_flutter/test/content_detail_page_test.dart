import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_detail_page.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

void main() {
  late MemoryContentRepository repository;
  late ContentLibraryController controller;
  const entryKey = 'example:spell/fireball';

  setUp(() async {
    repository = MemoryContentRepository(
      initialEntries: [
        ContentEntry.fromJson(const {
          'id': 'example:spell/fireball',
          'type': 'spell',
          'slug': 'fireball',
          'name': '火球术',
          'summary': '爆炸性火焰',
          'body': <Map<String, Object?>>[],
          'tags': ['spell', 'fire'],
          'revision': 1,
        }),
      ],
    );
    controller = ContentLibraryController(repository: repository);
    await controller.refresh();
  });

  Future<void> pumpDetailPage(
    WidgetTester tester, {
    String? entryKeyOverride,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContentDetailPage(
          entryKey: entryKeyOverride ?? entryKey,
          controller: controller,
          onOpenEntry: (_) {},
          onImportRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders entry name and summary', (tester) async {
    await pumpDetailPage(tester);
    expect(find.text('火球术'), findsWidgets);
    expect(find.textContaining('爆炸性火焰'), findsOneWidget);
  });

  testWidgets('reader is read-only with no edit duplicate or note entry',
      (tester) async {
    await pumpDetailPage(tester);
    expect(find.byTooltip('编辑条目'), findsNothing);
    expect(find.byTooltip('复制条目'), findsNothing);
    expect(find.text('笔记'), findsNothing);
  });

  testWidgets('favorite bookmark toggles persistence', (tester) async {
    await pumpDetailPage(tester);
    await tester.tap(find.byTooltip('收藏'));
    await tester.pumpAndSettle();
    expect(await repository.isFavorite(entryKey), isTrue);
    expect(find.byTooltip('取消收藏'), findsOneWidget);
  });
}
