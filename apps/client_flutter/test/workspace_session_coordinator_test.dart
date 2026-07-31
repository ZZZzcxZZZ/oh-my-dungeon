import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/workspace/workspace_database_factory.dart';
import 'package:dnd_table_client/src/core/workspace/workspace_identity.dart';
import 'package:dnd_table_client/src/core/workspace/workspace_session_coordinator.dart';
import 'package:dnd_table_client/src/core/workspace/workspace_storage_manager.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts local and switches by stable server and user ids', () async {
    final manager = WorkspaceStorageManager(factory: _MemoryFactory());
    final coordinator = WorkspaceSessionCoordinator(storage: manager);

    await coordinator.initialize();
    expect(manager.identity, const LocalWorkspaceIdentity());

    await coordinator.authenticated(
      serverInstanceId: 'server-1',
      userId: 'user-1',
    );
    expect(
      manager.identity,
      AccountWorkspaceIdentity(serverInstanceId: 'server-1', userId: 'user-1'),
    );

    await manager.dispose();
  });

  test('network interruption does not change the account workspace', () async {
    final manager = WorkspaceStorageManager(factory: _MemoryFactory());
    final coordinator = WorkspaceSessionCoordinator(storage: manager);
    await coordinator.initialize();
    await coordinator.authenticated(
      serverInstanceId: 'server-1',
      userId: 'user-1',
    );

    coordinator.networkUnavailable();

    expect(
      manager.identity,
      AccountWorkspaceIdentity(serverInstanceId: 'server-1', userId: 'user-1'),
    );
    await manager.dispose();
  });

  test('explicit logout returns to local workspace', () async {
    final manager = WorkspaceStorageManager(factory: _MemoryFactory());
    final coordinator = WorkspaceSessionCoordinator(storage: manager);
    await coordinator.initialize();
    await coordinator.authenticated(
      serverInstanceId: 'server-1',
      userId: 'user-1',
    );

    await coordinator.loggedOut();

    expect(manager.identity, const LocalWorkspaceIdentity());
    await manager.dispose();
  });

  test(
    'keeps the previous database alive until the handoff completes',
    () async {
      final factory = _TrackingMemoryFactory();
      final manager = WorkspaceStorageManager(factory: factory);
      final coordinator = WorkspaceSessionCoordinator(storage: manager);
      await coordinator.initialize();
      final localDatabase = factory.opened.single;

      await coordinator.authenticated(
        serverInstanceId: 'server-1',
        userId: 'user-1',
      );

      await localDatabase.customSelect('SELECT 1').get();
      expect(factory.closed, isEmpty);

      await manager.completeHandoff();

      expect(factory.closed, contains(localDatabase));
      await manager.dispose();
    },
  );
}

class _MemoryFactory implements WorkspaceDatabaseFactory {
  @override
  Future<AppDatabase> open(WorkspaceIdentity identity) async {
    return AppDatabase.forTesting(NativeDatabase.memory());
  }
}

class _TrackingMemoryFactory implements WorkspaceDatabaseFactory {
  final List<AppDatabase> opened = [];
  final List<AppDatabase> closed = [];

  @override
  Future<AppDatabase> open(WorkspaceIdentity identity) async {
    final database = _TrackingAppDatabase(onClose: closed.add);
    opened.add(database);
    return database;
  }
}

class _TrackingAppDatabase extends AppDatabase {
  _TrackingAppDatabase({required this.onClose})
    : super.forTesting(NativeDatabase.memory());

  final void Function(AppDatabase database) onClose;

  @override
  Future<void> close() async {
    onClose(this);
    await super.close();
  }
}
