import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import type {
  ServerDiscoverySettings,
  ServerSettingsView,
  UpdateServerSettingsInput
} from './server-settings.types';

const DEFAULT_SETTINGS: ServerSettingsView = {
  serverName: 'D&D Table Tool',
  registrationEnabled: true,
  defaultLocale: 'zh-CN',
  maxUploadSizeMb: 20
};

const ALLOWED_ADMIN_ROLES = new Set(['owner', 'admin']);

@Injectable()
export class ServerSettingsService {
  constructor(private readonly prismaService: PrismaService) {}

  async getDiscoverySettings(): Promise<ServerDiscoverySettings> {
    const existing = await this.prismaService.serverSetting.findFirst();
    const row =
      existing ??
      (await this.prismaService.serverSetting.upsert({
        where: { id: 'singleton' },
        create: { id: 'singleton' },
        update: {}
      }));
    return {
      instanceId: row.instanceId,
      serverName: row.serverName,
      registrationEnabled: row.registrationEnabled
    };
  }

  async getSettings(): Promise<ServerSettingsView> {
    const row = await this.prismaService.serverSetting.findFirst();
    if (!row) {
      return { ...DEFAULT_SETTINGS };
    }
    return toView(row);
  }

  async updateSettings(
    userId: string,
    input: UpdateServerSettingsInput
  ): Promise<ServerSettingsView> {
    await this.assertCanManage(userId);

    const existing = await this.prismaService.serverSetting.findFirst();
    let saved: any;
    if (!existing) {
      saved = await this.prismaService.serverSetting.create({
        data: { registrationEnabled: input.registrationEnabled }
      });
    } else {
      saved = await this.prismaService.serverSetting.update({
        where: { id: existing.id },
        data: { registrationEnabled: input.registrationEnabled }
      });
    }
    return toView(saved);
  }

  private async assertCanManage(userId: string): Promise<void> {
    const admin = await this.prismaService.serverAdmin.findUnique({
      where: { userId }
    });
    if (!admin || !ALLOWED_ADMIN_ROLES.has(admin.role)) {
      throw new ForbiddenException('Server admin privileges required');
    }
  }
}

function toView(row: {
  serverName: string;
  registrationEnabled: boolean;
  defaultLocale: string;
  maxUploadSizeMb: number;
}): ServerSettingsView {
  return {
    serverName: row.serverName,
    registrationEnabled: row.registrationEnabled,
    defaultLocale: row.defaultLocale,
    maxUploadSizeMb: row.maxUploadSizeMb
  };
}
