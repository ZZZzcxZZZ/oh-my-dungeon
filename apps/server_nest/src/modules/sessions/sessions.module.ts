import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { SessionsController } from './sessions.controller';
import { SessionsService } from './sessions.service';
import { SessionPolicy } from './policies/session.policy';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [SessionsController],
  providers: [SessionsService, SessionPolicy],
  exports: [SessionsService]
})
export class SessionsModule {}
