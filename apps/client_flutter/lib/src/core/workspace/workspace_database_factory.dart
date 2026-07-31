import '../database/app_database.dart';
import 'workspace_identity.dart';

abstract interface class WorkspaceDatabaseFactory {
  Future<AppDatabase> open(WorkspaceIdentity identity);
}

final class DriftWorkspaceDatabaseFactory implements WorkspaceDatabaseFactory {
  const DriftWorkspaceDatabaseFactory();

  @override
  Future<AppDatabase> open(WorkspaceIdentity identity) async {
    return AppDatabase.named('workspace_${identity.storageKey}.db');
  }
}
