import 'dart:async';

import '../domain/campaign.dart';

/// Abstract realtime socket service for a campaign chat room.
///
/// Implementations connect to the server's `/campaigns` Socket.IO namespace,
/// join a campaign room, and expose incoming `campaign:message:new` and
/// `campaign:changed` events. [changeStream] emits a signal whenever any
/// entity in the campaign changes (actor/content), so listeners can trigger
/// an incremental pull.
abstract class CampaignSocketService {
  bool get isConnected;

  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String campaignId,
  });

  Future<void> disconnect();

  Stream<CampaignChatMessage> get messageStream;

  /// 战役实体变更信号流。收到信号后应触发 [pullUntilCurrent] 增量拉取。
  Stream<void> get changeStream;
}

class NoopCampaignSocketService implements CampaignSocketService {
  final _messageController =
      StreamController<CampaignChatMessage>.broadcast();
  final _changeController = StreamController<void>.broadcast();

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

  @override
  Stream<void> get changeStream => _changeController.stream;

  void emitMessage(CampaignChatMessage message) {
    _messageController.add(message);
  }

  /// 测试辅助：模拟服务端推送 campaign:changed 信号。
  void emitChange() {
    _changeController.add(null);
  }

  Future<void> dispose() async {
    await _messageController.close();
    await _changeController.close();
  }
}
