import 'package:flutter/material.dart';

import '../../domain/campaign_actor.dart';
import 'campaign_actor_controller.dart';
import 'campaign_actor_sheet_page.dart';

bool canEditCampaignActor({
  required CampaignActor actor,
  required String currentUserId,
  required bool canEditAnyActor,
}) {
  return canEditAnyActor || actor.ownerUserId == currentUserId;
}

Future<void> openCampaignActorSheet({
  required BuildContext context,
  required CampaignActorController controller,
  required CampaignActor actor,
  required bool canEditAnyActor,
}) {
  final canEdit = canEditCampaignActor(
    actor: actor,
    currentUserId: controller.currentUserId,
    canEditAnyActor: canEditAnyActor,
  );
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => CampaignActorSheetPage(
        controller: controller,
        actorId: actor.id,
        canEdit: canEdit,
      ),
    ),
  );
}
