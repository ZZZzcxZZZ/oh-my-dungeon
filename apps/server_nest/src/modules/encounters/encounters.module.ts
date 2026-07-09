import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { CampaignPolicy } from '../campaigns/policies/campaign.policy';
import { EncountersController } from './encounters.controller';
import { EncountersService } from './encounters.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [EncountersController],
  providers: [CampaignPolicy, EncountersService],
  exports: [EncountersService]
})
export class EncountersModule {}
