import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { MediaService } from './media.service';

describe('MediaService', () => {
  const prisma = {
    mediaAsset: {
      create: jest.fn(),
      findUnique: jest.fn(),
    },
    campaignMember: { findFirst: jest.fn() },
  };
  let root = '';

  beforeEach(async () => {
    jest.clearAllMocks();
    root = await mkdtemp(join(tmpdir(), 'dnd-media-'));
    prisma.mediaAsset.create.mockImplementation(async ({ data }) => ({
      id: 'asset-1',
      ...data,
      createdAt: new Date('2026-07-16T00:00:00.000Z'),
    }));
  });

  afterEach(async () => rm(root, { recursive: true, force: true }));

  it('stores a supported image by immutable asset id instead of its client filename', async () => {
    const service = new MediaService(prisma as never, root);

    const asset = await service.upload('user-1', {
      purpose: 'avatar',
      mimeType: 'image/png',
      bytes: Buffer.from([0x89, 0x50, 0x4e, 0x47]),
    });

    expect(asset.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(asset.storageKey).toBe(`${asset.id}.png`);
    expect(await readFile(join(root, asset.storageKey))).toEqual(
      Buffer.from([0x89, 0x50, 0x4e, 0x47]),
    );
  });

  it('rejects an unsupported mime type before writing a file', async () => {
    const service = new MediaService(prisma as never, root);

    await expect(
      service.upload('user-1', {
        purpose: 'avatar',
        mimeType: 'image/svg+xml',
        bytes: Buffer.from('<svg/>'),
      }),
    ).rejects.toThrow('Unsupported media type');
  });

  it('requires campaign membership before a file can enter campaign storage', async () => {
    prisma.campaignMember.findFirst.mockResolvedValue(null);
    const service = new MediaService(prisma as never, root);

    await expect(
      service.upload('user-2', {
        purpose: 'campaignFile',
        campaignId: 'camp-1',
        mimeType: 'application/pdf',
        bytes: Buffer.from('%PDF'),
      }),
    ).rejects.toThrow('Campaign membership required');
  });
});
