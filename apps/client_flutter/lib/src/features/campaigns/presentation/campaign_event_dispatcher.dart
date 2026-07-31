import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/sync/campaign_sync_api_client.dart';
import '../domain/campaign_event.dart';

/// Task 3.1 — CampaignEvent 统一发送入口.
///
/// 把 CampaignEvent 原子操作 (HP 变化、给予物品等) 封装为单一调度器,
/// 让 DM 控场 Sheet (Task 3.4) 和角色卡 CampaignActionSink (Task 3.3)
/// 都通过这个入口发送事件. 调用成功后:
///   1. 服务端已原子完成状态修改 + 事件追加 + 聊天广播
///   2. 调用方可通过 [onEventDispatched] 回调把事件追加到本地聊天缓存
///   3. 调用方可通过 [onCharacterChanged] 回调刷新本地 character 缓存
///
/// 离线时调用方自行决定是否忽略错误或展示 SnackBar.
class CampaignEventDispatcher extends ChangeNotifier {
  CampaignEventDispatcher({
    required CampaignSyncApiClient apiClient,
    required String Function() apiBaseUrlProvider,
    required String Function() accessTokenProvider,
    Future<void> Function(CampaignEvent event)? onEventDispatched,
    Future<void> Function(Map<String, Object?> characterSummary)?
    onCharacterChanged,
  }) : _apiClient = apiClient,
       _apiBaseUrlProvider = apiBaseUrlProvider,
       _accessTokenProvider = accessTokenProvider,
       _onEventDispatched = onEventDispatched,
       _onCharacterChanged = onCharacterChanged;

  final CampaignSyncApiClient _apiClient;
  final String Function() _apiBaseUrlProvider;
  final String Function() _accessTokenProvider;
  final Future<void> Function(CampaignEvent event)? _onEventDispatched;
  final Future<void> Function(Map<String, Object?> characterSummary)?
  _onCharacterChanged;

  bool _dispatching = false;
  String? _lastError;

  bool get isDispatching => _dispatching;
  String? get lastError => _lastError;

  /// 调整 character HP. delta < 0 为伤害, > 0 为治疗.
  /// 返回更新后的 character revision, 失败时抛 [CampaignSyncException]
  /// 或 [CampaignConflictException].
  Future<int> changeCharacterHp({
    required String campaignId,
    required String characterId,
    required int delta,
    String? reason,
    int? baseRevision,
  }) async {
    return _dispatch(
      () => _apiClient.changeCharacterHp(
        apiBaseUrl: _apiBaseUrlProvider(),
        accessToken: _accessTokenProvider(),
        campaignId: campaignId,
        characterId: characterId,
        delta: delta,
        reason: reason,
        baseRevision: baseRevision,
      ),
    );
  }

  /// 给予 character 物品. quantity 默认 1, 必须为正整数.
  Future<int> grantItem({
    required String campaignId,
    required String characterId,
    required String itemId,
    required String name,
    int quantity = 1,
    int? baseRevision,
  }) async {
    return _dispatch(
      () => _apiClient.grantItem(
        apiBaseUrl: _apiBaseUrlProvider(),
        accessToken: _accessTokenProvider(),
        campaignId: campaignId,
        characterId: characterId,
        itemId: itemId,
        name: name,
        quantity: quantity,
        baseRevision: baseRevision,
      ),
    );
  }

  /// 给予 character 一个结构化状态，可选按轮记录持续时间。
  Future<int> addCondition({
    required String campaignId,
    required String characterId,
    required String type,
    required String name,
    int? durationRounds,
    int? baseRevision,
  }) async {
    return _dispatch(
      () => _apiClient.addCondition(
        apiBaseUrl: _apiBaseUrlProvider(),
        accessToken: _accessTokenProvider(),
        campaignId: campaignId,
        characterId: characterId,
        type: type,
        name: name,
        durationRounds: durationRounds,
        baseRevision: baseRevision,
      ),
    );
  }

  Future<int> _dispatch(Future<CampaignEventResult> Function() action) async {
    _setError(null);
    _setDispatching(true);
    try {
      final result = await action();
      // 先刷新 character 缓存, 再追加事件消息, 保证 UI 顺序一致.
      if (_onCharacterChanged != null) {
        await _onCharacterChanged(result.character);
      }
      if (_onEventDispatched != null) {
        await _onEventDispatched(result.event);
      }
      final revisionValue = result.character['revision'];
      return revisionValue is num ? revisionValue.toInt() : 0;
    } catch (error) {
      _setError(error.toString());
      rethrow;
    } finally {
      _setDispatching(false);
    }
  }

  void _setDispatching(bool value) {
    if (_dispatching == value) return;
    _dispatching = value;
    notifyListeners();
  }

  void _setError(String? message) {
    if (_lastError == message) return;
    _lastError = message;
    notifyListeners();
  }
}
