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
    const url = new URL(publicBaseUrl);
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.pathname = '/realtime';
    return url.toString().replace(/\/$/, '');
  }
}
