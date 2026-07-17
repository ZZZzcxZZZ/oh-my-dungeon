import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/campaign_cache_repository.dart';
import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_actor.dart';
import '../../domain/campaign_actor_audit.dart';
import '../../domain/campaign_change.dart';
import '../../../characters/domain/character.dart';

/// Human-readable error string for a [CampaignSyncException] with status code.
String _describeSyncException(CampaignSyncException exception) {
  switch (exception.statusCode) {
    case 400:
      return '请求无效：${exception.message}';
    case 401:
      return '登录已过期，请重新登录';
    case 403:
      return '无权执行此操作：${exception.message}';
    case 404:
      return '资源不存在：${exception.message}';
    case 409:
      return '数据已被其他端修改，请刷新后重试';
    default:
      return exception.message;
  }
}

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
    String Function()? accessTokenProvider,
    String Function()? currentUserIdProvider,
  }) : _cacheRepository = cacheRepository,
       _apiClient = apiClient,
       _apiBaseUrl = apiBaseUrl,
       _initialAccessToken = accessToken,
       _initialCurrentUserId = currentUserId,
       _accessTokenProvider = accessTokenProvider,
       _currentUserIdProvider = currentUserIdProvider;

  final CampaignCacheRepository _cacheRepository;
  final CampaignSyncApiClient _apiClient;
  final String _apiBaseUrl;
  final String _initialAccessToken;
  final String _initialCurrentUserId;
  final String Function()? _accessTokenProvider;
  final String Function()? _currentUserIdProvider;

  String get _accessToken =>
      _accessTokenProvider?.call() ?? _initialAccessToken;
  String get _currentUserId =>
      _currentUserIdProvider?.call() ?? _initialCurrentUserId;

  String? _selectedCampaignId;
  StreamSubscription<List<CampaignActor>>? _subscription;

  List<CampaignActor> _actors = [];
  String _query = '';
  final Set<String> _activeFilters = {'player', 'npc', 'unclaimed'};
  bool _loading = false;
  String? _error;
  CampaignConflictException? _conflict;
  final Map<String, List<CampaignActorAudit>> _audits = {};
  final Set<String> _loadingAudits = {};
  final Map<String, String> _auditErrors = {};

  String? get selectedCampaignId => _selectedCampaignId;
  List<CampaignActor> get actors => _actors;
  String get query => _query;
  Set<String> get activeFilters => Set.unmodifiable(_activeFilters);
  bool get isLoading => _loading;
  String? get error => _error;
  CampaignConflictException? get conflict => _conflict;
  String get currentUserId => _currentUserId;
  List<CampaignActorAudit> auditsFor(String actorId) =>
      List.unmodifiable(_audits[actorId] ?? const []);
  bool isLoadingAudits(String actorId) => _loadingAudits.contains(actorId);
  String? auditErrorFor(String actorId) => _auditErrors[actorId];

  /// 根据当前查询和筛选条件过滤后的角色列表。
  List<CampaignActor> get filteredActors {
    final query = _query.trim().toLowerCase();
    return _actors
        .where((actor) {
          if (!_matchesFilters(actor)) return false;
          if (query.isEmpty) return true;
          final name = actor.sheet['name']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        })
        .toList(growable: false);
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
    _audits.clear();
    _loadingAudits.clear();
    _auditErrors.clear();
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

  Future<void> loadActorAudits(String actorId) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null || _loadingAudits.contains(actorId)) return;
    _loadingAudits.add(actorId);
    _auditErrors.remove(actorId);
    notifyListeners();
    try {
      _audits[actorId] = await _apiClient.listActorAudits(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        actorId: actorId,
      );
    } catch (_) {
      _auditErrors[actorId] = '加载编辑历史失败';
    }
    _loadingAudits.remove(actorId);
    notifyListeners();
  }

  Future<bool> publishCharacter(
    CharacterSheet character, {
    String actorType = 'player',
    Map<String, Object?>? sheetOverride,
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
        sheet: sheetOverride ?? character.toJson(),
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
    } on CampaignSyncException catch (e) {
      _error = _describeSyncException(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = '发布角色失败：网络错误，请检查服务器连接';
      notifyListeners();
      return false;
    }
  }

  /// DM 创建常驻 NPC / 怪物 / 同伴角色。
  ///
  /// 走 `/actors`（DM create）端点，不走 `/actors/publish`（玩家自发布）。
  /// 服务端会校验调用者拥有 `canManageCampaign` 能力，并拒绝 `actorType ==
  /// 'player'`（玩家角色必须自发布）。
  ///
  /// 见 spec §发言身份 DM 与 §DM角色生命周期：常驻角色 lifecycle=persistent。
  Future<bool> createDmActor({
    required String actorType,
    required Map<String, Object?> sheet,
    String lifecycle = 'persistent',
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      _error = '请先选择战役';
      notifyListeners();
      return false;
    }
    if (actorType == 'player') {
      _error = '玩家角色请使用发布到战役功能';
      notifyListeners();
      return false;
    }
    _error = null;
    try {
      final created = await _apiClient.createActor(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        actorType: actorType,
        lifecycle: lifecycle,
        sheet: sheet,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(created, 'upsert'),
      );
      return true;
    } on CampaignConflictException catch (e) {
      _conflict = e;
      notifyListeners();
      return false;
    } on CampaignSyncException catch (e) {
      _error = _describeSyncException(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = '创建角色失败：网络错误，请检查服务器连接';
      notifyListeners();
      return false;
    }
  }

  /// Creates a throwaway DM persona with enough state to be used in chat and
  /// later added to an encounter without opening the full character editor.
  Future<bool> createTemporaryNpc({
    required String name,
    int maxHp = 1,
  }) async {
    final campaignId = _selectedCampaignId;
    final normalizedName = name.trim();
    if (campaignId == null || normalizedName.isEmpty) return false;

    _error = null;
    try {
      final hp = maxHp < 0 ? 0 : maxHp;
      final created = await _apiClient.createActor(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        actorType: 'npc',
        lifecycle: 'temporary',
        sheet: {'name': normalizedName, 'currentHp': hp, 'maxHp': hp},
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(created, 'upsert'),
      );
      return true;
    } on CampaignConflictException catch (error) {
      _conflict = error;
      notifyListeners();
      return false;
    } on CampaignSyncException catch (e) {
      _error = _describeSyncException(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = '创建临时角色失败：网络错误，请检查服务器连接';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateActor(
    CampaignActor actor,
    Map<String, Object?> sheet,
  ) async {
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
      await loadActorAudits(actor.id);
      return true;
    } on CampaignConflictException catch (e) {
      _conflict = e;
      notifyListeners();
      return false;
    } on CampaignSyncException catch (e) {
      _error = _describeSyncException(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = '保存角色失败：网络错误，请检查服务器连接';
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
    } on CampaignSyncException catch (e) {
      _error = _describeSyncException(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = '归档角色失败：网络错误，请检查服务器连接';
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
