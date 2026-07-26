import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { CampaignsModule } from '../campaigns/campaigns.module';
import { GameEventsController } from './game-events.controller';
import { GameEventsService } from './game-events.service';

@Module({
  imports: [PrismaModule, AuthModule, CampaignsModule],
  controllers: [GameEventsController],
  providers: [GameEventsService],
  exports: [GameEventsService],
})
export class GameEventsModule {}
