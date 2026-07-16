import { BadRequestException, ForbiddenException, Inject, Injectable, NotFoundException, Optional } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { PrismaService } from '../../prisma/prisma.service';

const MIME_EXTENSIONS: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
};
const DEFAULT_MAX_UPLOAD_SIZE_MB = 20;
export const MEDIA_STORAGE_ROOT = 'MEDIA_STORAGE_ROOT';

function resolveMaxBytes(): number {
  const configured = Number(process.env.MAX_UPLOAD_SIZE_MB);
  if (Number.isFinite(configured) && configured > 0) {
    return Math.floor(configured) * 1024 * 1024;
  }
  return DEFAULT_MAX_UPLOAD_SIZE_MB * 1024 * 1024;
}

export interface MediaUploadInput {
  purpose: 'avatar' | 'campaignFile';
  mimeType: string;
  bytes: Buffer;
  campaignId?: string;
}

@Injectable()
export class MediaService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() @Inject(MEDIA_STORAGE_ROOT) private readonly configuredStorageRoot?: string,
  ) {}

  private get storageRoot() {
    return this.configuredStorageRoot ?? process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads');
  }

  async upload(ownerUserId: string, input: MediaUploadInput) {
    const extension = MIME_EXTENSIONS[input.mimeType];
    if (!extension || (input.purpose === 'avatar' && !input.mimeType.startsWith('image/'))) {
      throw new BadRequestException('Unsupported media type');
    }
    const maxBytes = resolveMaxBytes();
    if (input.bytes.length === 0 || input.bytes.length > maxBytes) {
      throw new BadRequestException('Media file exceeds the allowed size');
    }
    if (input.campaignId && !(await this.isCampaignMember(ownerUserId, input.campaignId))) {
      throw new ForbiddenException('Campaign membership required');
    }
    const id = randomUUID();
    const storageKey = `${id}.${extension}`;
    await mkdir(this.storageRoot, { recursive: true });
    await writeFile(join(this.storageRoot, storageKey), input.bytes);
    try {
      return await (this.prisma as any).mediaAsset.create({
        data: {
          id,
          ownerUserId,
          campaignId: input.campaignId ?? null,
          purpose: input.purpose,
          mimeType: input.mimeType,
          byteSize: input.bytes.length,
          storageKey,
          sha256: createHash('sha256').update(input.bytes).digest('hex'),
        },
      });
    } catch (error) {
      await rm(join(this.storageRoot, storageKey), { force: true });
      throw error;
    }
  }

  async readForUser(userId: string, assetId: string): Promise<{ asset: any; bytes: Buffer }> {
    const asset = await (this.prisma as any).mediaAsset.findUnique({ where: { id: assetId } });
    if (!asset) throw new NotFoundException('Media asset not found');
    if (asset.ownerUserId !== userId && !(asset.campaignId && await this.isCampaignMember(userId, asset.campaignId))) {
      throw new NotFoundException('Media asset not found');
    }
    return { asset, bytes: await readFile(join(this.storageRoot, asset.storageKey)) };
  }

  private async isCampaignMember(userId: string, campaignId: string): Promise<boolean> {
    const member = await this.prisma.campaignMember.findFirst({ where: { userId, campaignId } });
    return member != null;
  }
}
