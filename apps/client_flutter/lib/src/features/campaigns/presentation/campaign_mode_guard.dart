import '../../client_mode/domain/client_mode.dart';

enum CampaignModeAccess { allowed, switchToDungeonMaster, switchToPlayer }

class CampaignModeGuard {
  const CampaignModeGuard._();

  static CampaignModeAccess evaluate({
    required bool isCampaignOwner,
    required ClientMode currentMode,
  }) {
    if (isCampaignOwner) {
      return currentMode == ClientMode.dungeonMaster
          ? CampaignModeAccess.allowed
          : CampaignModeAccess.switchToDungeonMaster;
    }
    return currentMode == ClientMode.player
        ? CampaignModeAccess.allowed
        : CampaignModeAccess.switchToPlayer;
  }
}
