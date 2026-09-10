import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { CampaignSyncModule } from './modules/campaign-sync/campaign-sync.module';
import { CampaignsModule } from './modules/campaigns/campaigns.module';
import { CharactersModule } from './modules/characters/characters.module';
// EncountersModule 已从应用装配中摘除: 战斗系统不开发 (见 0.1 收敛规格),
// 客户端无任何消费者. 代码与测试暂保留, 标注 deprecated 供后续清理.
// import { EncountersModule } from './modules/encounters/encounters.module';
import { GameEventsModule } from './modules/game-events/game-events.module';
import { HealthModule } from './modules/health/health.module';
// MediaModule 已从应用装配中摘除: 客户端无消费者 (头像走本地 data URL).
// 代码与测试暂保留, 标注 deprecated 供后续清理或接入服务器头像同步.
// import { MediaModule } from './modules/media/media.module';
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
