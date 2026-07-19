import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { SessionPolicy } from './policies/session.policy';
import { CheckRequestsController } from './check-requests.controller';
import { CheckRequestsService } from './check-requests.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [CheckRequestsController],
  providers: [CheckRequestsService, SessionPolicy]
})
export class CheckRequestsModule {}
