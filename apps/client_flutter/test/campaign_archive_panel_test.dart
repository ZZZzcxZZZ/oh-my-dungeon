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
    List<String> selectedTags = const [],
    ValueChanged<List<String>>? onTagsChanged,
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
            selectedTags: selectedTags,
            onTagsChanged: onTagsChanged ?? (_) {},
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
      // ignore: use_null_aware_elements
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

  // Plan 2026-07-23 task 4.1: defensive fallback for legacy bad data.
  // bodyBlocks may contain malformed entries (strings or objects without
  // a `type` field) from before the server-side strict validation. The
  // panel should still surface the body text rather than silently
  // rendering an empty body section.
  testWidgets(
    'archive detail renders legacy body when bodyBlocks contains only malformed entries',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-malformed',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '损坏档案',
        'summary': '正文格式异常的历史数据',
        'payload': {
          // Malformed: bodyBlocks is a list but elements are not Maps.
          'bodyBlocks': ['第一段旧字符串', '第二段旧字符串'],
          // Legacy body fallback — should win when bodyBlocks filters empty.
          'body': '回退到 legacy body。',
        },
        'pinned': false,
        'updatedAt': '2026-07-17T00:00:00.000Z',
      });

      await pumpPanel(tester, entries: [entry]);

      await tester.tap(find.text('损坏档案'));
      await tester.pumpAndSettle();

      // Legacy body should win — user sees text rather than an empty body.
      expect(find.text('回退到 legacy body。'), findsOneWidget);
      // Malformed strings should NOT appear as paragraph blocks.
      expect(find.text('第一段旧字符串'), findsNothing);
    },
  );

  testWidgets(
    'archive detail surfaces malformed bodyBlocks strings when no legacy body exists',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-malformed-only',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '只剩坏数据',
        'summary': '正文格式异常且无 legacy body',
        'payload': {
          // Malformed bodyBlocks with no `body` fallback — the joined
          // strings should be shown so the user sees *something*.
          'bodyBlocks': ['孤立段落一', '孤立段落二'],
        },
        'pinned': false,
        'updatedAt': '2026-07-17T00:00:00.000Z',
      });

      await pumpPanel(tester, entries: [entry]);

      await tester.tap(find.text('只剩坏数据'));
      await tester.pumpAndSettle();

      // The body section should appear with the malformed strings joined.
      expect(find.text('正文'), findsOneWidget);
      expect(find.textContaining('孤立段落一'), findsOneWidget);
      expect(find.textContaining('孤立段落二'), findsOneWidget);
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

    // List row chips should be present inside Card rows (not the filter area).
    final cards = find.byType(Card);
    expect(cards, findsWidgets);
    expect(
      find.descendant(of: cards.first, matching: find.text('lore')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cards.first, matching: find.text('map')),
      findsOneWidget,
    );
  });

  // ---- Tag-based filtering (Plan 2026-07-23 task 4.2) ----

  /// Stateful test wrapper that holds the selectedTags list and re-pumps
  /// the panel whenever onTagsChanged fires. Without this, the stateless
  /// panel cannot reflect the selection state after a tap.
  Future<void> pumpStatefulPanel(
    WidgetTester tester, {
    required List<CampaignArchiveEntry> entries,
    List<String> initialSelectedTags = const [],
  }) async {
    List<String> selectedTags = List<String>.from(initialSelectedTags);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: CampaignArchivePanel(
                entries: entries,
                isLoading: false,
                error: null,
                canManage: false,
                selectedKind: null,
                onKindChanged: (_) {},
                selectedTags: selectedTags,
                onTagsChanged: (next) {
                  setState(() {
                    selectedTags = List<String>.from(next);
                  });
                },
                onRefresh: () async {},
                onArchive: (_) async => true,
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tag filter area shows every distinct tag as a selectable FilterChip',
    (tester) async {
      final entries = [
        CampaignArchiveEntry.fromJson({
          'id': 'a-1',
          'campaignId': 'camp-1',
          'kind': 'document',
          'title': 'Entry A',
          'summary': '',
          'payload': {'tags': ['lore', 'map']},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
        CampaignArchiveEntry.fromJson({
          'id': 'a-2',
          'campaignId': 'camp-1',
          'kind': 'clue',
          'title': 'Entry B',
          'summary': '',
          'payload': {'tags': ['map']},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
      ];

      await pumpStatefulPanel(tester, entries: entries);

      // Each distinct tag should render as a FilterChip.
      expect(find.widgetWithText(FilterChip, 'lore'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'map'), findsOneWidget);
      // Tag chips live inside the filter area, not inside list rows.
      final filterArea = find.byKey(const Key('archive-tag-filter-area'));
      expect(filterArea, findsOneWidget);
      expect(
        find.descendant(of: filterArea, matching: find.byType(FilterChip)),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'tapping a tag FilterChip toggles selection and reflects in the chip state',
    (tester) async {
      final entries = [
        CampaignArchiveEntry.fromJson({
          'id': 'a-1',
          'campaignId': 'camp-1',
          'kind': 'document',
          'title': 'Entry A',
          'summary': '',
          'payload': {'tags': ['lore']},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
      ];

      await pumpStatefulPanel(tester, entries: entries);

      final chip = find.widgetWithText(FilterChip, 'lore');
      expect(chip, findsOneWidget);
      // Initially unselected.
      expect((tester.widget<FilterChip>(chip)).selected, isFalse);

      await tester.tap(chip);
      await tester.pumpAndSettle();

      // After tap: the chip should now be selected.
      expect((tester.widget<FilterChip>(chip)).selected, isTrue);
    },
  );

  testWidgets(
    'tapping a selected tag FilterChip removes it from the selection',
    (tester) async {
      final entries = [
        CampaignArchiveEntry.fromJson({
          'id': 'a-1',
          'campaignId': 'camp-1',
          'kind': 'document',
          'title': 'Entry A',
          'summary': '',
          'payload': {'tags': ['lore', 'map']},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
      ];

      await pumpStatefulPanel(
        tester,
        entries: entries,
        initialSelectedTags: const ['lore', 'map'],
      );

      final loreChip = find.widgetWithText(FilterChip, 'lore');
      final mapChip = find.widgetWithText(FilterChip, 'map');
      expect((tester.widget<FilterChip>(loreChip)).selected, isTrue);
      expect((tester.widget<FilterChip>(mapChip)).selected, isTrue);

      await tester.tap(loreChip);
      await tester.pumpAndSettle();

      expect((tester.widget<FilterChip>(loreChip)).selected, isFalse);
      expect((tester.widget<FilterChip>(mapChip)).selected, isTrue);
    },
  );

  testWidgets(
    'tag filter area is hidden when no entries carry tags',
    (tester) async {
      final entries = [
        CampaignArchiveEntry.fromJson({
          'id': 'a-1',
          'campaignId': 'camp-1',
          'kind': 'document',
          'title': 'Untagged',
          'summary': '',
          'payload': {},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
      ];

      await pumpStatefulPanel(tester, entries: entries);

      expect(find.byKey(const Key('archive-tag-filter-area')), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    },
  );

  testWidgets(
    'selected tag chips show a clear-all action that empties the selection',
    (tester) async {
      final entries = [
        CampaignArchiveEntry.fromJson({
          'id': 'a-1',
          'campaignId': 'camp-1',
          'kind': 'document',
          'title': 'Entry A',
          'summary': '',
          'payload': {'tags': ['lore']},
          'pinned': false,
          'updatedAt': '2026-07-23T00:00:00.000Z',
        }),
      ];

      await pumpStatefulPanel(
        tester,
        entries: entries,
        initialSelectedTags: const ['lore'],
      );

      expect(find.text('清除标签'), findsOneWidget);

      await tester.tap(find.text('清除标签'));
      await tester.pumpAndSettle();

      // After clearing: no chips are selected and the clear button is gone.
      expect(
        (tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'lore'))).selected,
        isFalse,
      );
      expect(find.text('清除标签'), findsNothing);
    },
  );

  // ---- Time formatting + editor display name (Plan 2026-07-23 task 4.3) ----

  /// Detail footer should read `更新于 2026-07-23 · 由 张三` — the ISO
  /// timestamp is collapsed to a yMd date via `intl.DateFormat`, and the
  /// server-provided `updatedByName` snapshot is appended when present.
  testWidgets(
    'detail footer shows formatted date and editor name when updatedByName is present',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-1',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '古老笔记',
        'summary': '',
        'payload': const {},
        'pinned': false,
        'updatedAt': '2026-07-23T14:32:11.000Z',
        'updatedByName': '张三',
      });

      await pumpPanel(tester, entries: [entry]);
      await tester.tap(find.text('古老笔记'));
      await tester.pumpAndSettle();

      expect(find.text('更新于 2026-07-23 · 由 张三'), findsOneWidget);
    },
  );

  testWidgets(
    'detail footer omits editor suffix when updatedByName is null',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-1',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '无署名笔记',
        'summary': '',
        'payload': const {},
        'pinned': false,
        'updatedAt': '2026-07-23T14:32:11.000Z',
      });

      await pumpPanel(tester, entries: [entry]);
      await tester.tap(find.text('无署名笔记'));
      await tester.pumpAndSettle();

      expect(find.text('更新于 2026-07-23'), findsOneWidget);
      expect(find.textContaining('由'), findsNothing);
    },
  );

  testWidgets(
    'detail footer falls back to createdByName when updatedByName is absent',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-1',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '创建者署名',
        'summary': '',
        'payload': const {},
        'pinned': false,
        'updatedAt': '2026-07-23T14:32:11.000Z',
        'createdByName': '李四',
      });

      await pumpPanel(tester, entries: [entry]);
      await tester.tap(find.text('创建者署名'));
      await tester.pumpAndSettle();

      expect(find.text('更新于 2026-07-23 · 由 李四'), findsOneWidget);
    },
  );

  testWidgets(
    'list row shows editor name and formatted date metadata',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-1',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '行元数据',
        'summary': '',
        'payload': const {},
        'pinned': false,
        'updatedAt': '2026-07-23T14:32:11.000Z',
        'updatedByName': '王五',
      });

      await pumpPanel(tester, entries: [entry]);

      expect(find.text('由 王五 · 2026-07-23'), findsOneWidget);
    },
  );

  testWidgets(
    'list row shows only formatted date when editor name is unknown',
    (tester) async {
      final entry = CampaignArchiveEntry.fromJson({
        'id': 'archive-1',
        'campaignId': 'camp-1',
        'kind': 'document',
        'title': '无名行',
        'summary': '',
        'payload': const {},
        'pinned': false,
        'updatedAt': '2026-07-23T14:32:11.000Z',
      });

      await pumpPanel(tester, entries: [entry]);

      expect(find.text('2026-07-23'), findsOneWidget);
      expect(find.textContaining('由'), findsNothing);
    },
  );
}
