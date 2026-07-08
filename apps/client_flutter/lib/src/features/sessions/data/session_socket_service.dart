import 'dart:async';

import '../domain/session.dart';

/// Abstract realtime socket service for a session.
///
/// Implementations connect to the server's `/sessions` WebSocket namespace,
/// join a session room, and expose streams for incoming `message:new` and
/// `roll:new` events. A no-op implementation ([NoopSessionSocketService])
/// is used in tests and when realtime is unavailable.
abstract class SessionSocketService {
  /// Whether the socket is currently connected.
  bool get isConnected;

  /// Connects to the server, authenticating with [accessToken], and joins
  /// the room for [sessionId].
  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String sessionId,
  });

  /// Emits `session:leave` and disconnects.
  Future<void> disconnect();

  /// Stream of chat messages broadcast by the server.
  Stream<ChatMessage> get messageStream;

  /// Stream of dice rolls broadcast by the server.
  Stream<DiceRoll> get rollStream;

  /// Stream of session lifecycle updates (e.g. started/ended).
  Stream<Session> get sessionUpdatedStream;
}

/// No-op implementation used in tests and when realtime is disabled.
class NoopSessionSocketService implements SessionSocketService {
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _rollController = StreamController<DiceRoll>.broadcast();
  final _sessionController = StreamController<Session>.broadcast();

  @override
  bool get isConnected => false;

  @override
  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String sessionId,
  }) async {}

  @override
  Future<void> disconnect() async {
    await _messageController.close();
    await _rollController.close();
    await _sessionController.close();
  }

  @override
  Stream<ChatMessage> get messageStream => _messageController.stream;

  @override
  Stream<DiceRoll> get rollStream => _rollController.stream;

  @override
  Stream<Session> get sessionUpdatedStream => _sessionController.stream;

  /// Test helper: simulate an incoming message.
  void emitMessage(ChatMessage message) => _messageController.add(message);

  /// Test helper: simulate an incoming roll.
  void emitRoll(DiceRoll roll) => _rollController.add(roll);

  /// Test helper: simulate a session update.
  void emitSessionUpdate(Session session) => _sessionController.add(session);
}
