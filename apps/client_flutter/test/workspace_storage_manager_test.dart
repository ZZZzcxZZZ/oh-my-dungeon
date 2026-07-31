import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/workspace/workspace_database_factory.dart';
import 'package:dnd_table_client/src/core/workspace/workspace_identity.dart';
import 'package:dnd_table_client/src/core/workspace/workspace_storage_manager.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closes the previous workspace after handoff completes', () async {
    final factory = _RecordingFactory();
    final manager = WorkspaceStorageManager(factory: factory);

    await manager.activate(const LocalWorkspaceIdentity());
    await manager.activate(
      AccountWorkspaceIdentity(serverInstanceId: 'server-1', userId: 'user-1'),
    );

    expect(factory.events, ['open:local', startsWith('open:account_')]);
    expect(manager.identity, isA<AccountWorkspaceIdentity>());
    expect(manager.generation, 2);

    await manager.completeHandoff();

    expect(factory.events.last, 'close:local');
    await manager.dispose();
  });

  test('does not reopen the active workspace', () async {
    final factory = _RecordingFactory();
    final manager = WorkspaceStorageManager(factory: factory);
    const identity = LocalWorkspaceIdentity();

    await manager.activate(identity);
    await manager.activate(identity);

    expect(factory.events, ['open:local']);
    expect(manager.generation, 1);
    await manager.dispose();
  });

  test('keeps the active workspace when opening another one fails', () async {
    final factory = _RecordingFactory();
    final manager = WorkspaceStorageManager(factory: factory);
    const local = LocalWorkspaceIdentity();
    await manager.activate(local);
    factory.failNextOpen = true;

    await expectLater(
      manager.activate(
        AccountWorkspaceIdentity(
          serverInstanceId: 'server-1',
          userId: 'user-1',
        ),
      ),
      throwsStateError,
    );

    expect(manager.identity, local);
    expect(manager.database, isNotNull);
    expect(manager.generation, 1);
    expect(factory.events, ['open:local', startsWith('open:account_')]);
    await manager.dispose();
  });

  test('dispose closes the active database once', () async {
    final factory = _RecordingFactory();
    final manager = WorkspaceStorageManager(factory: factory);
    await manager.activate(const LocalWorkspaceIdentity());

    await manager.dispose();
    await manager.dispose();

    expect(factory.events, ['open:local', 'close:local']);
  });

  test('serializes overlapping activations in request order', () async {
    final factory = _RecordingFactory();
    factory.accountOpenDelays.addAll([
      const Duration(milliseconds: 20),
      Duration.zero,
    ]);
    final manager = WorkspaceStorageManager(factory: factory);
    await manager.activate(const LocalWorkspaceIdentity());

    final first = manager.activate(
      AccountWorkspaceIdentity(
        serverInstanceId: 'server-1',
        userId: 'slow-user',
      ),
    );
    final second = manager.activate(
      AccountWorkspaceIdentity(
        serverInstanceId: 'server-1',
        userId: 'latest-user',
      ),
    );
    await Future.wait([first, second]);

    expect(
      manager.identity,
      AccountWorkspaceIdentity(
        serverInstanceId: 'server-1',
        userId: 'latest-user',
      ),
    );
    await manager.dispose();
  });
}

class _RecordingFactory implements WorkspaceDatabaseFactory {
  final List<Object> events = [];
  final List<Duration> accountOpenDelays = [];
  bool failNextOpen = false;

  @override
  Future<AppDatabase> open(WorkspaceIdentity identity) async {
    events.add('open:${identity.storageKey}');
    if (identity is AccountWorkspaceIdentity && accountOpenDelays.isNotEmpty) {
      await Future<void>.delayed(accountOpenDelays.removeAt(0));
    }
    if (failNextOpen) {
      failNextOpen = false;
      throw StateError('open failed');
    }
    return _RecordingDatabase(
      identity.storageKey,
      events,
      NativeDatabase.memory(),
    );
  }
}

class _RecordingDatabase extends AppDatabase {
  _RecordingDatabase(this.storageKey, this.events, super.executor)
    : super.forTesting();

  final String storageKey;
  final List<Object> events;
  bool _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    events.add('close:$storageKey');
    await super.close();
  }
}
