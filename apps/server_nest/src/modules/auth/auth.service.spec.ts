import { ConflictException, ForbiddenException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { PasswordHashService } from './password-hash.service';

describe('AuthService', () => {
  let authService: AuthService;
  let prismaService: {
    user: {
      count: jest.Mock;
      findFirst: jest.Mock;
      create: jest.Mock;
    };
    serverAdmin: {
      create: jest.Mock;
    };
    serverSetting: {
      findFirst: jest.Mock;
    };
    $transaction: jest.Mock;
  };
  let passwordHashService: {
    hash: jest.Mock;
  };

  beforeEach(() => {
    prismaService = {
      user: {
        count: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn()
      },
      serverAdmin: {
        create: jest.fn()
      },
      serverSetting: {
        findFirst: jest.fn()
      },
      $transaction: jest.fn()
    };
    passwordHashService = {
      hash: jest.fn().mockResolvedValue('hashed-secret')
    };

    authService = new AuthService(
      prismaService as any,
      passwordHashService as any
    );
  });

  describe('register', () => {
    const baseInput = {
      username: 'ranger',
      email: 'ranger@example.com',
      password: 'p@ssw0rd'
    };

    it('persists passwordHash and not plaintext password', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        registrationEnabled: true
      });
      prismaService.user.count.mockResolvedValue(1);
      prismaService.$transaction.mockImplementation(async (cb: any) =>
        cb(prismaService)
      );
      prismaService.user.create.mockResolvedValue({
        id: 'user-2',
        username: 'ranger',
        email: 'ranger@example.com'
      });

      await authService.register(baseInput);

      expect(passwordHashService.hash).toHaveBeenCalledWith('p@ssw0rd');
      const createArgs = prismaService.user.create.mock.calls[0][0];
      expect(createArgs.data.passwordHash).toBe('hashed-secret');
      expect(createArgs.data.password).toBeUndefined();
    });

    it('returns the registered user and isFirstUser flag', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        registrationEnabled: true
      });
      prismaService.user.count.mockResolvedValue(0);
      prismaService.$transaction.mockImplementation(async (cb: any) =>
        cb(prismaService)
      );
      prismaService.user.create.mockResolvedValue({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com'
      });

      const result = await authService.register(baseInput);

      expect(result.user).toEqual({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com'
      });
      expect(result.isFirstUser).toBe(true);
    });

    it('makes the first registered user a ServerAdmin owner', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        registrationEnabled: true
      });
      prismaService.user.count.mockResolvedValue(0);
      prismaService.$transaction.mockImplementation(async (cb: any) =>
        cb(prismaService)
      );
      prismaService.user.create.mockResolvedValue({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com'
      });

      await authService.register(baseInput);

      expect(prismaService.serverAdmin.create).toHaveBeenCalledWith({
        data: { userId: 'user-1', role: 'owner' }
      });
    });

    it('does not create a ServerAdmin for non-first users', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        registrationEnabled: true
      });
      prismaService.user.count.mockResolvedValue(3);
      prismaService.$transaction.mockImplementation(async (cb: any) =>
        cb(prismaService)
      );
      prismaService.user.create.mockResolvedValue({
        id: 'user-4',
        username: 'ranger',
        email: 'ranger@example.com'
      });

      await authService.register(baseInput);

      expect(prismaService.serverAdmin.create).not.toHaveBeenCalled();
      expect(prismaService.user.count).toHaveBeenCalled();
    });

    it('rejects a duplicate username', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        registrationEnabled: true
      });
      prismaService.user.findFirst.mockResolvedValue({ id: 'existing-user' });

      await expect(authService.register(baseInput)).rejects.toThrow(
        ConflictException
      );
    });

    it('rejects a duplicate email', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        registrationEnabled: true
      });
      prismaService.user.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({ id: 'existing-user' });

      await expect(authService.register(baseInput)).rejects.toThrow(
        ConflictException
      );
    });

    it('rejects registration when the registration switch is off', async () => {
      prismaService.serverSetting.findFirst.mockResolvedValue({
        registrationEnabled: false
      });

      await expect(authService.register(baseInput)).rejects.toThrow(
        ForbiddenException
      );
      expect(prismaService.user.create).not.toHaveBeenCalled();
    });
  });
});
