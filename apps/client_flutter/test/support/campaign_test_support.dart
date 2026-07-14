import 'dart:async';

import 'package:dnd_table_client/src/features/campaigns/data/local/campaign_cache_repository.dart';
import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_change.dart';

CampaignActor testCampaignActor({
  String id = 'actor-1',
  String campaignId = 'campaign-1',
  String? ownerUserId,
  String? sourceCharacterId,
  String actorType = 'player',
  String status = 'active',
  Map<String, Object?>? sheet,
  int revision = 1,
}) =>
    CampaignActor(
      id: id,
      campaignId: campaignId,
      ownerUserId: ownerUserId,
      sourceCharacterId: sourceCharacterId,
      actorType: actorType,
      status: status,
      sheet: sheet ?? {'name': 'Test Hero', 'currentHp': 10, 'maxHp': 20},
      revision: revision,
      updatedBy: 'user-1',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    );

CampaignContentEntrySummary testContentEntry({
  String id = 'entry-1',
  String campaignId = 'campaign-1',
  String type = 'location',
  String slug = 'moon-harbor',
  String name = '月港',
  Map<String, Object?>? entry,
  int revision = 1,
}) =>
    CampaignContentEntrySummary(
      id: id,
      campaignId: campaignId,
      type: type,
      slug: slug,
      name: name,
      entry: entry ?? {'body': <Map<String, Object?>>[]},
      revision: revision,
      createdBy: 'user-1',
      updatedBy: 'user-1',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
      deletedAt: null,
    );

class MemoryCampaignCacheRepository implements CampaignCacheRepository {
  MemoryCampaignCacheRepository({
    List<CampaignActor> actors = const [],
    List<CampaignContentEntrySummary> entries = const [],
    Map<String, String> cursors = const {},
  })  : _actors = {for (final a in actors) a.id: a},
        _entries = {for (final e in entries) e.id: e},
        _cursors = Map.of(cursors);

  final Map<String, CampaignActor> _actors;
  final Map<String, CampaignContentEntrySummary> _entries;
  final Map<String, String> _cursors;
  final StreamController<List<CampaignActor>> _controller =
      StreamController<List<CampaignActor>>.broadcast();

  List<CampaignActor> get actors => _actors.values.toList(growable: false);
  List<CampaignContentEntrySummary> get entries =>
      _entries.values.toList(growable: false);

  void _emit(String campaignId) {
    _controller.add(
      _actors.values
          .where((actor) => actor.campaignId == campaignId)
          .toList(growable: false),
    );
  }

  @override
  Stream<List<CampaignActor>> watchActors(String campaignId) {
    final controller = StreamController<List<CampaignActor>>.broadcast();
    scheduleMicrotask(() => controller.add(_actors.values
        .where((actor) => actor.campaignId == campaignId)
        .toList(growable: false)));
    _controller.stream.listen(controller.add);
    return controller.stream;
  }

  @override
  Future<CampaignActor?> getActor(String campaignId, String actorId) async {
    final actor = _actors[actorId];
    if (actor == null || actor.campaignId != campaignId) return null;
    return actor;
  }

  @override
  Future<CampaignContentEntrySummary?> getContentEntry(
    String campaignId,
    String entryId,
  ) async {
    final entry = _entries[entryId];
    if (entry == null || entry.campaignId != campaignId) return null;
    return entry;
  }

  @override
  Future<String> cursorFor(String campaignId) async =>
      _cursors[campaignId] ?? '0';

  @override
  Future<void> applyPage(String campaignId, CampaignChangePage page) async {
    for (final change in page.items) {
      if (change.entityType == 'actor') {
        if (change.operation == 'upsert' && change.entity != null) {
          final actor = CampaignActor.fromJson(change.entity!);
          _actors[actor.id] = actor;
        } else if (change.operation == 'delete') {
          _actors.remove(change.entityId);
        }
      } else if (change.entityType == 'content') {
        if (change.operation == 'upsert' && change.entity != null) {
          final entry = CampaignContentEntrySummary.fromJson(change.entity!);
          _entries[entry.id] = entry;
        } else if (change.operation == 'delete') {
          _entries.remove(change.entityId);
        }
      }
    }
    _cursors[campaignId] = page.nextCursor;
    _emit(campaignId);
  }

