import { BadRequestException, Body, Controller, Get, Header, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AccessTokenPayload } from '../auth/auth.types';
import { MediaService } from './media.service';

const DEFAULT_MAX_UPLOAD_SIZE_MB = 20;

/**
 * 返回当前配置下 base64 字符串的允许长度上限.
 * Base64 编码后字节数 = (原文 * 4 / 3) 向上取整 + padding.
 * 此处加 8 字节冗余以容纳 padding 与换行符.
 */
function resolveMaxBase64Length(): number {
  const configured = Number(process.env.MAX_UPLOAD_SIZE_MB);
  const maxMb = Number.isFinite(configured) && configured > 0
    ? Math.floor(configured)
    : DEFAULT_MAX_UPLOAD_SIZE_MB;
  const maxBytes = maxMb * 1024 * 1024;
  return Math.ceil(maxBytes * 4 / 3) + 8;
}

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
    // DoS 防护: 解码前先校验字符串长度, 避免 100MB base64 字符串把内存吃满.
    // Express body-parser 默认 100KB 上限对此请求无效 (Nest 默认 limit 较大).
    const maxBase64Length = resolveMaxBase64Length();
    if (body.base64.length === 0 || body.base64.length > maxBase64Length) {
      throw new BadRequestException('Media payload exceeds the allowed size');
    }
    let bytes: Buffer;
    try {
      bytes = Buffer.from(body.base64, 'base64');
    } catch {
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
