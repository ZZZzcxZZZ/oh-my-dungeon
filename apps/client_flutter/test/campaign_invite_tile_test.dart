import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_invite_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows invite code and triggers copy and share callbacks', (
    tester,
  ) async {
    var copied = 0;
    var shared = 0;
    final invite = CampaignInvite(
      id: 'i1',
      campaignId: 'c1',
      code: 'ABC123',
      roleOnJoin: 'player',
      expiresAt: null,
      maxUses: 5,
      usedCount: 1,
      requireApproval: false,
      createdAt: '2026-07-17T00:00:00.000Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignInviteTile(
            invite: invite,
            onCopy: () => copied++,
            onShare: () => shared++,
          ),
        ),
      ),
    );

    expect(find.text('ABC123'), findsOneWidget);
    await tester.tap(find.byTooltip('复制邀请码'));
    expect(copied, 1);
    await tester.tap(find.byTooltip('分享邀请码'));
    expect(shared, 1);
  });
}
