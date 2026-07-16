import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { CampaignsController } from './campaigns.controller';
import { CampaignsService } from './campaigns.service';
import { CampaignPolicy } from './policies/campaign.policy';
import { CampaignArchivesService } from './campaign-archives.service';
import { CampaignArchivesController } from './campaign-archives.controller';

@Module({
  imports: [PrismaModule, AuthModule, RealtimeModule],
  controllers: [CampaignsController, CampaignArchivesController],
  providers: [CampaignsService, CampaignPolicy, CampaignArchivesService],
  exports: [CampaignsService, CampaignPolicy]
})
export class CampaignsModule {}
