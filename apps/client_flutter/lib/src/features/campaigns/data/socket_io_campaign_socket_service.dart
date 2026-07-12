import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../domain/campaign.dart';
import 'campaign_socket_service.dart';

class SocketIoCampaignSocketService implements CampaignSocketService {
  io.Socket? _socket;
  bool _connected = false;

  final _messageController =
      StreamController<CampaignChatMessage>.broadcast();

  @override
  bool get isConnected => _connected;

  @override
  Stream<CampaignChatMessage> get messageStream => _messageController.stream;

  @override
  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String campaignId,
  }) async {
    await disconnect();

    final completer = Completer<void>();
    final uri = Uri.parse(serverOrigin);

    _socket = io.io(
      '${uri.origin}/campaigns',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': accessToken})
          .enableReconnection()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _connected = true;
        _socket!.emit('campaign:join', {'campaignId': campaignId});
        if (!completer.isCompleted) {
          completer.complete();
        }
      })
      ..onDisconnect((_) {
        _connected = false;
      })
      ..onConnectError((error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      })
      ..on('campaign:message:new', (data) {
        final message = _parseMessage(data);
        if (message != null) _messageController.add(message);
      });

    _socket!.connect();

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    if (socket == null) return;
    _connected = false;
    socket.clearListeners();
    socket.dispose();
    _socket = null;
  }

  CampaignChatMessage? _parseMessage(dynamic data) {
    final json = _asJson(data);
    if (json == null) return null;
    try {
      return CampaignChatMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?>? _asJson(dynamic data) {
    if (data is Map<String, Object?>) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, Object?>) return decoded;
      } catch (_) {}
    }
    return null;
  }
}
