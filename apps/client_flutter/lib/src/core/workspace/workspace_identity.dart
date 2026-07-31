import 'dart:convert';

import 'package:crypto/crypto.dart';

sealed class WorkspaceIdentity {
  const WorkspaceIdentity();

  String get storageKey;
}

final class LocalWorkspaceIdentity extends WorkspaceIdentity {
  const LocalWorkspaceIdentity();

  @override
  String get storageKey => 'local';

  @override
  bool operator ==(Object other) => other is LocalWorkspaceIdentity;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AccountWorkspaceIdentity extends WorkspaceIdentity {
  factory AccountWorkspaceIdentity({
    required String serverInstanceId,
    required String userId,
  }) {
    final normalizedServerId = serverInstanceId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedServerId.isEmpty) {
      throw ArgumentError.value(
        serverInstanceId,
        'serverInstanceId',
        'must not be empty',
      );
    }
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    return AccountWorkspaceIdentity._(
      serverInstanceId: normalizedServerId,
      userId: normalizedUserId,
    );
  }

  const AccountWorkspaceIdentity._({
    required this.serverInstanceId,
    required this.userId,
  });

  final String serverInstanceId;
  final String userId;

  @override
  String get storageKey {
    final digest = sha256.convert(
      utf8.encode('$serverInstanceId\u0000$userId'),
    );
    return 'account_$digest';
  }

  @override
  bool operator ==(Object other) =>
      other is AccountWorkspaceIdentity &&
      other.serverInstanceId == serverInstanceId &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(serverInstanceId, userId);
}
