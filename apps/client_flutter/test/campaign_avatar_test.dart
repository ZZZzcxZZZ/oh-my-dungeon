import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_composer_identity.dart';
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
      expect(
        CampaignAvatar.healthFromHp(null, null),
        CampaignAvatarHealth.unknown,
      );
    });
  });

  group('healthFromState', () {
    test('maps server health projection to the shared avatar grade', () {
      expect(
        CampaignAvatar.healthFromState('healthy'),
        CampaignAvatarHealth.healthy,
      );
      expect(
        CampaignAvatar.healthFromState('injured'),
        CampaignAvatarHealth.injured,
      );
      expect(
        CampaignAvatar.healthFromState('critical'),
        CampaignAvatarHealth.critical,
      );
      expect(
        CampaignAvatar.healthFromState('down'),
        CampaignAvatarHealth.down,
      );
      expect(
        CampaignAvatar.healthFromState(null),
        CampaignAvatarHealth.unknown,
      );
    });
  });

  test('composer health prefers the current campaign actor sheet', () {
    const actorId = 'actor-1';
    const workspace = CampaignWorkspaceContext(
      campaign: Campaign(
        id: 'campaign-1',
        name: 'Campaign',
        description: '',
        system: 'dnd5e-2024',
        ownerId: 'dm-1',
        status: 'active',
        createdAt: '',
        updatedAt: '',
      ),
      membership: CampaignMembership(
        id: 'membership-1',
        campaignId: 'campaign-1',
        userId: 'dm-1',
        role: 'owner',
        displayName: 'DM',
        joinedAt: '',
        activeSpeakerActorId: actorId,
        speakerMode: 'actor',
      ),
      members: [],
      actors: [
        CampaignWorkspaceActor(
          id: actorId,
          ownerUserId: 'dm-1',
          actorType: 'npc',
          status: 'active',
          lifecycle: 'persistent',
          displayName: 'Guard',
          avatarAssetId: null,
          publicHealthState: 'healthy',
        ),
      ],
      capabilities: CampaignCapabilities(
        canManageCampaign: true,
        canManageMembers: true,
        canCreateActors: true,
        canSpeakAsNarrator: true,
      ),
    );
    const campaignActor = CampaignActor(
      id: actorId,
      campaignId: 'campaign-1',
      ownerUserId: 'dm-1',
      sourceCharacterId: null,
      actorType: 'npc',
      status: 'active',
      sheet: {'name': 'Guard', 'currentHp': 2, 'maxHp': 20, 'armorClass': 13},
      revision: 2,
      updatedBy: 'dm-1',
      createdAt: '',
      updatedAt: '',
    );

    final identity = resolveCampaignComposerIdentity(
      workspace: workspace,
      campaignActors: const [campaignActor],
      localCharacters: const [],
    );

    expect(identity.healthState, 'critical');
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
          body: CampaignAvatar(
            initials: 'A',
            health: CampaignAvatarHealth.down,
          ),
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

  testWidgets('keeps the portrait inset and centered inside the health ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CampaignAvatar(
            initials: 'A',
            size: 48,
            health: CampaignAvatarHealth.healthy,
          ),
        ),
      ),
    );

    final outer = tester.getRect(find.byType(CampaignAvatar));
    final portrait = tester.getRect(find.byType(CircleAvatar));
    expect(portrait.width, lessThan(outer.width));
    expect(portrait.center, outer.center);
  });

  testWidgets('keeps a compact portrait inside a material touch target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CampaignAvatar(
            initials: 'A',
            size: 32,
            tapTargetSize: 48,
            health: CampaignAvatarHealth.injured,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('campaign-avatar-target'))),
      const Size.square(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('campaign-avatar-visual'))),
      const Size.square(32),
    );
    expect(find.bySemanticsLabel('A，受伤'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('triggers onTap when tapped', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignAvatar(initials: 'A', onTap: () => tapped++),
        ),
      ),
    );

    await tester.tap(find.byType(CampaignAvatar));
    await tester.pump();

    expect(tapped, 1);
  });
}
