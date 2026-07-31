import 'dart:async';

import '../domain/campaign.dart';

class CampaignChangeSignal {
  const CampaignChangeSignal({
    required this.campaignId,
    required this.entityType,
    this.cursor,
  });

  final String campaignId;
  final String entityType;
  final String? cursor;
}

/// Abstract realtime socket service for a campaign chat room.
///
/// Implementations connect to the server's `/campaigns` Socket.IO namespace,
/// join a campaign room, and expose incoming `campaign:message:new` and
/// `campaign:changed` events. [changeStream] emits a signal whenever any
/// entity in the campaign changes (character/content), so listeners can trigger
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
  Stream<CampaignChangeSignal> get changeStream;
}

class NoopCampaignSocketService implements CampaignSocketService {
  final _messageController = StreamController<CampaignChatMessage>.broadcast();
  final _changeController = StreamController<CampaignChangeSignal>.broadcast();

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
  Stream<CampaignChangeSignal> get changeStream => _changeController.stream;

  void emitMessage(CampaignChatMessage message) {
    _messageController.add(message);
  }

  /// 测试辅助：模拟服务端推送 campaign:changed 信号。
  void emitChange({
    String campaignId = 'camp-1',
    String entityType = 'character',
    String? cursor,
  }) {
    _changeController.add(
      CampaignChangeSignal(
        campaignId: campaignId,
        entityType: entityType,
        cursor: cursor,
      ),
    );
  }

  Future<void> dispose() async {
    await _messageController.close();
    await _changeController.close();
  }
}
