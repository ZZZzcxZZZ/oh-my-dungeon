import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { VaultService } from "./vault.service";
import type {
  VaultChangePage,
  VaultDeviceView,
  VaultPushOperation,
  VaultPushResult,
} from "./vault.types";

interface PushBody {
  operations?: unknown;
}

@Controller("vault")
@UseGuards(JwtAuthGuard)
export class VaultController {
  constructor(private readonly vaultService: VaultService) {}

  @Post("push")
  @HttpCode(200)
  async push(
    @CurrentUser() user: AccessTokenPayload,
    @Headers("x-device-id") deviceHeader: string | undefined,
    @Body() body: PushBody,
  ): Promise<VaultPushResult> {
    const deviceId = extractDeviceId(deviceHeader);
    const operations = parseOperations(body.operations);
    const result = await this.vaultService.push(
      user.userId,
      deviceId,
      operations,
    );
    if (result.conflicts.length > 0) {
      throw new ConflictException(result);
    }
    return result;
  }

  @Get("changes")
  async getChanges(
    @CurrentUser() user: AccessTokenPayload,
    @Headers("x-device-id") deviceHeader: string | undefined,
    @Query("cursor") cursor: string | undefined,
  ): Promise<VaultChangePage> {
    const deviceId = extractDeviceId(deviceHeader);
    return this.vaultService.getChanges(user.userId, deviceId, cursor ?? "0");
  }

  @Get("devices")
  async listDevices(
    @CurrentUser() user: AccessTokenPayload,
    @Headers("x-device-id") deviceHeader: string | undefined,
  ): Promise<VaultDeviceView[]> {
    extractDeviceId(deviceHeader);
    return this.vaultService.listDevices(user.userId);
  }

  @Delete("devices/:deviceId")
  @HttpCode(204)
  async revokeDevice(
    @CurrentUser() user: AccessTokenPayload,
    @Headers("x-device-id") deviceHeader: string | undefined,
    @Param("deviceId") targetDeviceId: string,
  ): Promise<void> {
    const deviceId = extractDeviceId(deviceHeader);
    await this.vaultService.revokeDevice(
      user.userId,
      deviceId,
      targetDeviceId,
    );
  }
}

function extractDeviceId(header: string | undefined): string {
  if (!header || typeof header !== "string" || header.trim().length === 0) {
    throw new BadRequestException("X-Device-Id header is required");
  }
  return header.trim();
}

function parseOperations(value: unknown): VaultPushOperation[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value as VaultPushOperation[];
}
