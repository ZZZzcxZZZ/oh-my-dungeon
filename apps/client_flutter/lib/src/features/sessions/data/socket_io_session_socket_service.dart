import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../domain/session.dart';
import 'session_socket_service.dart';

/// Realtime [SessionSocketService] backed by `socket_io_client`.
///
/// Connects to the server's `/sessions` namespace, authenticates via the
/// handshake `auth` field, and joins the session room. Incoming
/// `message:new` / `roll:new` / `session:updated` events are parsed into
/// domain objects and exposed as streams.
class SocketIoSessionSocketService implements SessionSocketService {
  SocketIoSessionSocketService();

  io.Socket? _socket;
  bool _connected = false;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _rollController = StreamController<DiceRoll>.broadcast();
  final _sessionController = StreamController<Session>.broadcast();

  @override
  bool get isConnected => _connected;

  @override
  Stream<ChatMessage> get messageStream => _messageController.stream;

  @override
  Stream<DiceRoll> get rollStream => _rollController.stream;

  @override
  Stream<Session> get sessionUpdatedStream => _sessionController.stream;

  @override
  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String sessionId,
  }) async {
    await disconnect();

    final completer = Completer<void>();
    final uri = Uri.parse(serverOrigin);

    _socket = io.io(
      '${uri.origin}/sessions',
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
        _socket!.emit('session:join', {'sessionId': sessionId});
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
      ..on('message:new', (data) {
        final message = _parseMessage(data);
        if (message != null) _messageController.add(message);
      })
      ..on('roll:new', (data) {
        final roll = _parseRoll(data);
        if (roll != null) _rollController.add(roll);
      })
      ..on('session:updated', (data) {
        final session = _parseSession(data);
        if (session != null) _sessionController.add(session);
      });

    _socket!.connect();

    // Don't block forever if the server is unreachable; resolve once connected
    // or after a short timeout so the page remains usable via HTTP.
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

  ChatMessage? _parseMessage(dynamic data) {
    final json = _asJson(data);
    if (json == null) return null;
    try {
      return ChatMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  DiceRoll? _parseRoll(dynamic data) {
    final json = _asJson(data);
    if (json == null) return null;
    try {
      return DiceRoll.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Session? _parseSession(dynamic data) {
    final json = _asJson(data);
    if (json == null) return null;
    try {
      return Session.fromJson(json);
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
