import 'package:dnd_table_client/src/core/workspace/workspace_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses one stable key for the local workspace', () {
    const identity = LocalWorkspaceIdentity();

    expect(identity.storageKey, 'local');
    expect(identity, const LocalWorkspaceIdentity());
  });

  test('builds a deterministic path-safe account workspace key', () {
    final identity = AccountWorkspaceIdentity(
      serverInstanceId: 'server/unsafe',
      userId: 'user:1',
    );
    final same = AccountWorkspaceIdentity(
      serverInstanceId: 'server/unsafe',
      userId: 'user:1',
    );
    final other = AccountWorkspaceIdentity(
      serverInstanceId: 'server/unsafe',
      userId: 'user:2',
    );

    expect(identity.storageKey, same.storageKey);
    expect(identity.storageKey, startsWith('account_'));
    expect(identity.storageKey, isNot(contains('/')));
    expect(identity.storageKey, isNot(contains(':')));
    expect(identity.storageKey, isNot(other.storageKey));
  });

  test('rejects empty account identity components', () {
    expect(
      () => AccountWorkspaceIdentity(serverInstanceId: '', userId: 'user-1'),
      throwsArgumentError,
    );
    expect(
      () => AccountWorkspaceIdentity(
        serverInstanceId: 'server-1',
        userId: ' ',
      ),
      throwsArgumentError,
    );
  });
}
