import { Module } from '@nestjs/common';
import { ServerSettingsModule } from '../server-settings/server-settings.module';
import { ServerInfoController } from './server-info.controller';
import { ServerInfoService } from './server-info.service';

@Module({
  imports: [ServerSettingsModule],
  controllers: [ServerInfoController],
  providers: [ServerInfoService]
})
export class ServerInfoModule {}
