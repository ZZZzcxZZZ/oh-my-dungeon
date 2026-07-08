import { BadRequestException, Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import type { RegisterResult } from './auth.types';

interface RegisterRequestBody {
  username?: unknown;
  email?: unknown;
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
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}
