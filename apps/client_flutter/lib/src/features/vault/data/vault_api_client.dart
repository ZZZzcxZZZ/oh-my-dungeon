import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/sync/sync_models.dart';
import '../domain/vault_models.dart';

/// Personal Vault HTTP 接口。所有方法要求 Bearer token 与 X-Device-Id 头。
abstract interface class VaultApiClient {
  Future<VaultPushResult> push(
    VaultSession session,
    List<SyncOperation> operations,
  );
  Future<VaultChangePage> changes(VaultSession session, String cursor);
  Future<List<VaultDeviceView>> listDevices(VaultSession session);
  Future<void> revokeDevice(VaultSession session, String deviceId);
}

/// 基于 `package:http` 的实现。构造时注入 [client] 以便测试用 MockClient 替换。
class HttpVaultApiClient implements VaultApiClient {
  HttpVaultApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<VaultPushResult> push(
    VaultSession session,
    List<SyncOperation> operations,
  ) async {
    final response = await _client.post(
      Uri.parse('${_normalize(session.baseUrl)}/api/vault/push'),
      headers: {
        'authorization': 'Bearer ${session.accessToken}',
        'x-device-id': session.deviceId,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'operations': operations
            .map(
              (op) => {
                'operationId': op.id,
                'entityType': op.entityType,
                'entityId': op.entityId,
                'baseRevision': op.baseRevision,
                'operation': 'upsert',
                'payload': jsonDecode(op.payloadJson),
              },
            )
            .toList(),
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = _parsePushResult(decoded);

    if (response.statusCode == 409) {
      throw VaultConflictException(result);
    }
    if (response.statusCode != 200) {
      throw VaultApiException(
        'Vault push failed with HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    return result;
  }

  @override
  Future<VaultChangePage> changes(VaultSession session, String cursor) async {
    final response = await _client.get(
      Uri.parse(
        '${_normalize(session.baseUrl)}/api/vault/changes?cursor=$cursor',
      ),
      headers: {
        'authorization': 'Bearer ${session.accessToken}',
        'x-device-id': session.deviceId,
      },
    );

    if (response.statusCode != 200) {
      throw VaultApiException(
        'Vault changes failed with HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawChanges = decoded['changes'] as List<dynamic>? ?? const [];
    return VaultChangePage(
      cursor: decoded['cursor'].toString(),
      hasMore: (decoded['hasMore'] as bool?) ?? false,
      changes: rawChanges
          .map((raw) => _parseChange(raw as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<VaultDeviceView>> listDevices(VaultSession session) async {
    final response = await _client.get(
      Uri.parse('${_normalize(session.baseUrl)}/api/vault/devices'),
      headers: {
        'authorization': 'Bearer ${session.accessToken}',
        'x-device-id': session.deviceId,
      },
    );

    if (response.statusCode != 200) {
      throw VaultApiException(
        'Vault list devices failed with HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> rawDevices = decoded is List<dynamic>
        ? decoded
        : (decoded as Map<String, dynamic>)['devices'] as List<dynamic>? ??
              const [];
    return rawDevices
        .map((raw) => _parseDevice(raw as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> revokeDevice(VaultSession session, String deviceId) async {
    final response = await _client.delete(
      Uri.parse('${_normalize(session.baseUrl)}/api/vault/devices/$deviceId'),
      headers: {
        'authorization': 'Bearer ${session.accessToken}',
        'x-device-id': session.deviceId,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw VaultApiException(
        'Vault revoke device failed with HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }

  VaultPushResult _parsePushResult(Map<String, dynamic> decoded) {
    final applied = (decoded['applied'] as List<dynamic>?) ?? const [];
    final skipped = (decoded['skipped'] as List<dynamic>?) ?? const [];
    final conflicts = (decoded['conflicts'] as List<dynamic>?) ?? const [];
    return VaultPushResult(
      applied: applied.map((e) => e.toString()).toList(),
      skipped: skipped.map((e) => e.toString()).toList(),
      conflicts: conflicts
          .map((raw) => _parseConflict(raw as Map<String, dynamic>))
          .toList(),
    );
  }

  VaultConflict _parseConflict(Map<String, dynamic> raw) {
    return VaultConflict(
      entityId: raw['entityId'].toString(),
      currentRevision: (raw['currentRevision'] as num).toInt(),
    );
  }

  VaultChange _parseChange(Map<String, dynamic> raw) {
    final payload = raw['payload'];
    return VaultChange(
      cursor: raw['cursor'].toString(),
      operation: raw['operation'].toString(),
      entityType: raw['entityType'].toString(),
      entityId: raw['entityId'].toString(),
      revision: (raw['revision'] as num).toInt(),
      payloadJson: payload == null ? '{}' : jsonEncode(payload),
    );
  }

  VaultDeviceView _parseDevice(Map<String, dynamic> raw) {
    return VaultDeviceView(
      deviceId: raw['deviceId'].toString(),
      name: raw['name'].toString(),
      platform: raw['platform'].toString(),
      lastCursor: raw['lastCursor']?.toString() ?? '0',
      lastSeenAt: raw['lastSeenAt']?.toString() ?? '',
      revokedAt: raw['revokedAt']?.toString(),
      isCurrent: (raw['isCurrent'] as bool?) ?? false,
    );
  }

  String _normalize(String baseUrl) {
    return baseUrl.replaceFirst(RegExp(r'/+$'), '');
  }
}

class VaultApiException implements Exception {
  const VaultApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
