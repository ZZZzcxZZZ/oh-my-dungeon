import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { ServerMetadata } from './server-metadata.type';

@Injectable()
export class ServerInfoService {
  constructor(private readonly configService: ConfigService) {}

  getMetadata(): ServerMetadata {
    const publicBaseUrl = this.configService.get<string>(
      'PUBLIC_BASE_URL',
      'http://localhost:3000'
    );
    const serverName = this.configService.get<string>(
      'SERVER_NAME',
      'D&D Table Tool'
    );
    const registrationEnabled =
      this.configService.get<string>('REGISTRATION_ENABLED', 'true') === 'true';

    return {
      name: serverName,
      version: '0.1.0',
      apiBaseUrl: `${publicBaseUrl}/api`,
      websocketUrl: this.toWebSocketUrl(publicBaseUrl),
      registrationEnabled,
      serverMode: 'self_hosted',
      supportedSystems: ['dnd5e'],
      apiVersion: '1',
      features: ['campaignArchives', 'campaignActors', 'campaignChat']
    };
  }

  private toWebSocketUrl(publicBaseUrl: string): string {
    // WS 路径必须与 CampaignsGateway 的 namespace 一致 (apps/server_nest/src/modules/realtime/campaigns.gateway.ts).
    // 客户端 socket_io_campaign_socket_service.dart 直接拼接 `${origin}/campaigns`, 不读取此字段,
    // 但保留此字段以避免破坏 server_profiles 持久化结构与已有客户端.
    const url = new URL(publicBaseUrl);
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.pathname = '/campaigns';
    return url.toString().replace(/\/$/, '');
  }
}
