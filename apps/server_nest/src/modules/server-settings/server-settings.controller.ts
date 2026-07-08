import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Patch,
  UseGuards
} from '@nestjs/common';
import { ServerSettingsService } from './server-settings.service';
import type { ServerSettingsView, UpdateServerSettingsInput } from './server-settings.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AccessTokenPayload } from '../auth/auth.types';

interface UpdateServerSettingsRequestBody {
  registrationEnabled?: unknown;
}

@Controller('server-settings')
export class ServerSettingsController {
  constructor(private readonly serverSettingsService: ServerSettingsService) {}

  @Get()
  getSettings(): Promise<ServerSettingsView> {
    return this.serverSettingsService.getSettings();
  }

  @Patch()
  @UseGuards(JwtAuthGuard)
  updateSettings(
    @CurrentUser() user: AccessTokenPayload,
    @Body() body: UpdateServerSettingsRequestBody
  ): Promise<ServerSettingsView> {
    if (typeof body.registrationEnabled !== 'boolean') {
      throw new BadRequestException('registrationEnabled must be a boolean');
    }
    const input: UpdateServerSettingsInput = {
      registrationEnabled: body.registrationEnabled
    };
    return this.serverSettingsService.updateSettings(user.userId, input);
  }
}
