import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_archive_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec §档案: 点击档案条目后用更丰富的卡片浮窗展示完整信息：
/// 标题、类型、正文、来源消息、关联角色、关联地点、相关条目。
void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    required List<CampaignArchiveEntry> entries,
    bool canManage = false,
    String? error,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignArchivePanel(
            entries: entries,
            isLoading: false,
            error: error,
            canManage: canManage,
            selectedKind: null,
            onKindChanged: (_) {},
            onRefresh: () async {},
            onArchive: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
    'tapping an archive entry shows a card popup with body content rendered',
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
      // Pinned indicator.
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
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
}
