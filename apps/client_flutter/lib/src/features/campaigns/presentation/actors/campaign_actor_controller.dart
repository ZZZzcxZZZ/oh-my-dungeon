import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/campaign_cache_repository.dart';
import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_actor.dart';
import '../../domain/campaign_change.dart';
import '../../../characters/domain/character.dart';

/// 战役角色管理状态。Player 模式用于发布本地角色到战役；DM 模式用于浏览、
/// 编辑、归档所有 CampaignActor。所有写操作通过 [CampaignSyncApiClient] 提交，
/// 成功后立即写本地缓存以避免 UI 等待拉取循环。
class CampaignActorController extends ChangeNotifier {
  CampaignActorController({
    required CampaignCacheRepository cacheRepository,
    required CampaignSyncApiClient apiClient,
    required String apiBaseUrl,
    required String accessToken,
    required String currentUserId,
  })  : _cacheRepository = cacheRepository,
        _apiClient = apiClient,
        _apiBaseUrl = apiBaseUrl,
        _accessToken = accessToken,
        _currentUserId = currentUserId;

  final CampaignCacheRepository _cacheRepository;
  final CampaignSyncApiClient _apiClient;
  final String _apiBaseUrl;
  final String _accessToken;
  final String _currentUserId;

  String? _selectedCampaignId;
  StreamSubscription<List<CampaignActor>>? _subscription;

  List<CampaignActor> _actors = [];
  String _query = '';
  final Set<String> _activeFilters = {'player', 'npc', 'unclaimed'};
  bool _loading = false;
  String? _error;
  CampaignConflictException? _conflict;

  String? get selectedCampaignId => _selectedCampaignId;
  List<CampaignActor> get actors => _actors;
  String get query => _query;
  Set<String> get activeFilters => Set.unmodifiable(_activeFilters);
  bool get isLoading => _loading;
  String? get error => _error;
  CampaignConflictException? get conflict => _conflict;
  String get currentUserId => _currentUserId;

  /// 根据当前查询和筛选条件过滤后的角色列表。
  List<CampaignActor> get filteredActors {
    final query = _query.trim().toLowerCase();
    return _actors.where((actor) {
      if (!_matchesFilters(actor)) return false;
      if (query.isEmpty) return true;
      final name = actor.sheet['name']?.toString().toLowerCase() ?? '';
      return name.contains(query);
    }).toList(growable: false);
  }

  bool _matchesFilters(CampaignActor actor) {
    if (_activeFilters.contains('archived') && _activeFilters.length == 1) {
      return actor.status == 'archived';
    }
    if (actor.status == 'archived') return _activeFilters.contains('archived');
    if (_activeFilters.contains('unclaimed') &&
        actor.ownerUserId == null &&
        actor.actorType != 'npc') {
      return true;
    }
    if (_activeFilters.contains('player') && actor.actorType == 'player') {
      return true;
    }
    if (_activeFilters.contains('npc') && actor.actorType == 'npc') {
      return true;
    }
    return false;
  }

  Future<void> selectCampaign(String campaignId) async {
    if (_selectedCampaignId == campaignId) return;
    _selectedCampaignId = campaignId;
    _actors = [];
    _error = null;
    notifyListeners();
    await _subscription?.cancel();
    _subscription = _cacheRepository.watchActors(campaignId).listen((actors) {
      _actors = actors;
      notifyListeners();
    });
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void toggleFilter(String filter) {
    if (_activeFilters.contains(filter)) {
      // 不能移除最后一个筛选，避免空集。
      if (_activeFilters.length == 1) return;
      _activeFilters.remove(filter);
    } else {
      // 选中 archived 时清空其他筛选，因为 archived 是互斥视图。
      if (filter == 'archived') {
        _activeFilters
          ..clear()
          ..add('archived');
      } else {
        // 选中其他筛选时移除 archived。
        _activeFilters.remove('archived');
        _activeFilters.add(filter);
      }
    }
    notifyListeners();
  }

  void clearConflict() {
    if (_conflict == null) return;
    _conflict = null;
    notifyListeners();
  }

  Future<void> pullUntilCurrent() async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      var cursor = await _cacheRepository.cursorFor(campaignId);
      while (true) {
        final page = await _apiClient.listChanges(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          campaignId: campaignId,
          cursor: cursor,
        );
        await _cacheRepository.applyPage(campaignId, page);
        cursor = page.nextCursor;
        if (!page.hasMore) break;
      }
    } catch (e) {
      _error = '拉取战役变更失败';
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> publishCharacter(
    CharacterSheet character, {
    String actorType = 'player',
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      _error = '请先选择战役';
      notifyListeners();
      return false;
    }
    _error = null;
    try {
      final actor = await _apiClient.publishActor(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        sourceCharacterId: character.id,
        actorType: actorType,
        baseRevision: 0,
        sheet: character.toJson(),
      );
      // 立即写本地缓存，避免等待拉取循环。
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(actor, 'upsert'),
      );
      return true;
    } on CampaignConflictException catch (e) {
      _conflict = e;
      notifyListeners();
      return false;
    } catch (_) {
      _error = '发布角色失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateActor(CampaignActor actor, Map<String, Object?> sheet) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return false;
    _error = null;
    _conflict = null;
    try {
      final updated = await _apiClient.updateActor(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        actorId: actor.id,
        baseRevision: actor.revision,
        sheet: sheet,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(updated, 'upsert'),
      );
      return true;
    } on CampaignConflictException catch (e) {
      _conflict = e;
      notifyListeners();
      return false;
    } catch (_) {
      _error = '保存角色失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> archiveActor(CampaignActor actor) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return false;
    _error = null;
    _conflict = null;
    try {
      final archived = await _apiClient.archiveActor(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        actorId: actor.id,
        baseRevision: actor.revision,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(archived, 'upsert'),
      );
      return true;
    } on CampaignConflictException catch (e) {
      _conflict = e;
      notifyListeners();
      return false;
    } catch (_) {
      _error = '归档角色失败';
      notifyListeners();
      return false;
    }
  }

  /// 构造一个仅包含单个 actor 变更的页面，用于写本地缓存。
  CampaignChangePage _singleChangePage(CampaignActor actor, String operation) {
    return CampaignChangePage(
      items: [
        CampaignChange(
          id: 'local-${actor.id}-${actor.revision}',
          campaignId: actor.campaignId,
          cursor: '${actor.revision}',
          entityType: 'actor',
          entityId: actor.id,
          operation: operation,
          revision: actor.revision,
          createdAt: actor.updatedAt,
          entity: actor.toJson(),
        ),
      ],
      nextCursor: '${actor.revision}',
      hasMore: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