  @override
  Future<void> clearCampaign(String campaignId) async {
    _actors.removeWhere((_, actor) => actor.campaignId == campaignId);
    _entries.removeWhere((_, entry) => entry.campaignId == campaignId);
    _cursors.remove(campaignId);
    _emit(campaignId);
  }
}

class MemoryCampaignSyncApiClient implements CampaignSyncApiClient {
  MemoryCampaignSyncApiClient({
    List<CampaignChangePage> changePages = const [],
    this.listChangesException,
  }) : _changePages = List.of(changePages);

  final List<CampaignChangePage> _changePages;
  int _changePageIndex = 0;
  final Object? listChangesException;

  final List<Map<String, Object?>> publishCalls = [];
  final List<Map<String, Object?>> createActorCalls = [];
  final List<Map<String, Object?>> updateActorCalls = [];
  final List<Map<String, Object?>> archiveCalls = [];
  final List<Map<String, Object?>> createEntryCalls = [];
  final List<Map<String, Object?>> updateEntryCalls = [];
  final List<String> deleteEntryCalls = [];

  @override
  Future<CampaignChangePage> listChanges({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String cursor,
    int? limit,
  }) async {
    if (listChangesException != null) throw listChangesException!;
    if (_changePageIndex < _changePages.length) {
      return _changePages[_changePageIndex++];
    }
    return const CampaignChangePage(items: [], nextCursor: '0', hasMore: false);
  }

  @override
  Future<CampaignActor> publishActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String sourceCharacterId,
    required String actorType,
    required int baseRevision,
    required Map<String, Object?> sheet,
  }) async {
    publishCalls.add({
      'campaignId': campaignId,
      'sourceCharacterId': sourceCharacterId,
      'actorType': actorType,
      'baseRevision': baseRevision,
      'sheet': sheet,
    });
    return testCampaignActor(
      campaignId: campaignId,
      sourceCharacterId: sourceCharacterId,
      actorType: actorType,
      sheet: sheet,
    );
  }

  @override
  Future<CampaignActor> createActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorType,
    String? ownerUserId,
    required Map<String, Object?> sheet,
  }) async {
    createActorCalls.add({
      'campaignId': campaignId,
      'actorType': actorType,
      'ownerUserId': ownerUserId,
      'sheet': sheet,
    });
    return testCampaignActor(
      campaignId: campaignId,
      actorType: actorType,
      ownerUserId: ownerUserId,
      sheet: sheet,
    );
  }

  @override
  Future<List<CampaignActor>> listActors({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async =>
      [testCampaignActor(campaignId: campaignId)];

  @override
  Future<CampaignActor> getActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
  }) async =>
      testCampaignActor(id: actorId, campaignId: campaignId);

  @override
  Future<CampaignActor> updateActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
    required int baseRevision,
    required Map<String, Object?> sheet,
  }) async {
    updateActorCalls.add({
      'campaignId': campaignId,
      'actorId': actorId,
      'baseRevision': baseRevision,
      'sheet': sheet,
    });
    return testCampaignActor(id: actorId, campaignId: campaignId, sheet: sheet);
  }

  @override
  Future<CampaignActor> archiveActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
    required int baseRevision,
  }) async {
    archiveCalls.add({
      'campaignId': campaignId,
      'actorId': actorId,
      'baseRevision': baseRevision,
    });
    return testCampaignActor(
      id: actorId,
      campaignId: campaignId,
      status: 'archived',
    );
  }

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
    createEntryCalls.add({
      'campaignId': campaignId,
      'type': type,
      'slug': slug,
      'name': name,
      'entry': entry,
    });
    return testContentEntry(
      campaignId: campaignId,
      type: type,
      slug: slug,
      name: name,
      entry: entry,
    );
  }

  @override
  Future<CampaignContentEntrySummary> updateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    required int baseRevision,
    required Map<String, Object?> entry,
  }) async {
    updateEntryCalls.add({
      'campaignId': campaignId,
      'entryId': entryId,
      'baseRevision': baseRevision,
      'entry': entry,
    });
    return testContentEntry(
      id: entryId,
      campaignId: campaignId,
      entry: entry,
    );
  }

  @override
  Future<void> deleteEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) async {
    deleteEntryCalls.add(entryId);
  }

  @override
  Future<Map<String, Object?>> validateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async =>
      {'valid': true, 'errors': <String>[]};
}
