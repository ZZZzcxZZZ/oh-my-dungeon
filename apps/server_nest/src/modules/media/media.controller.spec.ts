import { BadRequestException } from '@nestjs/common';
import { MediaController } from './media.controller';

describe('MediaController', () => {
  const media = {
    upload: jest.fn(),
    readForUser: jest.fn(),
  };
  const user = { userId: 'user-1', username: 'tester' };

  beforeEach(() => {
    jest.resetAllMocks();
    media.upload.mockResolvedValue({ id: 'asset-1' });
  });

  it('rejects malformed base64 instead of silently decoding it', async () => {
    const controller = new MediaController(media as never);

    await expect(
      controller.upload(user, {
        purpose: 'avatar',
        mimeType: 'image/png',
        base64: 'valid-prefix%%%invalid',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(media.upload).not.toHaveBeenCalled();
  });

  it('accepts canonical padded base64 and passes exact bytes to storage', async () => {
    const controller = new MediaController(media as never);

    await controller.upload(user, {
      purpose: 'avatar',
      mimeType: 'image/png',
      base64: 'iVBORw==',
    });

    expect(media.upload).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({ bytes: Buffer.from([0x89, 0x50, 0x4e, 0x47]) }),
    );
  });
});
