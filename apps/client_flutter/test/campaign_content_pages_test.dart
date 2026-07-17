import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_change.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/content/campaign_content_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/content/campaign_content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

void main() {
  Future<void> drainStream() async {
    await Future.microtask(() {});
    await Future.microtask(() {});
  }

  test('uses credentials that become available after construction', () async {
    var accessToken = '';
    final apiClient = MemoryCampaignSyncApiClient();
    final controller = CampaignContentController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: '',
      currentUserId: '',
      accessTokenProvider: () => accessToken,
    );
    await controller.selectCampaign('campaign-1');

    accessToken = 'token-after-login';
    final created = await controller.createEntry(
      type: 'note',
      slug: 'after-login',
      name: 'After login',
      entry: const {'body': []},
    );

    expect(created, isTrue);
    expect(apiClient.createEntryCalls.single['accessToken'], 'token-after-login');
    controller.dispose();
  });

  testWidgets(
    'content page lists entries from cache and supports offline reading',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository(
        entries: [
          testContentEntry(id: 'entry-1', name: '月港', type: 'location'),
          testContentEntry(id: 'entry-2', name: '暗影森林', type: 'location'),
        ],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignContentController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignContentPage(
            controller: controller,
            campaignId: 'campaign-1',
            canEdit: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('campaign-content-page')), findsOneWidget);
      expect(find.text('月港'), findsOneWidget);
      expect(find.text('暗影森林'), findsOneWidget);
      expect(find.text('新建条目'), findsOneWidget);

      controller.dispose();
    },
  );

  testWidgets(
    'new entry button opens editor and submit calls api createEntry',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository();
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignContentController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignContentPage(
            controller: controller,
            campaignId: 'campaign-1',
            canEdit: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建条目'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('campaign-content-editor')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('editor-field-name')),
        '黑塔',
      );
      await tester.tap(find.byKey(const Key('editor-type-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('地点').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(apiClient.createEntryCalls, hasLength(1));
      expect(apiClient.createEntryCalls.last['campaignId'], 'campaign-1');
      expect(apiClient.createEntryCalls.last['type'], 'location');
      expect(apiClient.createEntryCalls.last['slug'], 'black-tower');
      expect(apiClient.createEntryCalls.last['name'], '黑塔');

      controller.dispose();
    },
  );

  testWidgets(
    'json import dialog parses array and previews count',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository();
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignContentController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignContentPage(
            controller: controller,
            campaignId: 'campaign-1',
            canEdit: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('import-json-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('campaign-json-import-dialog')), findsOneWidget);

      const jsonText = '''[
        {"type":"location","slug":"moon-harbor","name":"月港","entry":{"body":[]}},
        {"type":"npc","slug":"tavern-keeper","name":"酒馆老板","entry":{"body":[]}}
      ]''';
      await tester.enterText(
        find.byKey(const Key('json-import-text-field')),
        jsonText,
      );
      await tester.tap(find.byKey(const Key('json-import-preview-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 个条目'), findsOneWidget);
      expect(find.text('月港'), findsOneWidget);
      expect(find.text('酒馆老板'), findsOneWidget);

      controller.dispose();
    },
  );

  testWidgets(
    'delete entry calls api and removes from cache',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository(
        entries: [
          testContentEntry(id: 'entry-1', name: '月港'),
        ],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignContentController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignContentPage(
            controller: controller,
            campaignId: 'campaign-1',
            canEdit: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('删除月港'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '确认删除'));
      await tester.pumpAndSettle();

      expect(apiClient.deleteEntryCalls, hasLength(1));
      expect(apiClient.deleteEntryCalls.last, 'entry-1');

      controller.dispose();
    },
  );

  testWidgets(
    'create failure shows error and does not fake success',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository();
      final apiClient = _FailingCreateEntryApiClient();
      final controller = CampaignContentController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignContentPage(
            controller: controller,
            campaignId: 'campaign-1',
            canEdit: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建条目'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('editor-field-name')),
        '失败条目',
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(find.textContaining('创建失败'), findsOneWidget);
      expect(cacheRepository.entries, isEmpty);

      controller.dispose();
    },
  );

  testWidgets(
    'player mode hides edit actions',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository(
        entries: [
          testContentEntry(id: 'entry-1', name: '月港'),
        ],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignContentController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignContentPage(
            controller: controller,
            campaignId: 'campaign-1',
            canEdit: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('月港'), findsOneWidget);
      expect(find.text('新建条目'), findsNothing);
      expect(find.byKey(const Key('import-json-button')), findsNothing);

      controller.dispose();
    },
  );
}

class _FailingCreateEntryApiClient extends MemoryCampaignSyncApiClient {
  @override
  Future<CampaignContentEntrySummary> createEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async {
    throw const CampaignSyncException('Server error', statusCode: 500);
  }
}
