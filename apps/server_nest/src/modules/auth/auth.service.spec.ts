import {
  ConflictException,
  ForbiddenException,
  UnauthorizedException
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { PasswordHashService } from './password-hash.service';

describe('AuthService', () => {
  let authService: AuthService;
  let prismaService: {
    user: {
      count: jest.Mock;
      findFirst: jest.Mock;
      findUnique: jest.Mock;
      create: jest.Mock;
    };
    serverAdmin: {
      create: jest.Mock;
    };
    serverSetting: {
      findFirst: jest.Mock;
    };
    refreshToken: {
      create: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
    };
    $transaction: jest.Mock;
  };
  let passwordHashService: {
    hash: jest.Mock;
    compare: jest.Mock;
  };
  let tokenService: {
    signAccessToken: jest.Mock;
    generateRefreshToken: jest.Mock;
    refreshExpiresAt: jest.Mock;
    hashRefreshToken: jest.Mock;
  };

  beforeEach(() => {
    prismaService = {
      user: {
        count: jest.fn(),
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn()
      },
      serverAdmin: {
        create: jest.fn()
      },
      serverSetting: {
        findFirst: jest.fn()
      },
      refreshToken: {
        create: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn()
      },
      $transaction: jest.fn()
    };
    passwordHashService = {
      hash: jest.fn().mockResolvedValue('hashed-secret'),
      compare: jest.fn()
    };
    tokenService = {
      signAccessToken: jest.fn().mockReturnValue('access-token'),
      generateRefreshToken: jest.fn().mockReturnValue({
        token: 'refresh-plaintext',
        tokenHash: 'refresh-hash'
      }),
      refreshExpiresAt: jest.fn().mockReturnValue(new Date('2026-08-08T00:00:00Z')),
      hashRefreshToken: jest.fn().mockReturnValue('refresh-hash')
    };

    authService = new AuthService(
      prismaService as any,
      passwordHashService as any,
      tokenService as any
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

  describe('login', () => {
    const storedUser = {
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com',
      passwordHash: 'hashed-secret'
    };

    beforeEach(() => {
      passwordHashService.compare.mockResolvedValue(true);
      prismaService.user.findFirst.mockResolvedValue(storedUser);
      prismaService.refreshToken.create.mockResolvedValue({});
    });

    it('returns the user, access token and refresh token on success', async () => {
      const result = await authService.login({
        identifier: 'ranger',
        password: 'p@ssw0rd'
      });

      expect(result.user).toEqual({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com'
      });
      expect(result.accessToken).toBe('access-token');
      expect(result.refreshToken).toBe('refresh-plaintext');
    });

    it('looks up the user by username or email', async () => {
      await authService.login({
        identifier: 'ranger@example.com',
        password: 'p@ssw0rd'
      });

      expect(prismaService.user.findFirst).toHaveBeenCalledWith({
        where: {
          OR: [
            { username: 'ranger@example.com' },
            { email: 'ranger@example.com' }
          ]
        }
      });
    });

    it('verifies the password against the stored hash', async () => {
      await authService.login({ identifier: 'ranger', password: 'p@ssw0rd' });

      expect(passwordHashService.compare).toHaveBeenCalledWith(
        'p@ssw0rd',
        'hashed-secret'
      );
    });

    it('signs an access token with userId and username', async () => {
      await authService.login({ identifier: 'ranger', password: 'p@ssw0rd' });

      expect(tokenService.signAccessToken).toHaveBeenCalledWith({
        userId: 'user-1',
        username: 'ranger'
      });
    });

    it('persists the refresh token hash, not the plaintext', async () => {
      await authService.login({ identifier: 'ranger', password: 'p@ssw0rd' });

      expect(prismaService.refreshToken.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId: 'user-1',
          tokenHash: 'refresh-hash',
          expiresAt: expect.any(Date)
        })
      });
      const createArgs = prismaService.refreshToken.create.mock.calls[0][0];
      expect(createArgs.data.token).toBeUndefined();
    });

    it('does not expose passwordHash on the returned user', async () => {
      const result = await authService.login({
        identifier: 'ranger',
        password: 'p@ssw0rd'
      });

      expect(result.user).not.toHaveProperty('passwordHash');
    });

    it('rejects an unknown identifier with 401', async () => {
      prismaService.user.findFirst.mockResolvedValue(null);

      await expect(
        authService.login({ identifier: 'ghost', password: 'p@ssw0rd' })
      ).rejects.toThrow(UnauthorizedException);
    });

    it('rejects a wrong password with 401', async () => {
      passwordHashService.compare.mockResolvedValue(false);

      await expect(
        authService.login({ identifier: 'ranger', password: 'wrong' })
      ).rejects.toThrow(UnauthorizedException);
    });

    it('does not issue tokens when credentials are invalid', async () => {
      passwordHashService.compare.mockResolvedValue(false);

      await expect(
        authService.login({ identifier: 'ranger', password: 'wrong' })
      ).rejects.toThrow();

      expect(tokenService.signAccessToken).not.toHaveBeenCalled();
      expect(prismaService.refreshToken.create).not.toHaveBeenCalled();
    });
  });

  describe('getCurrentUser', () => {
    it('returns the registered user for a valid id', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com'
      });

      const user = await authService.getCurrentUser('user-1');

      expect(user).toEqual({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com'
      });
      expect(prismaService.user.findUnique).toHaveBeenCalledWith({
        where: { id: 'user-1' }
      });
    });

    it('throws 401 when the user no longer exists', async () => {
      prismaService.user.findUnique.mockResolvedValue(null);

      await expect(authService.getCurrentUser('ghost')).rejects.toThrow(
        UnauthorizedException
      );
    });

    it('does not expose passwordHash', async () => {
      prismaService.user.findUnique.mockResolvedValue({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com',
        passwordHash: 'hashed-secret'
      });

      const user = await authService.getCurrentUser('user-1');

      expect(user).not.toHaveProperty('passwordHash');
    });
  });

  describe('refresh', () => {
    const buildRecord = (overrides: Record<string, unknown> = {}) => ({
      id: 'rt-1',
      userId: 'user-1',
      tokenHash: 'refresh-hash',
      expiresAt: new Date(Date.now() + 86_400_000),
      revokedAt: null,
      createdAt: new Date(),
      ...overrides
    });

    beforeEach(() => {
      tokenService.hashRefreshToken.mockReturnValue('refresh-hash');
      tokenService.signAccessToken.mockReturnValue('new-access-token');
      prismaService.refreshToken.findUnique.mockResolvedValue(buildRecord());
      prismaService.user.findUnique.mockResolvedValue({
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com'
      });
    });

    it('returns a new access token for a valid refresh token', async () => {
      const result = await authService.refresh('refresh-plaintext');

      expect(result.accessToken).toBe('new-access-token');
    });

    it('hashes the token and looks it up by tokenHash', async () => {
      await authService.refresh('refresh-plaintext');

      expect(tokenService.hashRefreshToken).toHaveBeenCalledWith('refresh-plaintext');
      expect(prismaService.refreshToken.findUnique).toHaveBeenCalledWith({
        where: { tokenHash: 'refresh-hash' }
      });
    });

    it('signs the new access token with the user payload', async () => {
      await authService.refresh('refresh-plaintext');

      expect(tokenService.signAccessToken).toHaveBeenCalledWith({
        userId: 'user-1',
        username: 'ranger'
      });
    });

    it('rejects an unknown refresh token with 401', async () => {
      prismaService.refreshToken.findUnique.mockResolvedValue(null);

      await expect(
        authService.refresh('refresh-plaintext')
      ).rejects.toThrow(UnauthorizedException);
    });

    it('rejects a revoked refresh token with 401', async () => {
      prismaService.refreshToken.findUnique.mockResolvedValue(
        buildRecord({ revokedAt: new Date() })
      );

      await expect(
        authService.refresh('refresh-plaintext')
      ).rejects.toThrow(UnauthorizedException);
    });

    it('rejects an expired refresh token with 401', async () => {
      prismaService.refreshToken.findUnique.mockResolvedValue(
        buildRecord({ expiresAt: new Date(Date.now() - 86_400_000) })
      );

      await expect(
        authService.refresh('refresh-plaintext')
      ).rejects.toThrow(UnauthorizedException);
    });

    it('rejects when the user no longer exists with 401', async () => {
      prismaService.user.findUnique.mockResolvedValue(null);

      await expect(
        authService.refresh('refresh-plaintext')
      ).rejects.toThrow(UnauthorizedException);
    });

    it('does not issue a new access token when the refresh token is invalid', async () => {
      prismaService.refreshToken.findUnique.mockResolvedValue(null);

      await expect(
        authService.refresh('refresh-plaintext')
      ).rejects.toThrow();

      expect(tokenService.signAccessToken).not.toHaveBeenCalled();
    });
  });

  describe('logout', () => {
    beforeEach(() => {
      tokenService.hashRefreshToken.mockReturnValue('refresh-hash');
    });

    it('revokes a valid refresh token by setting revokedAt', async () => {
      prismaService.refreshToken.findUnique.mockResolvedValue({
        id: 'rt-1',
        revokedAt: null
      });

      await authService.logout('refresh-plaintext');

      expect(prismaService.refreshToken.update).toHaveBeenCalledWith({
        where: { id: 'rt-1' },
        data: { revokedAt: expect.any(Date) }
      });
    });

    it('does not call update when the refresh token does not exist', async () => {
      prismaService.refreshToken.findUnique.mockResolvedValue(null);

      await authService.logout('refresh-plaintext');

      expect(prismaService.refreshToken.update).not.toHaveBeenCalled();
    });

    it('is idempotent when the token is already revoked', async () => {
      prismaService.refreshToken.findUnique.mockResolvedValue({
        id: 'rt-1',
        revokedAt: new Date()
      });

      await authService.logout('refresh-plaintext');

      expect(prismaService.refreshToken.update).not.toHaveBeenCalled();
    });
  });
});
