import { Module } from "@nestjs/common";
import { PrismaModule } from "../../prisma/prisma.module";
import { AuthModule } from "../auth/auth.module";
import { CampaignPolicy } from "../campaigns/policies/campaign.policy";
import { ContentPackageValidatorService } from "./content-package-validator.service";
import { ContentController } from "./content.controller";
import { ContentService } from "./content.service";

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [ContentController],
  providers: [CampaignPolicy, ContentPackageValidatorService, ContentService],
  exports: [ContentService],
})
export class ContentModule {}
