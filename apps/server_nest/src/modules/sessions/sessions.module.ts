import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { SessionsController } from './sessions.controller';
import { SessionsService } from './sessions.service';
import { SessionPolicy } from './policies/session.policy';

@Module({
  imports: [PrismaModule, AuthModule, RealtimeModule],
  controllers: [SessionsController],
  providers: [SessionsService, SessionPolicy],
  exports: [SessionsService]
})
export class SessionsModule {}
