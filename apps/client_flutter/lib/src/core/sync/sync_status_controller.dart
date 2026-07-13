import 'package:flutter/foundation.dart';

import 'sync_models.dart';

/// 面向 UI 的同步状态。监听 Outbox 数量与同步阶段刷新展示。
class SyncStatusController extends ChangeNotifier {
  SyncStatusController();

  SyncPhase _phase = SyncPhase.offline;
  int _pendingCount = 0;
  String? _lastError;

  SyncPhase get phase => _phase;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;

  void setPhase(SyncPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (phase != SyncPhase.error) _lastError = null;
    notifyListeners();
  }

  void setPendingCount(int count) {
    if (_pendingCount == count) return;
    _pendingCount = count;
    notifyListeners();
  }

  void setError(String? error) {
    _lastError = error;
    _phase = error == null ? _phase : SyncPhase.error;
    notifyListeners();
  }

  Future<void> refresh(Future<int> Function() countProvider) async {
    final count = await countProvider();
    setPendingCount(count);
  }
}
