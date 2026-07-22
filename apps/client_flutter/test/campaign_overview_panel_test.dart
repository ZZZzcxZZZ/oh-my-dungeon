import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_overview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 2026-07-23 Wave 1 Task 1.1: 战役中心概览区块重构
///
/// 用户反馈：成员和下面的工具什么设置黏在一起。
/// 改造目标：成员列表与 DM 工具卡/设置区块之间必须有 Divider 分隔，
/// 且 DM 工具卡视觉权重降低（surfaceContainerLow + outlineVariant border，
/// 而非 surfaceContainerHigh）。
void main() {
  const campaign = Campaign(
    id: 'camp-1',
    name: '示例战役',
    description: '战役简介',
    system: 'dnd5e',
    ownerId: 'u-dm',
    status: 'active',
    createdAt: '2026-07-01T00:00:00.000Z',
    updatedAt: '2026-07-01T00:00:00.000Z',
  );

  CampaignMemberPreview member(String id, String name) => CampaignMemberPreview(
        userId: id,
        displayName: name,
        role: 'player',
      );

  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('CampaignOverviewPanel 区块分隔', () {
    testWidgets('DM 模式：成员列表与 DM 工具卡之间存在 Divider',
        (tester) async {
      await tester.pumpWidget(harness(
        CampaignOverviewPanel(
          campaign: campaign,
          canManage: true,
          members: [member('u-1', '玩家A'), member('u-2', '玩家B')],
          onOpenDmControl: () {},
          onEditDetails: () {},
          onTransferOwnership: () {},
          onArchiveCampaign: () {},
          onLeaveCampaign: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final memberList = find.byKey(const Key('campaign-member-list'));
      final dmControl =
          find.byKey(const Key('campaign-overview-dm-control-entry'));
      expect(memberList, findsOneWidget);
      expect(dmControl, findsOneWidget);

      // 两个区块之间必须至少有一个 Divider
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('DM 工具卡不再使用 surfaceContainerHigh 高对比背景',
        (tester) async {
      await tester.pumpWidget(harness(
        CampaignOverviewPanel(
          campaign: campaign,
          canManage: true,
          members: [member('u-1', '玩家A')],
          onOpenDmControl: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final dmControl =
          find.byKey(const Key('campaign-overview-dm-control-entry'));
      expect(dmControl, findsOneWidget);

      final materials = tester.widgetList<Material>(
          find.descendant(of: dmControl, matching: find.byType(Material)));
      final theme = Theme.of(tester.element(dmControl)).colorScheme;
      for (final m in materials) {
        expect(
          m.color,
          isNot(theme.surfaceContainerHigh),
          reason: 'DM 工具卡应降权：不再使用 surfaceContainerHigh',
        );
      }
    });

    testWidgets('DM 工具卡使用 outlineVariant border 降权', (tester) async {
      await tester.pumpWidget(harness(
        CampaignOverviewPanel(
          campaign: campaign,
          canManage: true,
          members: [member('u-1', '玩家A')],
          onOpenDmControl: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final dmControl =
          find.byKey(const Key('campaign-overview-dm-control-entry'));
      final container = tester.widget<Container>(dmControl);
      final decoration = container.decoration;
      expect(decoration, isA<BoxDecoration>(),
          reason: 'DM 工具卡应使用 BoxDecoration 包裹');
      expect((decoration as BoxDecoration).border, isNotNull,
          reason: 'DM 工具卡应使用 Border(outlineVariant) 降低视觉权重');
    });

    testWidgets('玩家模式：成员列表与战役设置区块之间存在 Divider',
        (tester) async {
      await tester.pumpWidget(harness(
        CampaignOverviewPanel(
          campaign: campaign,
          canManage: false,
          members: [member('u-1', '玩家A')],
          onLeaveCampaign: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final memberList = find.byKey(const Key('campaign-member-list'));
      final settings = find.byKey(const Key('campaign-overview-settings'));
      expect(memberList, findsOneWidget);
      expect(settings, findsOneWidget);

      expect(find.byType(Divider), findsWidgets);
    });
  });
}
