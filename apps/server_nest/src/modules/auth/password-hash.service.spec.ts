import { PasswordHashService } from './password-hash.service';

describe('PasswordHashService', () => {
  let service: PasswordHashService;

  beforeEach(() => {
    service = new PasswordHashService();
  });

  describe('hash', () => {
    it('returns a non-empty string that is not the plaintext password', async () => {
      const password = 'correct horse battery staple';
      const hash = await service.hash(password);

      expect(typeof hash).toBe('string');
      expect(hash.length).toBeGreaterThan(0);
      expect(hash).not.toBe(password);
    });

    it('produces different hashes for the same password (salted)', async () => {
      const password = 'hunter2';
      const first = await service.hash(password);
      const second = await service.hash(password);

      expect(first).not.toBe(second);
    });
  });

  describe('compare', () => {
    it('returns true for the correct password', async () => {
      const password = 's3cret-pass';
      const hash = await service.hash(password);

      expect(await service.compare(password, hash)).toBe(true);
    });

    it('returns false for an incorrect password', async () => {
      const hash = await service.hash('the-right-password');

      expect(await service.compare('the-wrong-password', hash)).toBe(false);
    });
  });
});
