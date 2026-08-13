import { ForbiddenException } from '@nestjs/common';
import { ServerSettingsService } from './server-settings.service';

describe('ServerSettingsService', () => {
  let service: ServerSettingsService;
  let prismaService: {
    serverSetting: {
      findFirst: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      upsert: jest.Mock;
    };
    serverAdmin: {
      findUnique: jest.Mock;
    };
  };

  beforeEach(() => {
    prismaService = {
      serverSetting: {
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        upsert: jest.fn()
      },
      serverAdmin: {
        findUnique: jest.fn()
      }
    };

    service = new ServerSettingsService(prismaService as any);
  });

  describe('getSettings', () => {
    it('returns the stored settings as a public view', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: true,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15,
        allowPublicCampaignDiscovery: false,
        enabledSystems: ['dnd5e'],
        createdAt: new Date(),
        updatedAt: new Date()
      });

      const result = await service.getSettings();

      expect(result).toEqual({
        serverName: 'Friday Table',
        registrationEnabled: true,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15
      });
    });

    it('returns defaults when no settings row exists', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue(null);

      const result = await service.getSettings();

      expect(result).toEqual({
        serverName: 'OhMyDungeon',
        registrationEnabled: true,
        defaultLocale: 'zh-CN',
        maxUploadSizeMb: 20
      });
    });

    it('does not leak internal fields like id or allowPublicCampaignDiscovery', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: true,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15,
        allowPublicCampaignDiscovery: false,
        enabledSystems: ['dnd5e'],
        createdAt: new Date(),
        updatedAt: new Date()
      });

      const result = await service.getSettings();

      expect(result).not.toHaveProperty('id');
      expect(result).not.toHaveProperty('allowPublicCampaignDiscovery');
      expect(result).not.toHaveProperty('enabledSystems');
    });
  });

  describe('getDiscoverySettings', () => {
    it('returns the persisted server identity', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        id: 'settings-1',
        instanceId: 'instance-1',
        serverName: 'Friday Table',
        registrationEnabled: true,
        defaultLocale: 'zh-CN',
        maxUploadSizeMb: 20
      });

      await expect(service.getDiscoverySettings()).resolves.toEqual({
        instanceId: 'instance-1',
        serverName: 'Friday Table',
        registrationEnabled: true
      });
      expect(prismaService.serverSetting.upsert).not.toHaveBeenCalled();
    });

    it('creates a stable server identity when settings do not exist', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue(null);
      prismaService.serverSetting.upsert.mockResolvedValue({
        id: 'settings-1',
        instanceId: 'instance-1',
        serverName: 'OhMyDungeon',
        registrationEnabled: true,
        defaultLocale: 'zh-CN',
        maxUploadSizeMb: 20
      });

      await expect(service.getDiscoverySettings()).resolves.toEqual({
        instanceId: 'instance-1',
        serverName: 'OhMyDungeon',
        registrationEnabled: true
      });
      expect(prismaService.serverSetting.upsert).toHaveBeenCalledWith({
        where: { id: 'singleton' },
        create: { id: 'singleton' },
        update: {}
      });
    });
  });

  describe('updateSettings', () => {
    it('rejects a non-admin user with 403', async () => {
      prismaService.serverAdmin.findUnique.mockResolvedValue(null);

      await expect(
        service.updateSettings('user-1', { registrationEnabled: false })
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a user whose admin role is neither owner nor admin', async () => {
      prismaService.serverAdmin.findUnique.mockResolvedValue({
        userId: 'user-1',
        role: 'spectator'
      });

      await expect(
        service.updateSettings('user-1', { registrationEnabled: false })
      ).rejects.toThrow(ForbiddenException);
    });

    it('allows an owner to update registrationEnabled', async () => {
      prismaService.serverAdmin.findUnique.mockResolvedValue({
        userId: 'user-1',
        role: 'owner'
      });
      prismaService.serverSetting.findFirst.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: true,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15
      });
      prismaService.serverSetting.update.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: false,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15
      });

      const result = await service.updateSettings('user-1', {
        registrationEnabled: false
      });

      expect(prismaService.serverSetting.update).toHaveBeenCalledWith({
        where: { id: 'settings-1' },
        data: { registrationEnabled: false }
      });
      expect(result.registrationEnabled).toBe(false);
    });

    it('allows an admin to update registrationEnabled', async () => {
      prismaService.serverAdmin.findUnique.mockResolvedValue({
        userId: 'user-2',
        role: 'admin'
      });
      prismaService.serverSetting.findFirst.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: false,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15
      });
      prismaService.serverSetting.update.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: true,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15
      });

      const result = await service.updateSettings('user-2', {
        registrationEnabled: true
      });

      expect(result.registrationEnabled).toBe(true);
    });

    it('creates a settings row when none exists yet', async () => {
      prismaService.serverAdmin.findUnique.mockResolvedValue({
        userId: 'user-1',
        role: 'owner'
      });
      prismaService.serverSetting.findFirst.mockResolvedValue(null);
      prismaService.serverSetting.create.mockResolvedValue({
        id: 'settings-1',
        serverName: 'OhMyDungeon',
        registrationEnabled: false,
        defaultLocale: 'zh-CN',
        maxUploadSizeMb: 20
      });

      const result = await service.updateSettings('user-1', {
        registrationEnabled: false
      });

      expect(prismaService.serverSetting.create).toHaveBeenCalledWith({
        data: { registrationEnabled: false }
      });
      expect(prismaService.serverSetting.update).not.toHaveBeenCalled();
      expect(result.registrationEnabled).toBe(false);
    });

    it('checks admin privileges before touching settings', async () => {
      prismaService.serverAdmin.findUnique.mockResolvedValue(null);

      await expect(
        service.updateSettings('user-1', { registrationEnabled: false })
      ).rejects.toThrow();

      expect(prismaService.serverSetting.findFirst).not.toHaveBeenCalled();
      expect(prismaService.serverSetting.update).not.toHaveBeenCalled();
    });

    it('returns the updated view without internal fields', async () => {
      prismaService.serverAdmin.findUnique.mockResolvedValue({
        userId: 'user-1',
        role: 'owner'
      });
      prismaService.serverSetting.findFirst.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: true,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15
      });
      prismaService.serverSetting.update.mockResolvedValue({
        id: 'settings-1',
        serverName: 'Friday Table',
        registrationEnabled: false,
        defaultLocale: 'en-US',
        maxUploadSizeMb: 15,
        allowPublicCampaignDiscovery: false,
        enabledSystems: ['dnd5e'],
        createdAt: new Date(),
        updatedAt: new Date()
      });

      const result = await service.updateSettings('user-1', {
        registrationEnabled: false
      });

      expect(result).not.toHaveProperty('id');
      expect(result).not.toHaveProperty('allowPublicCampaignDiscovery');
    });
  });
});
