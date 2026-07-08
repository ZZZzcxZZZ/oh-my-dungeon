import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { CampaignsModule } from './modules/campaigns/campaigns.module';
import { HealthModule } from './modules/health/health.module';
import { RoomsModule } from './modules/rooms/rooms.module';
import { ServerInfoModule } from './modules/server-info/server-info.module';
import { ServerSettingsModule } from './modules/server-settings/server-settings.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true
    }),
    PrismaModule,
    HealthModule,
    RoomsModule,
    ServerInfoModule,
    AuthModule,
    ServerSettingsModule,
    CampaignsModule
  ]
})
export class AppModule {}
