import '../../characters/presentation/character_detail_page.dart';
import 'campaign_controller.dart';

/// Task 3.3 — `CampaignActionSink` 的战役侧具体实现.
///
/// 将角色卡内的检定结果通过 `CampaignController.sendMessage` 以 `kind: 'roll'`
/// 广播到战役聊天, 携带结构化 `eventData` 供聊天渲染检定卡片.
/// 本地角色卡上下文 (无战役) 不构造此 sink, 仅保留本地 SnackBar 反馈.
class CharacterRollSink implements CampaignActionSink {
  CharacterRollSink({
    required this.campaignId,
    required this.campaignController,
    this.campaignCharacterId,
    this.conversationId,
  });

  final String campaignId;
  final CampaignController campaignController;

  @override
  final String? campaignCharacterId;

  /// Plan 2026-07-23 task 5.3: optional conversation scoping. When null,
  /// rolls are broadcast to the campaign-wide main room (legacy behaviour).
  final String? conversationId;

  @override
  Future<void> dispatchRoll(CharacterRollEvent event) async {
    await campaignController.sendMessage(
      campaignId: campaignId,
      kind: 'roll',
      content: event.summary,
      campaignCharacterId: campaignCharacterId,
      conversationId: conversationId,
      eventData: <String, Object?>{
        'notation': event.notation,
        'label': event.label,
        'total': event.total,
        'playerRolled': true,
      },
    );
  }
}
