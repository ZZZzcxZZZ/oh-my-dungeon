import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { CampaignSyncModule } from './modules/campaign-sync/campaign-sync.module';
import { CampaignsModule } from './modules/campaigns/campaigns.module';
import { CharactersModule } from './modules/characters/characters.module';
import { GameEventsModule } from './modules/game-events/game-events.module';
import { HealthModule } from './modules/health/health.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { ServerInfoModule } from './modules/server-info/server-info.module';
import { ServerSettingsModule } from './modules/server-settings/server-settings.module';
import { VaultModule } from './modules/vault/vault.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', '../../.env']
    }),
    PrismaModule,
    HealthModule,
    // 媒体与战斗模块已随产品范围收敛删除 (客户端无消费者).
    ServerInfoModule,
    AuthModule,
    ServerSettingsModule,
    CampaignsModule,
    CampaignSyncModule,
    CharactersModule,
    GameEventsModule,
    RealtimeModule,
    VaultModule
  ]
})
export class AppModule {}
