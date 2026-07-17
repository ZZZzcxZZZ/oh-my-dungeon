import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('healthFromHp', () {
    test('maps HP ratio to health grade', () {
      expect(CampaignAvatar.healthFromHp(20, 20), CampaignAvatarHealth.healthy);
      expect(CampaignAvatar.healthFromHp(11, 20), CampaignAvatarHealth.healthy);
      expect(CampaignAvatar.healthFromHp(10, 20), CampaignAvatarHealth.injured);
      expect(CampaignAvatar.healthFromHp(6, 20), CampaignAvatarHealth.injured);
      expect(CampaignAvatar.healthFromHp(5, 20), CampaignAvatarHealth.critical);
      expect(CampaignAvatar.healthFromHp(3, 20), CampaignAvatarHealth.critical);
      expect(CampaignAvatar.healthFromHp(0, 20), CampaignAvatarHealth.down);
    });

    test('returns unknown when maxHp missing or zero', () {
      expect(CampaignAvatar.healthFromHp(10, 0), CampaignAvatarHealth.unknown);
      expect(CampaignAvatar.healthFromHp(null, null),
          CampaignAvatarHealth.unknown);
    });
  });

  testWidgets('shows first initial when no image is provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CampaignAvatar(initials: 'AB')),
      ),
    );

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('shows downed indicator when health is down', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CampaignAvatar(initials: 'A', health: CampaignAvatarHealth.down),
        ),
      ),
    );

    expect(find.byTooltip('倒地'), findsOneWidget);
  });

  testWidgets('does not show downed indicator when healthy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CampaignAvatar(
            initials: 'A',
            health: CampaignAvatarHealth.healthy,
          ),
        ),
      ),
    );

    expect(find.byTooltip('倒地'), findsNothing);
  });

  testWidgets('triggers onTap when tapped', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignAvatar(
            initials: 'A',
            onTap: () => tapped++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CampaignAvatar));
    await tester.pump();

    expect(tapped, 1);
  });
}
