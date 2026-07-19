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

  testWidgets('edit button opens dialog and updates the entry', (tester) async {
    await pumpDetailPage(tester);

    await tester.tap(find.byTooltip('编辑条目'));
    await tester.pumpAndSettle();

    expect(find.text('编辑条目'), findsOneWidget);
    final nameField = find.byKey(const Key('content-edit-name-field'));
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, '火球术（家规）');
    await tester.pump();

    final summaryField = find.byKey(const Key('content-edit-summary-field'));
    expect(summaryField, findsOneWidget);
    await tester.enterText(summaryField, 'DC 增益 +2');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final updated = await repository.getByKey(entryKey);
    expect(updated?.name, '火球术（家规）');
    expect(updated?.summary, 'DC 增益 +2');
    expect(updated?.revision, 2);
  });

  testWidgets('duplicate button opens dialog and creates a copy',
      (tester) async {
    await pumpDetailPage(tester);

    await tester.tap(find.byTooltip('复制条目'));
    await tester.pumpAndSettle();

    expect(find.text('复制条目'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('content-duplicate-name-field')),
      '火球术（家规副本）',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '创建副本'));
    await tester.pumpAndSettle();

    final duplicate = await repository.getByKey(
      'example:spell/fireball-copy',
    );
    expect(duplicate, isNotNull);
    expect(duplicate!.name, '火球术（家规副本）');
    expect(duplicate.type, 'spell');
    expect(duplicate.summary, '爆炸性火焰');
  });

  testWidgets('duplicate button shows error snackbar when source is missing',
      (tester) async {
    // 让 repository 找不到条目 - 通过让 _entry 被加载后立即删除.
    await pumpDetailPage(tester);
    await repository.deletePackage('example');
    await tester.tap(find.byTooltip('复制条目'));
    await tester.pumpAndSettle();
    // 输入名称后点创建副本, 应当失败提示.
    await tester.enterText(
      find.byKey(const Key('content-duplicate-name-field')),
      '不存在副本',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '创建副本'));
    await tester.pumpAndSettle();
    expect(find.textContaining('复制失败'), findsOneWidget);
  });
}
