import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { CampaignsGateway } from './campaigns.gateway';

@Module({
  imports: [PrismaModule, AuthModule],
  providers: [CampaignsGateway],
  exports: [CampaignsGateway]
})
export class RealtimeModule {}
