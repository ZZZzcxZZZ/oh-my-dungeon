import 'workspace_identity.dart';
import 'workspace_storage_manager.dart';

/// Maps authentication lifecycle events to private local workspaces.
///
/// Connectivity is deliberately not authentication: losing the network keeps
/// the last authenticated account workspace active for offline use.
final class WorkspaceSessionCoordinator {
  WorkspaceSessionCoordinator({required WorkspaceStorageManager storage})
    : _storage = storage;

  final WorkspaceStorageManager _storage;

  Future<void> initialize() {
    return _storage.activate(const LocalWorkspaceIdentity());
  }

  Future<void> authenticated({
    required String serverInstanceId,
    required String userId,
  }) {
    return _storage.activate(
      AccountWorkspaceIdentity(
        serverInstanceId: serverInstanceId,
        userId: userId,
      ),
    );
  }

  /// A transient network failure must not expose another identity's data.
  void networkUnavailable() {}

  Future<void> loggedOut() {
    return _storage.activate(const LocalWorkspaceIdentity());
  }
}
