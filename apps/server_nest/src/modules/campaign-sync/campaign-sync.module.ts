import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CampaignsModule } from "../campaigns/campaigns.module";
import { RealtimeModule } from "../realtime/realtime.module";
import { PrismaModule } from "../../prisma/prisma.module";
import { CampaignCharactersController } from "./campaign-characters.controller";
import { CampaignCharactersService } from "./campaign-characters.service";
import { CampaignChangeService } from "./campaign-change.service";
import { CampaignContentController } from "./campaign-content.controller";
import { CampaignContentService } from "./campaign-content.service";
import { CampaignEventsController } from "./campaign-events.controller";
import { CampaignEventsService } from "./campaign-events.service";
import { CampaignEntryValidatorService } from "./campaign-entry-validator.service";

@Module({
  imports: [PrismaModule, AuthModule, CampaignsModule, RealtimeModule],
  controllers: [
    CampaignCharactersController,
    CampaignContentController,
    CampaignEventsController,
  ],
  providers: [
    CampaignChangeService,
    CampaignCharactersService,
    CampaignContentService,
    CampaignEntryValidatorService,
    CampaignEventsService,
  ],
  exports: [
    CampaignChangeService,
    CampaignCharactersService,
    CampaignContentService,
    CampaignEntryValidatorService,
    CampaignEventsService,
  ],
})
export class CampaignSyncModule {}
