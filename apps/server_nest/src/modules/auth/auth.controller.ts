import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  UseGuards
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { CurrentUser } from './current-user.decorator';
import { JwtAuthGuard } from './jwt-auth.guard';
import type {
  AccessTokenPayload,
  LoginResult,
  RefreshResult,
  RegisterResult,
  RegisteredUser
} from './auth.types';

interface RegisterRequestBody {
  username?: unknown;
  email?: unknown;
  password?: unknown;
}

interface LoginRequestBody {
  identifier?: unknown;
  password?: unknown;
}

interface RefreshRequestBody {
  refreshToken?: unknown;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() body: RegisterRequestBody): Promise<RegisterResult> {
    if (!isNonEmptyString(body.username)) {
      throw new BadRequestException('Username is required');
    }
    if (!isNonEmptyString(body.password)) {
      throw new BadRequestException('Password is required');
    }
    if (!isNonEmptyString(body.email) || !body.email.includes('@')) {
      throw new BadRequestException('A valid email is required');
    }

    return this.authService.register({
      username: body.username,
      email: body.email,
      password: body.password
    });
  }

  @Post('login')
  @HttpCode(200)
  login(@Body() body: LoginRequestBody): Promise<LoginResult> {
    if (!isNonEmptyString(body.identifier)) {
      throw new BadRequestException('Identifier is required');
    }
    if (!isNonEmptyString(body.password)) {
      throw new BadRequestException('Password is required');
    }

    return this.authService.login({
      identifier: body.identifier,
      password: body.password
    });
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AccessTokenPayload): Promise<RegisteredUser> {
    return this.authService.getCurrentUser(user.userId);
  }

  @Post('refresh')
  @HttpCode(200)
  refresh(@Body() body: RefreshRequestBody): Promise<RefreshResult> {
    if (!isNonEmptyString(body.refreshToken)) {
      throw new BadRequestException('Refresh token is required');
    }
    return this.authService.refresh(body.refreshToken);
  }

  @Post('logout')
  @HttpCode(204)
  logout(@Body() body: RefreshRequestBody): Promise<void> {
    if (!isNonEmptyString(body.refreshToken)) {
      throw new BadRequestException('Refresh token is required');
    }
    return this.authService.logout(body.refreshToken);
  }
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}
