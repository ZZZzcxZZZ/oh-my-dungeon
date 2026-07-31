import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_overview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

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

  CampaignMemberPreview member(String id, String name) =>
      CampaignMemberPreview(userId: id, displayName: name, role: 'player');

  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('CampaignOverviewPanel 区块分隔', () {
    testWidgets('DM 模式：成员列表与 DM 工具卡之间存在 Divider', (tester) async {
      await tester.pumpWidget(
        harness(
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
        ),
      );
      await tester.pumpAndSettle();

      final memberList = find.byKey(const Key('campaign-member-list'));
      final dmControl = find.byKey(
        const Key('campaign-overview-dm-control-entry'),
      );
      expect(memberList, findsOneWidget);
      expect(dmControl, findsOneWidget);

      // 两个区块之间必须至少有一个 Divider
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('DM 工具卡不再使用 surfaceContainerHigh 高对比背景', (tester) async {
      await tester.pumpWidget(
        harness(
          CampaignOverviewPanel(
            campaign: campaign,
            canManage: true,
            members: [member('u-1', '玩家A')],
            onOpenDmControl: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dmControl = find.byKey(
        const Key('campaign-overview-dm-control-entry'),
      );
      expect(dmControl, findsOneWidget);

      final materials = tester.widgetList<Material>(
        find.descendant(of: dmControl, matching: find.byType(Material)),
      );
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
      await tester.pumpWidget(
        harness(
          CampaignOverviewPanel(
            campaign: campaign,
            canManage: true,
            members: [member('u-1', '玩家A')],
            onOpenDmControl: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dmControl = find.byKey(
        const Key('campaign-overview-dm-control-entry'),
      );
      final container = tester.widget<Container>(dmControl);
      final decoration = container.decoration;
      expect(
        decoration,
        isA<BoxDecoration>(),
        reason: 'DM 工具卡应使用 BoxDecoration 包裹',
      );
      expect(
        (decoration as BoxDecoration).border,
        isNotNull,
        reason: 'DM 工具卡应使用 Border(outlineVariant) 降低视觉权重',
      );
    });

    testWidgets('玩家模式：成员列表与战役设置区块之间存在 Divider', (tester) async {
      await tester.pumpWidget(
        harness(
          CampaignOverviewPanel(
            campaign: campaign,
            canManage: false,
            members: [member('u-1', '玩家A')],
            onLeaveCampaign: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final memberList = find.byKey(const Key('campaign-member-list'));
      final settings = find.byKey(const Key('campaign-overview-settings'));
      expect(memberList, findsOneWidget);
      expect(settings, findsOneWidget);

      expect(find.byType(Divider), findsWidgets);
    });
  });

  group('CampaignOverviewPanel 成员绑定归属', () {
    testWidgets('成员栏按 boundCharacterId 显示绑定角色，不按 ownerUserId 猜测', (tester) async {
      // 塔夫场景：角色发布者(ownerUserId=主持人) 与绑定者不一致。
      // 主持人未绑定任何角色时，塔夫不应显示在主持人名下。
      final tav = testCampaignCharacter(
        id: 'char-tav',
        ownerUserId: 'u-dm',
        characterType: 'player',
        sheet: {'name': '塔夫'},
      );
      await tester.pumpWidget(
        harness(
          CampaignOverviewPanel(
            campaign: campaign,
            canManage: true,
            members: [
              CampaignMemberPreview(
                userId: 'u-dm',
                displayName: '主持人',
                role: 'owner',
                boundCharacterId: null,
              ),
              CampaignMemberPreview(
                userId: 'u-player',
                displayName: '玩家甲',
                role: 'player',
                boundCharacterId: 'char-tav',
              ),
            ],
            characters: [tav],
            onOpenDmControl: () {},
            onEditDetails: () {},
            onTransferOwnership: () {},
            onArchiveCampaign: () {},
            onLeaveCampaign: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 顶部角色 chip 是"主持人"，成员列表里也是"主持人"，所以至少出现两次
      // （顶部 chip + 成员 displayName）。关键是成员条目必须显示"未绑定角色"。
      expect(find.text('主持人'), findsNWidgets(2));
      expect(find.text('主持人 · 未绑定角色'), findsOneWidget);
      // 玩家绑定塔夫 → 塔夫显示在玩家甲名下
      expect(find.text('玩家甲'), findsOneWidget);
      expect(find.text('塔夫 · 玩家'), findsOneWidget);
      // 塔夫不应出现在主持人条目里（主持人条目只应有一个 subtitle）
      expect(find.text('塔夫 · 主持人'), findsNothing);
    });

    testWidgets('成员绑定角色已归档时不显示角色名', (tester) async {
      await tester.pumpWidget(
        harness(
          CampaignOverviewPanel(
            campaign: campaign,
            canManage: false,
            members: [
              CampaignMemberPreview(
                userId: 'u-player',
                displayName: '玩家甲',
                role: 'player',
                boundCharacterId: 'char-old',
              ),
            ],
            characters: [
              testCampaignCharacter(
                id: 'char-old',
                ownerUserId: 'u-player',
                characterType: 'player',
                status: 'archived',
                sheet: {'name': '旧角色'},
              ),
            ],
            onLeaveCampaign: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('玩家甲'), findsOneWidget);
      expect(find.text('玩家 · 未绑定角色'), findsOneWidget);
      expect(find.text('旧角色'), findsNothing);
    });
  });
}
