import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { CampaignsController } from './campaigns.controller';
import { CampaignsService } from './campaigns.service';
import { CampaignPolicy } from './policies/campaign.policy';

@Module({
  imports: [PrismaModule, AuthModule, RealtimeModule],
  controllers: [CampaignsController],
  providers: [CampaignsService, CampaignPolicy],
  exports: [CampaignsService, CampaignPolicy]
})
export class CampaignsModule {}
