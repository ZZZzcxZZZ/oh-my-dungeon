import 'package:dnd_table_client/src/features/content/data/campaign_aware_content_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/content_test_support.dart';

void main() {
  group('CampaignAwareContentRepository', () {
    test('searches local packages and current campaign cache without overriding',
        () async {
      final localEntry = ContentEntry.fromJson({
        'id': 'example:location/moon-harbor',
        'type': 'location',
        'slug': 'moon-harbor',
        'name': '月港',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      });
      final campaignEntry = testContentEntry(
        id: 'campaign-entry-1',
        campaignId: 'campaign-1',
        type: 'location',
        slug: 'moon-harbor-homebrew',
        name: '月港',
      );
      final localRepo = MemoryContentRepository(initialEntries: [localEntry]);
      final campaignCache = MemoryCampaignCacheRepository(
        entries: [campaignEntry],
      );
      final repo = CampaignAwareContentRepository(
        local: localRepo,
        campaign: campaignCache,
        activeCampaignId: () => 'campaign-1',
      );

      final results = await repo.search(const ContentQuery(text: '月港'));

      expect(
        results.map((entry) => entry.origin),
        containsAll([ContentOrigin.local, ContentOrigin.campaign]),
      );
      // 同名条目都应保留，不互相覆盖。
      expect(results.where((e) => e.name == '月港'), hasLength(2));
    });

    test('returns only local entries when no active campaign', () async {
      final localEntry = ContentEntry.fromJson({
        'id': 'example:location/moon-harbor',
        'type': 'location',
        'slug': 'moon-harbor',
        'name': '月港',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      });
      final localRepo = MemoryContentRepository(initialEntries: [localEntry]);
      final campaignCache = MemoryCampaignCacheRepository(
        entries: [
          testContentEntry(
            id: 'campaign-entry-1',
            campaignId: 'campaign-1',
            name: '月港',
          ),
        ],
      );
      final repo = CampaignAwareContentRepository(
        local: localRepo,
        campaign: campaignCache,
        activeCampaignId: () => null,
      );

      final results = await repo.search(const ContentQuery(text: '月港'));

      expect(results, hasLength(1));
      expect(results.single.origin, ContentOrigin.local);
    });

    test('getByKey returns local entry by local key', () async {
      final localEntry = ContentEntry.fromJson({
        'id': 'example:location/moon-harbor',
        'type': 'location',
        'slug': 'moon-harbor',
        'name': '月港',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      });
      final localRepo = MemoryContentRepository(initialEntries: [localEntry]);
      final campaignCache = MemoryCampaignCacheRepository();
      final repo = CampaignAwareContentRepository(
        local: localRepo,
        campaign: campaignCache,
        activeCampaignId: () => null,
      );

      final entry = await repo.getByKey('local:example:location/moon-harbor');

      expect(entry, isNotNull);
      expect(entry!.origin, ContentOrigin.local);
      expect(entry.name, '月港');
    });

    test('getByKey returns campaign entry by campaign key', () async {
      final campaignEntry = testContentEntry(
        id: 'entry-1',
        campaignId: 'campaign-1',
        type: 'location',
        slug: 'moon-harbor',
        name: '月港',
      );
      final localRepo = MemoryContentRepository();
      final campaignCache = MemoryCampaignCacheRepository(
        entries: [campaignEntry],
      );
      final repo = CampaignAwareContentRepository(
        local: localRepo,
        campaign: campaignCache,
        activeCampaignId: () => 'campaign-1',
      );

      final entry =
          await repo.getByKey('campaign:campaign-1:entry-1');

      expect(entry, isNotNull);
      expect(entry!.origin, ContentOrigin.campaign);
      expect(entry.name, '月港');
    });

    test('getByKey returns null for unknown key', () async {
      final localRepo = MemoryContentRepository();
      final campaignCache = MemoryCampaignCacheRepository();
      final repo = CampaignAwareContentRepository(
        local: localRepo,
        campaign: campaignCache,
        activeCampaignId: () => 'campaign-1',
      );

      expect(await repo.getByKey('local:missing'), isNull);
      expect(await repo.getByKey('campaign:campaign-1:missing'), isNull);
    });

    test('watchPackages delegates to local repository only', () async {
      final localEntry = ContentEntry.fromJson({
        'id': 'example:location/moon-harbor',
        'type': 'location',
        'slug': 'moon-harbor',
        'name': '月港',
        'body': <Map<String, Object?>>[],
        'revision': 1,
      });
      final localRepo = MemoryContentRepository(initialEntries: [localEntry]);
      final campaignCache = MemoryCampaignCacheRepository();
      final repo = CampaignAwareContentRepository(
        local: localRepo,
        campaign: campaignCache,
        activeCampaignId: () => 'campaign-1',
      );

      final packages = await repo.watchPackages().first;

      // 战役条目不作为资料包出现，只读本地资料包列表。
      expect(packages, hasLength(1));
      expect(packages.single.id, 'example');
    });

    test('setFavorite and saveNote write through to local vault', () async {
      final localRepo = MemoryContentRepository();
      final campaignCache = MemoryCampaignCacheRepository(
        entries: [
          testContentEntry(
            id: 'entry-1',
            campaignId: 'campaign-1',
            name: '月港',
          ),
        ],
      );
      final repo = CampaignAwareContentRepository(
        local: localRepo,
        campaign: campaignCache,
        activeCampaignId: () => 'campaign-1',
      );

      await repo.setFavorite('campaign:campaign-1:entry-1', true);
      await repo.saveNote('campaign:campaign-1:entry-1', 'note');

      // 通过 favoritesOnly 查询验证收藏已写入本地 Vault。
      final favorites = await repo.search(const ContentQuery(favoritesOnly: true));
      expect(
        favorites.any((e) => e.id == 'campaign:campaign-1:entry-1'),
        isTrue,
      );
    });
  });
}
