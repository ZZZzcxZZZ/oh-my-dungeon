import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/campaign_cache_repository.dart';
import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_character.dart';
import '../../domain/campaign_character_audit.dart';
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
/// 编辑、归档所有 CampaignCharacter。所有写操作通过 [CampaignSyncApiClient] 提交，
/// 成功后立即写本地缓存以避免 UI 等待拉取循环。
class CampaignCharacterController extends ChangeNotifier {
  CampaignCharacterController({
    required CampaignCacheRepository cacheRepository,
    required CampaignSyncApiClient apiClient,
    required String apiBaseUrl,
    required String accessToken,
    required String currentUserId,
    String Function()? accessTokenProvider,
    String Function()? currentUserIdProvider,
    Future<void> Function(CampaignCharacter character)? onCharacterPublished,
  }) : _cacheRepository = cacheRepository,
       _apiClient = apiClient,
       _apiBaseUrl = apiBaseUrl,
       _initialAccessToken = accessToken,
       _initialCurrentUserId = currentUserId,
       _accessTokenProvider = accessTokenProvider,
       _currentUserIdProvider = currentUserIdProvider,
       _onCharacterPublished = onCharacterPublished;

  final CampaignCacheRepository _cacheRepository;
  final CampaignSyncApiClient _apiClient;
  final String _apiBaseUrl;
  final String _initialAccessToken;
  final String _initialCurrentUserId;
  final String Function()? _accessTokenProvider;
  final String Function()? _currentUserIdProvider;
  final Future<void> Function(CampaignCharacter character)?
  _onCharacterPublished;

  String get _accessToken =>
      _accessTokenProvider?.call() ?? _initialAccessToken;
  String get _currentUserId =>
      _currentUserIdProvider?.call() ?? _initialCurrentUserId;

  String? _selectedCampaignId;
  StreamSubscription<List<CampaignCharacter>>? _subscription;

  List<CampaignCharacter> _characters = [];
  String _query = '';
  final Set<String> _activeFilters = {'player', 'npc', 'unclaimed'};
  bool _loading = false;
  String? _error;
  CampaignConflictException? _conflict;
  final Map<String, List<CampaignCharacterAudit>> _audits = {};
  final Set<String> _loadingAudits = {};
  final Map<String, String> _auditErrors = {};

  String? get selectedCampaignId => _selectedCampaignId;
  List<CampaignCharacter> get characters => _characters;
  String get query => _query;
  Set<String> get activeFilters => Set.unmodifiable(_activeFilters);
  bool get isLoading => _loading;
  String? get error => _error;
  CampaignConflictException? get conflict => _conflict;
  String get currentUserId => _currentUserId;
  List<CampaignCharacterAudit> auditsFor(String characterId) =>
      List.unmodifiable(_audits[characterId] ?? const []);
  bool isLoadingAudits(String characterId) =>
      _loadingAudits.contains(characterId);
  String? auditErrorFor(String characterId) => _auditErrors[characterId];

  /// 根据当前查询和筛选条件过滤后的角色列表。
  List<CampaignCharacter> get filteredCharacters {
    final query = _query.trim().toLowerCase();
    return _characters
        .where((character) {
          if (!_matchesFilters(character)) return false;
          if (query.isEmpty) return true;
          final name = character.sheet['name']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        })
        .toList(growable: false);
  }

  bool _matchesFilters(CampaignCharacter character) {
    if (_activeFilters.contains('archived') && _activeFilters.length == 1) {
      return character.status == 'archived';
    }
    if (character.status == 'archived') {
      return _activeFilters.contains('archived');
    }
    if (_activeFilters.contains('unclaimed') &&
        character.ownerUserId == null &&
        character.characterType != 'npc') {
      return true;
    }
    if (_activeFilters.contains('player') &&
        character.characterType == 'player') {
      return true;
    }
    if (_activeFilters.contains('npc') && character.characterType == 'npc') {
      return true;
    }
    return false;
  }

