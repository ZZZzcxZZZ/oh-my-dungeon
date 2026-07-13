import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { CampaignSyncModule } from './modules/campaign-sync/campaign-sync.module';
import { CampaignsModule } from './modules/campaigns/campaigns.module';
import { CharactersModule } from './modules/characters/characters.module';
import { CheckRequestsModule } from './modules/check-requests/check-requests.module';
import { ContentModule } from './modules/content/content.module';
import { EncountersModule } from './modules/encounters/encounters.module';
import { HealthModule } from './modules/health/health.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { RoomsModule } from './modules/rooms/rooms.module';
import { ServerInfoModule } from './modules/server-info/server-info.module';
import { ServerSettingsModule } from './modules/server-settings/server-settings.module';
import { SessionsModule } from './modules/sessions/sessions.module';
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
    RoomsModule,
    ServerInfoModule,
    AuthModule,
    ServerSettingsModule,
    CampaignsModule,
    CampaignSyncModule,
    CharactersModule,
    CheckRequestsModule,
    ContentModule,
    EncountersModule,
    RealtimeModule,
    SessionsModule,
    VaultModule
  ]
})
export class AppModule {}
