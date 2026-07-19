import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { CampaignSyncModule } from './modules/campaign-sync/campaign-sync.module';
import { CampaignsModule } from './modules/campaigns/campaigns.module';
import { CharactersModule } from './modules/characters/characters.module';
import { CheckRequestsModule } from './modules/check-requests/check-requests.module';
import { EncountersModule } from './modules/encounters/encounters.module';
import { HealthModule } from './modules/health/health.module';
import { MediaModule } from './modules/media/media.module';
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
    MediaModule,
    ServerInfoModule,
    AuthModule,
    ServerSettingsModule,
    CampaignsModule,
    CampaignSyncModule,
    CharactersModule,
    CheckRequestsModule,
    EncountersModule,
    RealtimeModule,
    VaultModule
  ]
})
export class AppModule {}
