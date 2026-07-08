import { UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import { TokenService } from './token.service';

describe('TokenService', () => {
  let tokenService: TokenService;
  const configService = { get: jest.fn() };

  beforeEach(() => {
    jest.clearAllMocks();
    configService.get.mockImplementation((key: string) =>
      key === 'JWT_SECRET' ? 'test-secret' : undefined
    );
    tokenService = new TokenService(configService as any);
  });

  describe('signAccessToken / verifyAccessToken', () => {
    it('round-trips the access token payload', () => {
      const token = tokenService.signAccessToken({
        userId: 'user-1',
        username: 'ranger'
      });

      expect(tokenService.verifyAccessToken(token)).toEqual({
        userId: 'user-1',
        username: 'ranger'
      });
    });

    it('rejects a tampered token', () => {
      const token = tokenService.signAccessToken({
        userId: 'user-1',
        username: 'ranger'
      });

      expect(() =>
        tokenService.verifyAccessToken(`${token}tampered`)
      ).toThrow(UnauthorizedException);
    });

    it('rejects a token signed with a different secret', () => {
      configService.get.mockReturnValueOnce('other-secret');
      const token = tokenService.signAccessToken({
        userId: 'user-1',
        username: 'ranger'
      });

      configService.get.mockReturnValue('test-secret');
      expect(() => tokenService.verifyAccessToken(token)).toThrow(
        UnauthorizedException
      );
    });

    it('rejects a token missing required claims', () => {
      const token = jwt.sign({ foo: 'bar' }, 'test-secret');

      expect(() => tokenService.verifyAccessToken(token)).toThrow(
        UnauthorizedException
      );
    });
  });

  describe('refresh token', () => {
    it('generates a plaintext token and a distinct hash', () => {
      const { token, tokenHash } = tokenService.generateRefreshToken();

      expect(token).toEqual(expect.any(String));
      expect(token.length).toBeGreaterThan(0);
      expect(tokenHash).toEqual(expect.any(String));
      expect(tokenHash).not.toBe(token);
    });

    it('hashes the same token deterministically', () => {
      const { token, tokenHash } = tokenService.generateRefreshToken();

      expect(tokenService.hashRefreshToken(token)).toBe(tokenHash);
    });

    it('produces unique tokens', () => {
      const first = tokenService.generateRefreshToken();
      const second = tokenService.generateRefreshToken();

      expect(first.token).not.toBe(second.token);
      expect(first.tokenHash).not.toBe(second.tokenHash);
    });

    it('sets the refresh expiry 30 days ahead', () => {
      const now = new Date('2026-07-09T00:00:00Z');
      const expiresAt = tokenService.refreshExpiresAt(now);

      const expected = new Date('2026-08-08T00:00:00Z');
      expect(expiresAt.toISOString()).toBe(expected.toISOString());
    });
  });
});
