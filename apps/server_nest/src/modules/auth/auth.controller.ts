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
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}
