import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_context_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<AuthController> buildLoggedInAuthController() async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      'localhost',
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: _FakeAuthClient(),
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();
    return controller;
  }

  group('CampaignContextController workspace context', () {
    test('loads workspace capabilities from the server context', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
      );

      await controller.loadWorkspaceContext('camp-1');

      expect(controller.workspaceContext?.membership.boundActorId, 'actor-1');
      expect(
        controller.workspaceContext?.capabilities.canManageCampaign,
        isFalse,
      );
      expect(controller.isWorkspaceContextLoading, isFalse);
      expect(controller.workspaceContextError, isNull);

      controller.dispose();
      authController.dispose();
    });

    test('captures workspace context load failures without throwing', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(
          workspaceContextError: CampaignApiException(
            'manager only',
            statusCode: 403,
          ),
        ),
      );

      await controller.loadWorkspaceContext('camp-1');

      expect(controller.workspaceContext, isNull);
      expect(controller.isWorkspaceContextLoading, isFalse);
      expect(controller.workspaceContextError, 'manager only');

      controller.dispose();
      authController.dispose();
    });

    test(
      'updates speaker and refreshes the membership inside the context',
      () async {
        final authController = await buildLoggedInAuthController();
        final controller = CampaignContextController(
          apiBaseUrl: apiBaseUrl,
          authController: authController,
          campaignClient: _FakeCampaignClient(),
        );

        await controller.loadWorkspaceContext('camp-1');
        final originalMembership =
            controller.workspaceContext?.membership;

        final updated = await controller.updateSpeaker(
          campaignId: 'camp-1',
          speakerMode: 'ooc',
        );

        expect(updated, isTrue);
        expect(
          controller.workspaceContext?.membership.activeSpeakerActorId,
          isNull,
        );
        // The membership object should have been replaced, not the same instance.
        expect(
          identical(controller.workspaceContext?.membership, originalMembership),
          isFalse,
        );

        controller.dispose();
        authController.dispose();
      },
    );

    test('notifies listeners when workspace context starts and finishes', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
      );

      int notifications = 0;
      controller.addListener(() => notifications += 1);

      await controller.loadWorkspaceContext('camp-1');

      // At least: start loading + finish loading.
      expect(notifications, greaterThanOrEqualTo(2));

      controller.dispose();
      authController.dispose();
    });
  });

  group('CampaignContextController archives', () {
    test('maps a missing archive route to an upgrade message', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(
          archivesError: const CampaignApiException(
            'Cannot GET /api/campaigns/camp-1/archives',
            statusCode: 404,
          ),
        ),
      );

      await controller.loadArchives('camp-1');

      expect(controller.archives, isEmpty);
      expect(controller.archivesError, '当前服务器版本不支持战役档案，请更新服务端');

      controller.dispose();
      authController.dispose();
    });

    test('loads campaign archives independently from the chat stream', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
      );

      await controller.loadArchives('camp-1');

      expect(controller.archives, hasLength(1));
      expect(controller.archives.single.kind, 'clue');
      expect(controller.archives.single.title, 'The silver key');
      expect(controller.isArchivesLoading, isFalse);
      expect(controller.archivesError, isNull);

      controller.dispose();
      authController.dispose();
    });

    test('createArchiveEntry prepends the new entry to the list', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
      );

      await controller.loadArchives('camp-1');
      final created = await controller.createArchiveEntry(
        campaignId: 'camp-1',
        kind: 'document',
        title: 'Letter from Strahd',
      );

      expect(created, isNotNull);
      expect(controller.archives, hasLength(2));
      expect(controller.archives.first.title, 'Letter from Strahd');
      expect(controller.archives.last.title, 'The silver key');

      controller.dispose();
      authController.dispose();
    });

    test('archiveEntry removes the entry from the list', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
      );

      await controller.loadArchives('camp-1');
      final removed = await controller.archiveEntry(
        campaignId: 'camp-1',
        entryId: 'archive-1',
      );

      expect(removed, isTrue);
      expect(controller.archives, isEmpty);

      controller.dispose();
      authController.dispose();
    });
  });

  group('CampaignContextController lifecycle', () {
    test('clearSelection resets workspace and archive state', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
      );

      await controller.loadWorkspaceContext('camp-1');
      await controller.loadArchives('camp-1');
      expect(controller.workspaceContext, isNotNull);
      expect(controller.archives, isNotEmpty);

      controller.clearSelection();

      expect(controller.workspaceContext, isNull);
      expect(controller.workspaceContextError, isNull);
      expect(controller.archives, isEmpty);
      expect(controller.archivesError, isNull);

      controller.dispose();
      authController.dispose();
    });

    test('auth logout resets all context state', () async {
      final authController = await buildLoggedInAuthController();
      final controller = CampaignContextController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
      );

      await controller.loadWorkspaceContext('camp-1');
      await controller.loadArchives('camp-1');
      expect(controller.workspaceContext, isNotNull);
      expect(controller.archives, isNotEmpty);

      await authController.logout();

      expect(controller.workspaceContext, isNull);
      expect(controller.archives, isEmpty);

      controller.dispose();
      authController.dispose();
    });
  });
}

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const AuthUser(
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com',
    );
  }

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCampaignClient implements CampaignClient {
  _FakeCampaignClient({this.workspaceContextError, this.archivesError});

  final CampaignApiException? workspaceContextError;
  final CampaignApiException? archivesError;

  @override
  Future<void> markCampaignRead({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {}

  @override
  Future<CampaignMembership> updateSpeaker({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String speakerMode,
    String? actorId,
  }) async {
    return const CampaignMembership(
      id: 'member-1',
      campaignId: 'camp-1',
      userId: 'user-1',
      role: 'player',
      displayName: 'ranger',
      joinedAt: '2026-07-09T00:00:00.000Z',
      boundActorId: 'actor-1',
      activeSpeakerActorId: null,
    );
  }

  @override
  Future<List<CampaignArchiveEntry>> listArchives({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? kind,
    String? query,
    List<String>? tags,
  }) async {
    if (archivesError != null) throw archivesError!;
    return const [
      CampaignArchiveEntry(
        id: 'archive-1',
        campaignId: 'camp-1',
        kind: 'clue',
        title: 'The silver key',
        summary: '',
        payload: {},
        pinned: false,
        updatedAt: '2026-07-16T00:00:00.000Z',
      ),
    ];
  }

  @override
  Future<CampaignArchiveEntry> createArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String title,
    String? summary,
    Map<String, Object?>? payload,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
    List<Map<String, Object?>>? links,
    List<Map<String, Object?>>? attachmentRefs,
  }) async {
    return CampaignArchiveEntry(
      id: 'archive-new',
      campaignId: campaignId,
      kind: kind,
      title: title,
      summary: summary ?? '',
      payload: payload ?? const {},
      pinned: false,
      updatedAt: '2026-07-17T00:00:00.000Z',
    );
  }

  @override
  Future<CampaignArchiveEntry> updateArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    String? kind,
    String? title,
    String? summary,
    Map<String, Object?>? payload,
    bool? pinned,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
    List<Map<String, Object?>>? links,
    List<Map<String, Object?>>? attachmentRefs,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> archiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) async {}

  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    if (workspaceContextError != null) {
      throw workspaceContextError!;
    }
    return CampaignWorkspaceContext(
      campaign: const Campaign(
        id: 'camp-1',
        name: 'Curse of Strahd',
        description: '',
        system: 'dnd5e',
        ownerId: 'user-1',
        status: 'active',
        createdAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
      ),
      membership: const CampaignMembership(
        id: 'member-1',
        campaignId: 'camp-1',
        userId: 'user-1',
        role: 'player',
        displayName: 'ranger',
        joinedAt: '2026-07-09T00:00:00.000Z',
        boundActorId: 'actor-1',
        activeSpeakerActorId: 'actor-1',
      ),
      members: const [],
      actors: const [],
      capabilities: const CampaignCapabilities(
        canManageCampaign: false,
        canManageMembers: false,
        canCreateActors: false,
        canSpeakAsNarrator: false,
      ),
    );
  }

  @override
  Future<Campaign> createCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    String? description,
    String? system,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CampaignChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? query,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CampaignChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
    String? actionId,
    Map<String, Object?>? eventData,
    Map<String, Object?>? speakerSnapshot,
  }) {
    throw UnimplementedError();
  }
}
