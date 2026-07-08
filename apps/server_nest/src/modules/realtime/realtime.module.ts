import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { SessionsGateway } from './sessions.gateway';

@Module({
  imports: [PrismaModule, AuthModule],
  providers: [SessionsGateway],
  exports: [SessionsGateway]
})
export class RealtimeModule {}
