@Tags(['golden'])
library;

import 'package:dnd_table_client/src/core/widgets/empty_state.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_invite_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_helpers.dart';

/// 关键 UI 元素的视觉回归基线。
///
/// 默认跳过：基线图像对渲染平台敏感，需先在 CI 平台（Linux）生成：
///   flutter test --tags golden --dart-define=GOLDEN_TESTS=true --update-goldens
const bool _goldenEnabled = bool.fromEnvironment('GOLDEN_TESTS');

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'chat say bubble renders with onPrimaryContainer text',
    (tester) async {
      await tester.pumpWidget(
        themedApp(
          SizedBox(
            width: 420,
            child: CampaignChatBubble(
              message: CampaignChatMessage(
                id: 'm1',
                campaignId: 'c1',
                senderId: 'u1',
                campaignCharacterId: 'ch1',
                displayName: '艾莉娅',
                avatarUrl: null,
                kind: 'say',
                content: '你好，冒险者们！让我们出发吧。',
                createdAt: '2026-07-29T20:15:00Z',
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(CampaignChatBubble),
        matchesGoldenFile('goldens/chat_say_bubble.png'),
      );
    },
    skip: !_goldenEnabled,
  );

  testWidgets(
    'invite tile renders the invite code card',
    (tester) async {
      await tester.pumpWidget(
        themedApp(
          SizedBox(
            width: 360,
            child: CampaignInviteTile(
              invite: CampaignInvite(
                id: 'inv1',
                campaignId: 'c1',
                code: 'DND-7F3K',
                roleOnJoin: 'member',
                expiresAt: '2026-08-29T00:00:00Z',
                maxUses: 6,
                usedCount: 2,
                requireApproval: false,
                createdAt: '2026-07-29T00:00:00Z',
              ),
              onCopy: () {},
              onShare: () {},
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(CampaignInviteTile),
        matchesGoldenFile('goldens/invite_tile.png'),
      );
    },
    skip: !_goldenEnabled,
  );

  testWidgets(
    'EmptyState shows icon, title, message and action',
    (tester) async {
      await tester.pumpWidget(
        themedApp(
          SizedBox(
            width: 360,
            height: 280,
            child: EmptyState(
              icon: Icons.group_outlined,
              title: '战役中还没有角色',
              message: '点击右下角按钮创建第一个角色。',
              action: FilledButton.icon(
                onPressed: null,
                icon: Icon(Icons.add),
                label: Text('创建角色'),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(EmptyState),
        matchesGoldenFile('goldens/empty_state.png'),
      );
    },
    skip: !_goldenEnabled,
  );
}
