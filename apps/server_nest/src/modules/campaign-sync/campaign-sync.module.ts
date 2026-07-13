import { Module } from "@nestjs/common";
import { PrismaModule } from "../../prisma/prisma.module";
import { CampaignChangeService } from "./campaign-change.service";

@Module({
  imports: [PrismaModule],
  providers: [CampaignChangeService],
  exports: [CampaignChangeService],
})
export class CampaignSyncModule {}
