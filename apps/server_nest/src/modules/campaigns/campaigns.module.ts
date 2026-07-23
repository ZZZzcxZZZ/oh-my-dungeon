import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { CampaignsController } from './campaigns.controller';
import { CampaignsService } from './campaigns.service';
import { CampaignPolicy } from './policies/campaign.policy';
import { CampaignArchivesService } from './campaign-archives.service';
import { CampaignArchivesController } from './campaign-archives.controller';
import { CampaignConversationsService } from './campaign-conversations.service';
import { CampaignConversationsController } from './campaign-conversations.controller';

@Module({
  imports: [PrismaModule, AuthModule, RealtimeModule],
  controllers: [CampaignsController, CampaignArchivesController, CampaignConversationsController],
  providers: [CampaignsService, CampaignPolicy, CampaignArchivesService, CampaignConversationsService],
  exports: [CampaignsService, CampaignPolicy]
})
export class CampaignsModule {}
