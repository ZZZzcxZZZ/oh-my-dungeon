import 'package:flutter/foundation.dart';

import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_repository.dart';
import '../data/vault_api_client.dart';
import '../data/vault_sync_service.dart';
import '../domain/vault_models.dart';

/// 面向设置页的个人 Vault 同步契约。
///
/// 继承 [ChangeNotifier] 以便 widget 通过 [Listenable] 监听刷新。实现方负责
/// 在状态变化时调用 [notifyListeners]。错误信息只暴露简短文本，不得包含
/// access token 或实体全文。
abstract class VaultSyncActions extends ChangeNotifier {
  int get pendingCount;
  SyncPhase get phase;
  String? get lastError;
  bool get paused;
  List<VaultDeviceView> get devices;
  Future<void> syncNow();
  Future<void> setPaused(bool paused);
  Future<void> revokeDevice(String deviceId);
}

/// 生产环境控制器。持有 [VaultSession] 并委托 [VaultSyncService] 执行同步。
class VaultSyncController extends VaultSyncActions {
  VaultSyncController({
    required this.syncRepository,
    required this.apiClient,
    required this.changeApplier,
  }) : _service = VaultSyncService(
         syncRepository: syncRepository,
         apiClient: apiClient,
         changeApplier: changeApplier,
       );

  final SyncRepository syncRepository;
  final VaultApiClient apiClient;
  final VaultChangeApplier changeApplier;

  VaultSession? _session;
  SyncPhase _phase = SyncPhase.offline;
  String? _lastError;
  bool _paused = false;
  List<VaultDeviceView> _devices = [];
  int _pendingCount = 0;
  // VaultSyncService 无状态, 复用同一实例避免每次 syncNow 重复构造.
  final VaultSyncService _service;

  @override
  int get pendingCount => _pendingCount;
  @override
  SyncPhase get phase => _phase;
  @override
  String? get lastError => _lastError;
  @override
  bool get paused => _paused;
  @override
  List<VaultDeviceView> get devices => _devices;

  /// 配置当前登录会话。`null` 表示退出登录或未连接服务器，回到离线态。
  void configure(VaultSession? session) {
    _session = session;
    if (session == null) {
      _phase = SyncPhase.offline;
      _devices = [];
    } else {
      _phase = SyncPhase.idle;
      _refreshDevices();
    }
    notifyListeners();
  }

  /// 刷新 pending 数量与设备列表。由外层在同步前后或页面打开时调用。
  Future<void> refresh() async {
    _pendingCount = (await syncRepository.pending(scope: 'vault')).length;
    if (_session != null) {
      try {
        _devices = await apiClient.listDevices(_session!);
      } catch (_) {
        // 网络错误时保留现有设备列表，不清空。
      }
    }
    notifyListeners();
  }

  @override
  Future<void> syncNow() async {
    if (_session == null || _paused) return;
    _phase = SyncPhase.syncing;
    notifyListeners();

    final result = await _service.sync(_session!);
    _phase = result.phase;
    _lastError = result.error;
    _pendingCount = (await syncRepository.pending(scope: 'vault')).length;
    notifyListeners();
  }

  @override
  Future<void> setPaused(bool value) async {
    _paused = value;
    notifyListeners();
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    if (_session == null) return;
    await apiClient.revokeDevice(_session!, deviceId);
    _devices = await apiClient.listDevices(_session!);
    notifyListeners();
  }

  Future<void> _refreshDevices() async {
    if (_session == null) return;
    try {
      _devices = await apiClient.listDevices(_session!);
    } catch (_) {
      // 网络错误 — 保留空设备列表。
    }
  }
}
