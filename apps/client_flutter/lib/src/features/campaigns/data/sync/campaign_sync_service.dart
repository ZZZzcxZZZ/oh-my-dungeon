import '../../domain/campaign_actor.dart';
import '../local/campaign_cache_repository.dart';
import 'campaign_actor_backlink_service.dart';
import 'campaign_sync_api_client.dart';

/// 拉取循环的结果。驱动 UI 状态：暂停（401）、吊销（403）、错误、空闲。
enum CampaignSyncResult { idle, paused, revoked, error }

/// 战役变更拉取服务。循环请求 changes 直到 hasMore=false，应用到本地缓存，
/// 并把当前用户拥有的 Actor 回写到本地角色。
class CampaignSyncService {
  CampaignSyncService({
    required this.cacheRepository,
    required this.apiClient,
    required this.backlinkService,
  });

  final CampaignCacheRepository cacheRepository;
  final CampaignSyncApiClient apiClient;
  final CampaignActorBacklinkService backlinkService;

  Future<CampaignSyncResult> pullUntilCurrent({
    required String apiBaseUrl,
    required String accessToken,
    required String deviceId,
    required String campaignId,
    required String userId,
  }) async {
    try {
      var cursor = await cacheRepository.cursorFor(campaignId);
      while (true) {
        final page = await apiClient.listChanges(
          apiBaseUrl: apiBaseUrl,
          accessToken: accessToken,
          campaignId: campaignId,
          cursor: cursor,
        );
        await cacheRepository.applyPage(campaignId, page);
        // 应用后，把当前用户拥有且带 sourceCharacterId 的 Actor 回写本地角色。
        for (final change in page.items) {
          if (change.entityType == 'actor' &&
              change.operation == 'upsert' &&
              change.entity != null) {
            final actor = CampaignActor.fromJson(change.entity!);
            if (actor.ownerUserId == userId &&
                actor.sourceCharacterId != null) {
              await backlinkService.applyActorToCharacter(actor);
            }
          }
        }
        cursor = page.nextCursor;
        if (!page.hasMore) break;
      }
      return CampaignSyncResult.idle;
    } on CampaignSyncException catch (e) {
      if (e.statusCode == 401) return CampaignSyncResult.paused;
      if (e.statusCode == 403) return CampaignSyncResult.revoked;
      return CampaignSyncResult.error;
    } catch (_) {
      return CampaignSyncResult.error;
    }
  }
}
