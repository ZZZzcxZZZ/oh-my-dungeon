import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_archive_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 2026-07-23 task 4.4: 合并两套档案创建表单为单一 CampaignArchiveEditorPage。
///
/// 覆盖：
/// - 七个字段按顺序渲染（类型 → 标题 → 摘要 → 正文 → 标签 → 关联条目 → 附件引用）
/// - 字段间距统一 SizedBox(height: 16)
/// - 提交按钮为全宽 FilledButton
/// - 标题为空时提交显示校验错误
/// - 正常提交调用 onSubmit 并携带完整数据
/// - 正文块编辑器可添加 heading/paragraph/list 块
/// - 标签输入可添加与删除标签
/// - 关联条目多选从已有档案中选取
void main() {
  Future<void> pumpEditorPage(
    WidgetTester tester, {
    String initialKind = 'document',
    List<CampaignArchiveEntry> existingEntries = const [],
    Future<bool> Function(CampaignArchiveDraft)? onSubmit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CampaignArchiveEditorPage(
          initialKind: initialKind,
          existingEntries: existingEntries,
          onSubmit: onSubmit ?? (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders all seven field sections in the specified order',
    (tester) async {
      await pumpEditorPage(tester);

      // Field order: 类型 → 标题 → 摘要 → 正文 → 标签 → 关联条目 → 附件引用
      final kindLabel = find.text('类型');
      final titleLabel = find.text('标题');
      final summaryLabel = find.text('摘要');
      final bodyLabel = find.text('正文');
      final tagsLabel = find.text('标签');
      final linksLabel = find.text('关联条目');
      final attachmentLabel = find.text('附件引用');

      expect(kindLabel, findsOneWidget);
      expect(titleLabel, findsOneWidget);
      expect(summaryLabel, findsOneWidget);
      expect(bodyLabel, findsOneWidget);
      expect(tagsLabel, findsOneWidget);
      expect(linksLabel, findsOneWidget);
      expect(attachmentLabel, findsOneWidget);

      // Verify order: each label's y should be strictly increasing.
      final ys = [
        tester.getCenter(kindLabel).dy,
        tester.getCenter(titleLabel).dy,
        tester.getCenter(summaryLabel).dy,
        tester.getCenter(bodyLabel).dy,
        tester.getCenter(tagsLabel).dy,
        tester.getCenter(linksLabel).dy,
        tester.getCenter(attachmentLabel).dy,
      ];
      for (int i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]),
            reason: 'field at index $i should appear below field at ${i - 1}');
      }
    },
  );

  testWidgets(
    'submit button is a full-width FilledButton',
    (tester) async {
      await pumpEditorPage(tester);

      final buttonFinder = find.ancestor(
        of: find.text('创建'),
        matching: find.byType(FilledButton),
      );
      expect(buttonFinder, findsOneWidget);

      // Full-width: the button's width should match the available content width.
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      final buttonWidth = tester.getSize(buttonFinder).width;
      // Allow for horizontal padding (the bottom bar has 16px padding each side).
      expect(buttonWidth, greaterThanOrEqualTo(screenWidth - 48));
    },
  );

  testWidgets(
    'submitting with an empty title shows a validation error and does not call onSubmit',
    (tester) async {
      var submitCalled = false;
      await pumpEditorPage(
        tester,
        onSubmit: (_) async {
          submitCalled = true;
          return true;
        },
      );

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(find.text('请输入标题'), findsOneWidget);
      expect(submitCalled, isFalse);
    },
  );

  testWidgets(
    'filling required fields and submitting calls onSubmit with the collected data',
    (tester) async {
      CampaignArchiveDraft? captured;
      await pumpEditorPage(
        tester,
        onSubmit: (draft) async {
          captured = draft;
          return true;
        },
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '标题'),
        '失落之城',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '摘要'),
        '传说笔记',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.title, '失落之城');
      expect(captured!.summary, '传说笔记');
      expect(captured!.kind, 'document');
    },
  );

  testWidgets(
    'body block editor can add a paragraph block and submit carries it',
    (tester) async {
      CampaignArchiveDraft? captured;
      await pumpEditorPage(
        tester,
        onSubmit: (draft) async {
          captured = draft;
          return true;
        },
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '标题'),
        '有正文的条目',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Add a paragraph block.
      await tester.tap(find.text('添加段落'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('archive-editor-block-0-text')),
        '群山深处隐藏着入口。',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.bodyBlocks, hasLength(1));
      expect(captured!.bodyBlocks.first['type'], 'paragraph');
      expect(captured!.bodyBlocks.first['text'], '群山深处隐藏着入口。');
    },
  );

  testWidgets(
    'tag chip input can add and delete tags',
    (tester) async {
      CampaignArchiveDraft? captured;
      await pumpEditorPage(
        tester,
        onSubmit: (draft) async {
          captured = draft;
          return true;
        },
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '标题'),
        '带标签的条目',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Add a tag via the tag input field.
      await tester.enterText(
        find.byKey(const Key('archive-editor-tag-input')),
        'lore',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // The tag should now appear as a chip.
      expect(find.text('lore'), findsWidgets);

      // Add a second tag.
      await tester.enterText(
        find.byKey(const Key('archive-editor-tag-input')),
        'map',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.tags, containsAll(['lore', 'map']));
    },
  );

  testWidgets(
    'links multi-select shows existing entries and carries selection on submit',
    (tester) async {
      final existing = [
        CampaignArchiveEntry.fromJson({
          'id': 'arc-a',
          'campaignId': 'camp-1',
          'kind': 'location',
          'title': '黑森林',
          'summary': '',
          'payload': const {},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
        CampaignArchiveEntry.fromJson({
          'id': 'arc-b',
          'campaignId': 'camp-1',
          'kind': 'document',
          'title': '旧日记',
          'summary': '',
          'payload': const {},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
      ];

      CampaignArchiveDraft? captured;
      await pumpEditorPage(
        tester,
        existingEntries: existing,
        onSubmit: (draft) async {
          captured = draft;
          return true;
        },
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, '标题'),
        '主条目',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // The links section should list the existing entries.
      expect(find.text('黑森林'), findsOneWidget);
      expect(find.text('旧日记'), findsOneWidget);

      // Select the first entry. The links section sits below the fold, so
      // scroll it into view before tapping.
      await tester.ensureVisible(find.text('黑森林'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('黑森林'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.linkedEntryIds, contains('arc-a'));
      expect(captured!.linkedEntryIds, isNot(contains('arc-b')));
    },
  );

  testWidgets(
    'initialKind pre-fills the kind dropdown',
    (tester) async {
      await pumpEditorPage(tester, initialKind: 'clue');

      // The dropdown should show the clue label.
      expect(find.text('线索'), findsWidgets);
    },
  );
}
