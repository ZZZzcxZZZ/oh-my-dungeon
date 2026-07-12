import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { CampaignsGateway } from './campaigns.gateway';
import { SessionsGateway } from './sessions.gateway';

@Module({
  imports: [PrismaModule, AuthModule],
  providers: [CampaignsGateway, SessionsGateway],
  exports: [CampaignsGateway, SessionsGateway]
})
export class RealtimeModule {}
