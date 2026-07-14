import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local/campaign_cache_repository.dart';
import '../../data/sync/campaign_sync_api_client.dart';
import '../../domain/campaign_change.dart';

/// 战役资料条目管理状态。DM 可创建、编辑、删除独立 JSON 条目；所有操作通过
/// [CampaignSyncApiClient] 提交，成功后立即写本地缓存。列表从缓存读取，
/// 因此断网时仍可查阅。
class CampaignContentController extends ChangeNotifier {
  CampaignContentController({
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
  StreamSubscription<List<CampaignContentEntrySummary>>? _subscription;

  List<CampaignContentEntrySummary> _entries = [];
  String _query = '';
  String? _error;
  bool _loading = false;

  String? get selectedCampaignId => _selectedCampaignId;
  List<CampaignContentEntrySummary> get entries => _entries;
  String get query => _query;
  String? get error => _error;
  bool get isLoading => _loading;
  String get currentUserId => _currentUserId;

  /// 根据查询过滤后的条目列表。
  List<CampaignContentEntrySummary> get filteredEntries {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries.where((entry) {
      final name = entry.name.toLowerCase();
      final slug = entry.slug.toLowerCase();
      final type = entry.type.toLowerCase();
      return name.contains(query) || slug.contains(query) || type.contains(query);
    }).toList(growable: false);
  }

  Future<void> selectCampaign(String campaignId) async {
    if (_selectedCampaignId == campaignId) return;
    _selectedCampaignId = campaignId;
    _entries = [];
    _error = null;
    notifyListeners();
    await _subscription?.cancel();
    _subscription = _cacheRepository.watchContentEntries(campaignId).listen(
      (entries) {
        _entries = entries;
        notifyListeners();
      },
    );
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> createEntry({
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      _error = '请先选择战役';
      notifyListeners();
      return false;
    }
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final created = await _apiClient.createEntry(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        type: type,
        slug: slug,
        name: name,
        entry: entry,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(created, 'upsert'),
      );
      _loading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _loading = false;
      _error = '创建失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEntry({
    required String entryId,
    required int baseRevision,
    required Map<String, Object?> entry,
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return false;
    _error = null;
    try {
      final updated = await _apiClient.updateEntry(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        entryId: entryId,
        baseRevision: baseRevision,
        entry: entry,
      );
      await _cacheRepository.applyPage(
        campaignId,
        _singleChangePage(updated, 'upsert'),
      );
      return true;
    } catch (_) {
      _error = '更新失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEntry(String entryId) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) return false;
    _error = null;
    try {
      await _apiClient.deleteEntry(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        entryId: entryId,
      );
      await _cacheRepository.applyPage(
        campaignId,
        CampaignChangePage(
          items: [
            CampaignChange(
              id: 'delete-$entryId',
              campaignId: campaignId,
              cursor: '0',
              entityType: 'content',
              entityId: entryId,
              operation: 'delete',
              revision: 0,
              createdAt: DateTime.now().toUtc().toIso8601String(),
            ),
          ],
          nextCursor: '0',
          hasMore: false,
        ),
      );
      return true;
    } catch (_) {
      _error = '删除失败';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, Object?>> validateEntry({
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async {
    final campaignId = _selectedCampaignId;
    if (campaignId == null) {
      return {'valid': false, 'errors': ['未选择战役']};
    }
    try {
      return await _apiClient.validateEntry(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        campaignId: campaignId,
        type: type,
        slug: slug,
        name: name,
        entry: entry,
      );
    } catch (e) {
      return {'valid': false, 'errors': ['$e']};
    }
  }

  /// 解析 JSON 文本为条目列表，供导入预览使用。
  List<Map<String, Object?>> parseImportJson(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return [_normalizeEntryJson(decoded)];
      }
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(_normalizeEntryJson)
            .toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  Map<String, Object?> _normalizeEntryJson(Map raw) {
    final map = Map<String, Object?>.from(raw);
    return {
      'type': map['type']?.toString() ?? '',
      'slug': map['slug']?.toString() ?? '',
      'name': map['name']?.toString() ?? '',
      'entry': map['entry'] is Map
          ? Map<String, Object?>.from(map['entry'] as Map)
          : <String, Object?>{'body': <Map<String, Object?>>[]},
    };
  }

  CampaignChangePage _singleChangePage(
    CampaignContentEntrySummary entry,
    String operation,
  ) {
    return CampaignChangePage(
      items: [
        CampaignChange(
          id: 'local-${entry.id}-${entry.revision}',
          campaignId: entry.campaignId,
          cursor: '${entry.revision}',
          entityType: 'content',
          entityId: entry.id,
          operation: operation,
          revision: entry.revision,
          createdAt: entry.updatedAt,
          entity: entry.toJson(),
        ),
      ],
      nextCursor: '${entry.revision}',
      hasMore: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
