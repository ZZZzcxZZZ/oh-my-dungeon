import '../database/app_database.dart';
import 'workspace_database_factory.dart';
import 'workspace_identity.dart';

final class WorkspaceStorageManager {
  WorkspaceStorageManager({required WorkspaceDatabaseFactory factory})
    : _factory = factory;

  final WorkspaceDatabaseFactory _factory;

  WorkspaceIdentity? _identity;
  AppDatabase? _database;
  final List<AppDatabase> _retiredDatabases = [];
  int _generation = 0;
  bool _disposeRequested = false;
  Future<void> _operationTail = Future<void>.value();
  Future<void>? _disposeFuture;

  WorkspaceIdentity? get identity => _identity;
  AppDatabase? get database => _database;
  int get generation => _generation;

  Future<void> activate(WorkspaceIdentity identity) {
    if (_disposeRequested) {
      throw StateError('WorkspaceStorageManager is disposed');
    }
    final operation = _operationTail.then<void>((_) => _activateNow(identity));
    _operationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> _activateNow(WorkspaceIdentity identity) async {
    if (_identity == identity) return;

    final replacement = await _factory.open(identity);
    final previous = _database;
    _database = replacement;
    _identity = identity;
    _generation += 1;
    if (previous != null) {
      _retiredDatabases.add(previous);
    }
  }

  /// Closes databases retired by the latest workspace switch.
  ///
  /// The caller must invoke this only after widgets using the previous
  /// workspace have been removed from the tree. Closing them during
  /// [activate] can otherwise interrupt in-flight Drift queries.
  Future<void> completeHandoff() {
    if (_disposeRequested) {
      return _disposeFuture ?? Future<void>.value();
    }
    final operation = _operationTail.then<void>((_) => _closeRetired());
    _operationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> _closeRetired() async {
    final retired = List<AppDatabase>.of(_retiredDatabases);
    _retiredDatabases.clear();
    for (final database in retired) {
      await database.close();
    }
  }

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    _disposeRequested = true;
    final operation = _operationTail.then<void>((_) async {
      final current = _database;
      _database = null;
      _identity = null;
      await _closeRetired();
      await current?.close();
    });
    _disposeFuture = operation;
    _operationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}