  Future<void> selectCampaign(String campaignId) async {
    if (_selectedCampaignId == campaignId) return;
    _selectedCampaignId = campaignId;
    _characters = [];
    _audits.clear();
    _loadingAudits.clear();
    _auditErrors.clear();
    _error = null;
    notifyListeners();
    await _subscription?.cancel();
    _subscription = _cacheRepository.watchCharacters(campaignId).listen((
      characters,
    ) {
      _characters = characters;
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

  Future<void> loadCharacterAudits(String characterId) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null || _loadingAudits.contains(characterId)) return;
    _loadingAudits.add(characterId);
    _auditErrors.remove(characterId);
    notifyListeners();
    try {
      _audits[characterId] = await _apiClient.listCharacterAudits(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        characterId: characterId,
      );
    } catch (_) {
      _auditErrors[characterId] = '加载编辑历史失败';
    }
    _loadingAudits.remove(characterId);
    notifyListeners();
  }

  Future<bool> publishCharacter(
    CharacterSheet character, {
    String characterType = 'player',
    Map<String, Object?>? sheetOverride,
    int? baseRevisionOverride,
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      _error = '请先选择战役';
      notifyListeners();
      return false;
    }
    _error = null;
    _conflict = null;
    // Spec §双向同步 切片 A: 重发布必须用本地缓存的 character.revision 作
    // baseRevision，否则服务端必然 409。首次发布本地无 character，传 0。
    // baseRevisionOverride 用于冲突解决"用本地覆盖"时传入服务端最新 revision。
    final existing = _characters.cast<CampaignCharacter?>().firstWhere(
      (a) => a?.sourceCharacterId == character.id,
      orElse: () => null,
    );
    final baseRevision = baseRevisionOverride ?? existing?.revision ?? 0;
    try {
      final campaignCharacter = await _apiClient.publishCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        sourceCharacterId: character.id,
        characterType: characterType,
        baseRevision: baseRevision,
        sheet: sheetOverride ?? character.toJson(),
      );
      // 立即写本地缓存，避免等待拉取循环。
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(campaignCharacter, 'upsert'),
      );
      _upsertCharacter(campaignCharacter);
      // 立即把远端 character 回写本地角色，避免等下次 pullUntilCurrent 才同步
      // 运行时字段。backlinkService 可能为 null（web build 无 database）。
      final callback = _onCharacterPublished;
      if (callback != null) {
        await callback(campaignCharacter);
      }
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
  /// 走 `/characters`（DM create）端点，不走 `/characters/publish`（玩家自发布）。
  /// 服务端会校验调用者拥有 `canManageCampaign` 能力，并拒绝 `characterType ==
  /// 'player'`（玩家角色必须自发布）。
  ///
  /// 见 spec §发言身份 DM 与 §DM角色生命周期：常驻角色 lifecycle=persistent。
  Future<bool> createDmCharacter({
    required String characterType,
    required Map<String, Object?> sheet,
    String lifecycle = 'persistent',
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      _error = '请先选择战役';
      notifyListeners();
      return false;
    }
    if (characterType == 'player') {
      _error = '玩家角色请使用发布到战役功能';
      notifyListeners();
      return false;
    }
    _error = null;
    try {
      final created = await _apiClient.createCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        characterType: characterType,
        lifecycle: lifecycle,
        sheet: sheet,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(created, 'upsert'),
      );
      _upsertCharacter(created);
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

  Future<bool> updateCharacter(
    CampaignCharacter character,
    Map<String, Object?> sheet, {
    String? lifecycle,
    bool? visibleToPlayers,
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return false;
    _error = null;
    _conflict = null;
    try {
      final updated = await _apiClient.updateCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        characterId: character.id,
        baseRevision: character.revision,
        sheet: sheet,
        lifecycle: lifecycle,
        visibleToPlayers: visibleToPlayers,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(updated, 'upsert'),
      );
      _upsertCharacter(updated);
      await loadCharacterAudits(character.id);
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

  Future<bool> archiveCharacter(CampaignCharacter character) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return false;
    _error = null;
    _conflict = null;
    try {
      final archived = await _apiClient.archiveCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        characterId: character.id,
        baseRevision: character.revision,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(archived, 'upsert'),
      );
      _upsertCharacter(archived);
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

  Future<bool> restoreCharacter(CampaignCharacter character) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return false;
    _error = null;
    _conflict = null;
    try {
      final restored = await _apiClient.restoreCharacter(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        characterId: character.id,
        baseRevision: character.revision,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(restored, 'upsert'),
      );
      _upsertCharacter(restored);
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
      _error = '恢复角色失败：网络错误，请检查服务器连接';
      notifyListeners();
      return false;
    }
  }

  /// 构造一个仅包含单个 character 变更的页面，用于写本地缓存。
  void _upsertCharacter(CampaignCharacter character) {
    final index = _characters.indexWhere(
      (candidate) => candidate.id == character.id,
    );
    if (index < 0) {
      _characters = [..._characters, character];
    } else {
      _characters = [..._characters]..[index] = character;
    }
    notifyListeners();
  }

  CampaignChangePage _singleChangePage(
    CampaignCharacter character,
    String operation,
  ) {
    return CampaignChangePage(
      items: [
        CampaignChange(
          id: 'local-${character.id}-${character.revision}',
          campaignId: character.campaignId,
          cursor: '${character.revision}',
          entityType: 'character',
          entityId: character.id,
          operation: operation,
          revision: character.revision,
          createdAt: character.updatedAt,
          entity: character.toJson(),
        ),
      ],
      nextCursor: '${character.revision}',
      hasMore: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
