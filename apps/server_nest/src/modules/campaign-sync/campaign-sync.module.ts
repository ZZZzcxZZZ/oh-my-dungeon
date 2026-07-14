import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CampaignsModule } from "../campaigns/campaigns.module";
import { RealtimeModule } from "../realtime/realtime.module";
import { PrismaModule } from "../../prisma/prisma.module";
import { CampaignActorsController } from "./campaign-actors.controller";
import { CampaignActorsService } from "./campaign-actors.service";
import { CampaignChangeService } from "./campaign-change.service";

@Module({
  imports: [PrismaModule, AuthModule, CampaignsModule, RealtimeModule],
  controllers: [CampaignActorsController],
  providers: [CampaignChangeService, CampaignActorsService],
  exports: [CampaignChangeService, CampaignActorsService],
})
export class CampaignSyncModule {}
