import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes } from 'crypto';
import * as jwt from 'jsonwebtoken';
import type { AccessTokenPayload } from './auth.types';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL_DAYS = 30;
const REFRESH_TOKEN_BYTES = 48;

@Injectable()
export class TokenService {
  constructor(private readonly configService: ConfigService) {}

  signAccessToken(payload: AccessTokenPayload): string {
    return jwt.sign(payload, this.getJwtSecret(), {
      expiresIn: ACCESS_TOKEN_TTL
    });
  }

  verifyAccessToken(token: string): AccessTokenPayload {
    try {
      const payload = jwt.verify(token, this.getJwtSecret());
      if (
        typeof payload === 'object' &&
        payload !== null &&
        typeof (payload as any).userId === 'string' &&
        typeof (payload as any).username === 'string'
      ) {
        return {
          userId: (payload as any).userId,
          username: (payload as any).username
        };
      }
      throw new UnauthorizedException('Invalid access token');
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('Invalid access token');
    }
  }

  generateRefreshToken(): { token: string; tokenHash: string } {
    const token = randomBytes(REFRESH_TOKEN_BYTES).toString('base64url');
    return { token, tokenHash: this.hashRefreshToken(token) };
  }

  hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  refreshExpiresAt(now: Date = new Date()): Date {
    const expiresAt = new Date(now);
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_TTL_DAYS);
    return expiresAt;
  }

  private getJwtSecret(): string {
    const secret = this.configService.get<string>('JWT_SECRET');
    if (!secret) {
      throw new UnauthorizedException('JWT secret is not configured');
    }
    return secret;
  }
}
