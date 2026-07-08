import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException
} from '@nestjs/common';
import { TokenService } from './token.service';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly tokenService: TokenService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const authHeader: string | undefined = request.headers?.authorization;
    const token = this.extractBearerToken(authHeader);
    const payload = this.tokenService.verifyAccessToken(token);
    request.user = payload;
    return true;
  }

  private extractBearerToken(header: string | undefined): string {
    if (!header || typeof header !== 'string') {
      throw new UnauthorizedException('Missing access token');
    }
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) {
      throw new UnauthorizedException('Missing access token');
    }
    return match[1];
  }
}
