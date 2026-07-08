import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { ServerSettingsController } from './server-settings.controller';
import { ServerSettingsService } from './server-settings.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [ServerSettingsController],
  providers: [ServerSettingsService],
  exports: [ServerSettingsService]
})
export class ServerSettingsModule {}
