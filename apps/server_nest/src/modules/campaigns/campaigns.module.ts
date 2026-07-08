import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { CampaignsController } from './campaigns.controller';
import { CampaignsService } from './campaigns.service';
import { CampaignPolicy } from './policies/campaign.policy';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [CampaignsController],
  providers: [CampaignsService, CampaignPolicy],
  exports: [CampaignsService]
})
export class CampaignsModule {}
