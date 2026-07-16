import { BadRequestException, Body, Controller, Get, Header, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AccessTokenPayload } from '../auth/auth.types';
import { MediaService } from './media.service';

@Controller('media')
@UseGuards(JwtAuthGuard)
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post()
  async upload(
    @CurrentUser() user: AccessTokenPayload,
    @Body() body: { purpose?: unknown; mimeType?: unknown; base64?: unknown; campaignId?: unknown },
  ) {
    if ((body.purpose !== 'avatar' && body.purpose !== 'campaignFile') || typeof body.mimeType !== 'string' || typeof body.base64 !== 'string') {
      throw new BadRequestException('purpose, mimeType and base64 are required');
    }
    if (body.campaignId !== undefined && typeof body.campaignId !== 'string') {
      throw new BadRequestException('campaignId must be a string');
    }
    let bytes: Buffer;
    try {
      bytes = Buffer.from(body.base64, 'base64');
    } catch (_) {
      throw new BadRequestException('Invalid base64 payload');
    }
    return this.media.upload(user.userId, {
      purpose: body.purpose,
      mimeType: body.mimeType,
      bytes,
      campaignId: body.campaignId,
    });
  }

  @Get(':assetId')
  @Header('cache-control', 'private, max-age=31536000, immutable')
  async read(@CurrentUser() user: AccessTokenPayload, @Param('assetId') assetId: string) {
    const { asset, bytes } = await this.media.readForUser(user.userId, assetId);
    return { id: asset.id, mimeType: asset.mimeType, base64: bytes.toString('base64') };
  }
}
