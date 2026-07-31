import 'dart:ui' as ui;

import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_character.dart';
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

    test('keeps the exact HP fraction for a progress ring', () {
      expect(CampaignAvatar.fractionFromHp(20, 20), 1);
      expect(CampaignAvatar.fractionFromHp(5, 20), 0.25);
      expect(CampaignAvatar.fractionFromHp(-2, 20), 0);
      expect(CampaignAvatar.fractionFromHp(24, 20), 1);
      expect(CampaignAvatar.fractionFromHp(10, 0), isNull);
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
      expect(CampaignAvatar.healthFromState('down'), CampaignAvatarHealth.down);
      expect(
        CampaignAvatar.healthFromState(null),
        CampaignAvatarHealth.unknown,
      );
    });
  });

  test('composer health prefers the current campaign character sheet', () {
    const characterId = 'character-1';
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
        activeSpeakerCharacterId: characterId,
        speakerMode: 'character',
      ),
      members: [],
      characters: [
        CampaignWorkspaceCharacter(
          id: characterId,
          ownerUserId: 'dm-1',
          characterType: 'npc',
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
        canCreateCharacters: true,
        canSpeakAsNarrator: true,
      ),
    );
    const campaignCharacter = CampaignCharacter(
      id: characterId,
      campaignId: 'campaign-1',
      ownerUserId: 'dm-1',
      sourceCharacterId: null,
      characterType: 'npc',
      status: 'active',
      sheet: {'name': 'Guard', 'currentHp': 2, 'maxHp': 20, 'armorClass': 13},
      revision: 2,
      updatedBy: 'dm-1',
      createdAt: '',
      updatedAt: '',
    );

    final identity = resolveCampaignComposerIdentity(
      workspace: workspace,
      campaignCharacters: const [campaignCharacter],
      localCharacters: const [],
    );

    expect(identity.healthState, 'critical');
    expect(identity.healthFraction, 0.1);
  });

  test('health ring paints remaining HP over a neutral track', () async {
    const size = ui.Size.square(40);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const painter = CampaignHealthRingPainter(
      color: ui.Color(0xFFFF0000),
      trackColor: ui.Color(0xFF0000FF),
      strokeWidth: 4,
      fraction: 0.25,
    );

    painter.paint(canvas, size);
    final image = await recorder.endRecording().toImage(40, 40);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final data = bytes!.buffer.asUint8List();

    ui.Color pixelAt(int x, int y) {
      final offset = (y * 40 + x) * 4;
      return ui.Color.fromARGB(
        data[offset + 3],
        data[offset],
        data[offset + 1],
        data[offset + 2],
      );
    }

    final top = pixelAt(20, 2);
    final bottom = pixelAt(20, 38);
    expect(top.r, greaterThan(top.b));
    expect(bottom.b, greaterThan(bottom.r));
  });

  testWidgets('legacy message rings do not invent a representative fraction', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CampaignAvatar(
          initials: 'A',
          health: CampaignAvatarHealth.healthy,
          useHealthGradeFallback: false,
        ),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.byKey(const Key('campaign-avatar-ring-healthy')),
    );
    expect((paint.painter! as CampaignHealthRingPainter).fraction, 0);
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
