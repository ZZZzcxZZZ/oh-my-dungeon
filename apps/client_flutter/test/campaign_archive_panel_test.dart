import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_archive_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 2026-07-23 task 3b: 档案升级为 Wiki 的 Flutter 测试。
///
/// 覆盖：
/// - 结构化 wiki 字段（bodyBlocks/tags/links/attachmentRefs）在详情中渲染；
/// - 列表行展示标签；
/// - 窄屏详情使用接近全高的 BottomSheet，宽屏使用最大宽度 760 的 Dialog；
/// - 创建者或 DM 可编辑；其他成员只读；
/// - 编辑表单可编辑正文与标签，不再只有名称和说明。
void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    required List<CampaignArchiveEntry> entries,
    bool canManage = false,
    String? currentUserId,
    String? error,
    bool isLoading = false,
    Future<bool> Function(
      CampaignArchiveEntry entry, {
      String? title,
      String? summary,
      List<Map<String, Object?>>? bodyBlocks,
      List<String>? tags,
    })? onUpdate,
    Future<bool> Function(CampaignArchiveEntry entry)? onArchive,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignArchivePanel(
            entries: entries,
            isLoading: isLoading,
            error: error,
            canManage: canManage,
            currentUserId: currentUserId,
            selectedKind: null,
            onKindChanged: (_) {},
            onRefresh: () async {},
            onArchive: onArchive ?? (_) async => true,
            onUpdate: onUpdate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CampaignArchiveEntry wikiEntry({
    String id = 'archive-wiki-1',
    String title = '失落之城',
    String summary = '传说笔记',
    String? createdBy,
  }) {
    return CampaignArchiveEntry.fromJson({
      'id': id,
      'campaignId': 'camp-1',
      'kind': 'document',
      'title': title,
      'summary': summary,
      'payload': {
        'bodyBlocks': [
          {'type': 'paragraph', 'text': '群山深处隐藏着失落之城的入口。'},
          {'type': 'heading', 'text': '关键线索', 'level': 2},
          {'type': 'list', 'items': ['石碑', '符文']},
        ],
        'tags': ['lore', 'map'],
        'links': [
          {'kind': 'actor', 'id': 'actor-1', 'label': '守护者'}
        ],
        'attachmentRefs': [
          {'kind': 'image', 'url': 'https://example.com/a.png', 'label': '地图照片'}
        ],
      },
      'pinned': false,
      'updatedAt': '2026-07-23T00:00:00.000Z',
      if (createdBy != null) 'createdBy': createdBy,
    });
  }

  testWidgets('archive load errors offer a clear retry action', (tester) async {
    await pumpPanel(
      tester,
      entries: const [],
      error: '当前服务器版本不支持战役档案，请更新服务端',
    );

    expect(find.text('当前服务器版本不支持战役档案，请更新服务端'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets(
    'tapping an archive entry shows a card popup with legacy body content rendered',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-1',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '古老的地图',
        'summary': '一张羊皮纸地图',
        'payload': {
          'body': '地图上标记着失落之城的入口，位于群山深处。',
          'sourceMessageId': 'msg-42',
          'relatedActorId': 'actor-1',
          'relatedLocationId': 'archive-loc-1',
        },
        'pinned': false,
        'updatedAt': '2026-07-17T00:00:00.000Z',
      });

      await pumpPanel(tester, entries: [entry]);

      // Tap the archive entry to open the detail popup.
      await tester.tap(find.text('古老的地图'));
      await tester.pumpAndSettle();

      // Detail popup should show: title, kind banner, summary, body content.
      expect(find.text('古老的地图'), findsWidgets);
      expect(find.text('文档'), findsOneWidget);
      expect(find.text('一张羊皮纸地图'), findsWidgets);
      expect(
        find.text('地图上标记着失落之城的入口，位于群山深处。'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'archive detail popup shows source message and related entities when present',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-2',
        'campaignId': 'camp-1',
        'kind': 'clue',
        'title': '神秘符号',
        'summary': '',
        'payload': {
          'body': '符号与古老教派有关。',
          'sourceMessageId': 'msg-99',
          'relatedActorId': 'actor-5',
          'relatedLocationId': 'archive-loc-3',
        },
        'pinned': true,
        'updatedAt': '2026-07-17T00:00:00.000Z',
      });

      await pumpPanel(tester, entries: [entry]);

      await tester.tap(find.text('神秘符号'));
      await tester.pumpAndSettle();

      // Body should be rendered.
      expect(find.text('符号与古老教派有关。'), findsOneWidget);
      // Source/related metadata chips should appear.
      expect(find.textContaining('来源消息'), findsOneWidget);
      expect(find.textContaining('关联角色'), findsOneWidget);
      expect(find.textContaining('关联地点'), findsOneWidget);
      // Pinned indicator — appears in both the list row and the detail banner.
      expect(find.byIcon(Icons.push_pin), findsWidgets);
    },
  );

  testWidgets(
    'archive detail popup falls back gracefully when payload is empty',
    (tester) async {
      final entry = CampaignArchiveEntry(
        id: 'archive-3',
        campaignId: 'camp-1',
        kind: 'location',
        title: '龙穴',
        summary: '熔岩环绕的洞穴',
        payload: const {},
        pinned: false,
        updatedAt: '2026-07-17T00:00:00.000Z',
      );

      await pumpPanel(tester, entries: [entry]);

      await tester.tap(find.text('龙穴'));
      await tester.pumpAndSettle();

      expect(find.text('龙穴'), findsWidgets);
      expect(find.text('地点'), findsWidgets);
      expect(find.text('熔岩环绕的洞穴'), findsWidgets);
      // No body, no source, no related entities — no extra sections.
      expect(find.textContaining('来源消息'), findsNothing);
      expect(find.textContaining('关联角色'), findsNothing);
    },
  );

  // ---- Wiki content rendering ----

  testWidgets(
    'archive detail renders structured bodyBlocks, tags, links and attachments',
    (tester) async {
      final entry = wikiEntry();

      await pumpPanel(tester, entries: [entry]);

      await tester.tap(find.text('失落之城'));
      await tester.pumpAndSettle();

      // Body blocks: paragraph, heading, list items.
      expect(find.text('群山深处隐藏着失落之城的入口。'), findsOneWidget);
      expect(find.text('关键线索'), findsOneWidget);
      expect(find.text('石碑'), findsOneWidget);
      expect(find.text('符文'), findsOneWidget);

      // Tags section.
      expect(find.text('标签'), findsOneWidget);
      // Tags appear in both the list row and the detail section.
      expect(find.text('lore'), findsWidgets);
      expect(find.text('map'), findsWidgets);

      // Links section — labelled "关联条目".
      expect(find.text('关联条目'), findsOneWidget);
      expect(find.textContaining('守护者'), findsOneWidget);

      // Attachments section.
      expect(find.text('附件'), findsOneWidget);
      expect(find.textContaining('地图照片'), findsOneWidget);
    },
  );

  // ---- Adaptive layout (BottomSheet vs Dialog) ----

  testWidgets('archive detail uses a near-full-height BottomSheet on narrow screens', (
    tester,
  ) async {
    // Force narrow surface.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = wikiEntry();
    await pumpPanel(tester, entries: [entry]);

    await tester.tap(find.text('失落之城'));
    await tester.pumpAndSettle();

    // A modal bottom sheet is on screen.
    expect(find.byType(BottomSheet), findsOneWidget);
    // No Dialog wrapper on narrow screens.
    expect(find.byType(Dialog), findsNothing);

    // The sheet should occupy most of the viewport height (>= 85%).
    final sheetBox = tester.getRect(find.byType(BottomSheet));
    expect(sheetBox.height, greaterThanOrEqualTo(800 * 0.85));
  });

  testWidgets('archive detail uses a max-width-760 Dialog on wide screens', (tester) async {
    // Force wide surface.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = wikiEntry();
    await pumpPanel(tester, entries: [entry]);

    await tester.tap(find.text('失落之城'));
    await tester.pumpAndSettle();

    // A Dialog is on screen, not a BottomSheet.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    // The visible Dialog content (the Material inside Dialog) must not
    // exceed ~760 in width. The Dialog widget itself is the full overlay
    // (it carries the inset padding), so we measure the Material child.
    final materialFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(Material),
    );
    expect(materialFinder, findsWidgets);
    final dialogBox = tester.getRect(materialFinder.first);
    expect(dialogBox.width, lessThanOrEqualTo(760 + 1));
  });

  // ---- Edit permission gating ----

  testWidgets('edit button shows when user is the entry creator', (tester) async {
    final entry = wikiEntry(createdBy: 'user-1');

    await pumpPanel(
      tester,
      entries: [entry],
      canManage: false,
      currentUserId: 'user-1',
      onUpdate: (_, {bodyBlocks, summary, tags, title}) async => true,
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('edit button shows when user is a manager even if not creator', (tester) async {
    final entry = wikiEntry(createdBy: 'user-other');

    await pumpPanel(
      tester,
      entries: [entry],
      canManage: true,
      currentUserId: 'user-1',
      onUpdate: (_, {bodyBlocks, summary, tags, title}) async => true,
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('edit button is hidden when user is neither creator nor manager', (tester) async {
    final entry = wikiEntry(createdBy: 'user-other');

    await pumpPanel(
      tester,
      entries: [entry],
      canManage: false,
      currentUserId: 'user-1',
    );

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  // ---- Edit form with body + tags ----

  testWidgets(
    'tapping edit button opens a form with title, summary, body and tags fields',
    (tester) async {
      final entry = wikiEntry(createdBy: 'user-1');

      await pumpPanel(
        tester,
        entries: [entry],
        canManage: false,
        currentUserId: 'user-1',
        onUpdate: (_, {bodyBlocks, summary, tags, title}) async => true,
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Form should appear with the wiki-editable sections.
      expect(find.text('编辑条目'), findsOneWidget);
      expect(find.byKey(const Key('archive-edit-title')), findsOneWidget);
      expect(find.byKey(const Key('archive-edit-summary')), findsOneWidget);
      expect(find.byKey(const Key('archive-edit-body')), findsOneWidget);
      expect(find.byKey(const Key('archive-edit-tags')), findsOneWidget);

      // Save button present.
      expect(find.byKey(const Key('archive-edit-save')), findsOneWidget);
    },
  );

  testWidgets(
    'submitting the edit form calls onUpdate with bodyBlocks and tags',
    (tester) async {
      final entry = wikiEntry(createdBy: 'user-1');
      Map<String, Object?>? capturedBody;
      List<String>? capturedTags;
      String? capturedTitle;

      await pumpPanel(
        tester,
        entries: [entry],
        canManage: false,
        currentUserId: 'user-1',
        onUpdate: (entry, {bodyBlocks, summary, tags, title}) async {
          capturedBody = bodyBlocks?.firstOrNull;
          capturedTags = tags;
          capturedTitle = title;
          return true;
        },
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Append to body text and tags text.
      await tester.enterText(
        find.byKey(const Key('archive-edit-body')),
        '补充段落：城门破损。',
      );
      await tester.enterText(
        find.byKey(const Key('archive-edit-tags')),
        'lore, map, secret',
      );

      await tester.tap(find.byKey(const Key('archive-edit-save')));
      await tester.pumpAndSettle();

      expect(capturedTitle, isNotNull);
      expect(capturedBody, isNotNull);
      // Tags should be parsed into a list containing the new entry.
      expect(capturedTags, contains('secret'));
    },
  );

  // ---- List rows show tags ----

  testWidgets('archive list rows display tags as compact chips', (tester) async {
    final entry = wikiEntry();

    await pumpPanel(tester, entries: [entry]);

    // Before opening detail: list row should already show tags.
    expect(find.text('lore'), findsOneWidget);
    expect(find.text('map'), findsOneWidget);
  });
}
