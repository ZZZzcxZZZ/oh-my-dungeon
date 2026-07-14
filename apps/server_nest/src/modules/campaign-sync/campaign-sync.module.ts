import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CampaignsModule } from "../campaigns/campaigns.module";
import { RealtimeModule } from "../realtime/realtime.module";
import { PrismaModule } from "../../prisma/prisma.module";
import { CampaignActorsController } from "./campaign-actors.controller";
import { CampaignActorsService } from "./campaign-actors.service";
import { CampaignChangeService } from "./campaign-change.service";
import { CampaignContentController } from "./campaign-content.controller";
import { CampaignContentService } from "./campaign-content.service";
import { CampaignEntryValidatorService } from "./campaign-entry-validator.service";

@Module({
  imports: [PrismaModule, AuthModule, CampaignsModule, RealtimeModule],
  controllers: [CampaignActorsController, CampaignContentController],
  providers: [
    CampaignChangeService,
    CampaignActorsService,
    CampaignContentService,
    CampaignEntryValidatorService,
  ],
  exports: [
    CampaignChangeService,
    CampaignActorsService,
    CampaignContentService,
    CampaignEntryValidatorService,
  ],
})
export class CampaignSyncModule {}
