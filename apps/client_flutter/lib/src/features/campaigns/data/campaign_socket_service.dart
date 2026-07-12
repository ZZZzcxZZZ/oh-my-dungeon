import 'dart:async';

import '../domain/campaign.dart';

/// Abstract realtime socket service for a campaign chat room.
///
/// Implementations connect to the server's `/campaigns` Socket.IO namespace,
/// join a campaign room, and expose incoming `campaign:message:new` events.
abstract class CampaignSocketService {
  bool get isConnected;

  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String campaignId,
  });

  Future<void> disconnect();

  Stream<CampaignChatMessage> get messageStream;
}

class NoopCampaignSocketService implements CampaignSocketService {
  final _messageController =
      StreamController<CampaignChatMessage>.broadcast();

  @override
  bool get isConnected => false;

  @override
  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String campaignId,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<CampaignChatMessage> get messageStream => _messageController.stream;

  void emitMessage(CampaignChatMessage message) {
    _messageController.add(message);
  }

  Future<void> dispose() async {
    await _messageController.close();
  }
}
