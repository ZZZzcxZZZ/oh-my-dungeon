import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PasswordHashService } from '../src/modules/auth/password-hash.service';

describe('campaigns endpoints', () => {
  let app: INestApplication;
  const prismaService = {
    user: {
      count: jest.fn(),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn()
    },
    serverAdmin: {
      create: jest.fn(),
      findUnique: jest.fn()
    },
    serverSetting: {
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn()
    },
    refreshToken: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn()
    },
    campaign: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn()
    },
    campaignMember: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn()
    },
    campaignInvite: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn()
    },
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }])
  };
  const passwordHashService = {
    hash: jest.fn().mockResolvedValue('hashed-secret'),
    compare: jest.fn()
  };
  const storedDmUser = {
    id: 'user-1',
    username: 'ranger',
    email: 'ranger@example.com',
    passwordHash: 'hashed-secret'
  };

  beforeAll(async () => {
    process.env.JWT_SECRET = 'test-secret';
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule]
    })
      .overrideProvider(PrismaService)
      .useValue(prismaService)
      .overrideProvider(PasswordHashService)
      .useValue(passwordHashService)
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api', {
      exclude: ['health', '.well-known/dnd-tool-server']
    });
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    prismaService.$queryRaw.mockResolvedValue([{ health_check: 1 }]);
    prismaService.serverSetting.findFirst.mockResolvedValue({
      registrationEnabled: true
    });
    prismaService.user.count.mockResolvedValue(1);
    prismaService.user.findFirst.mockResolvedValue(null);
    prismaService.user.findUnique.mockResolvedValue(null);
    prismaService.user.create.mockResolvedValue(storedDmUser);
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.refreshToken.create.mockResolvedValue({});
    prismaService.refreshToken.findUnique.mockResolvedValue(null);
    prismaService.refreshToken.update.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService)
    );
    passwordHashService.hash.mockResolvedValue('hashed-secret');
    passwordHashService.compare.mockResolvedValue(true);
    prismaService.campaign.create.mockResolvedValue({
      id: 'camp-1',
      name: 'Curse of Strahd',
      description: '',
      system: 'dnd5e',
      ownerId: 'user-1',
      status: 'active',
      createdAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z'
    });
    prismaService.campaign.findUnique.mockResolvedValue(null);
    prismaService.campaign.findMany.mockResolvedValue([]);
    prismaService.campaignMember.create.mockResolvedValue({});
    prismaService.campaignMember.findUnique.mockResolvedValue(null);
    prismaService.campaignMember.findFirst.mockResolvedValue(null);
    prismaService.campaignMember.findMany.mockResolvedValue([]);
    prismaService.campaignInvite.create.mockResolvedValue({});
    prismaService.campaignInvite.findUnique.mockResolvedValue(null);
    prismaService.campaignInvite.findFirst.mockResolvedValue(null);
    prismaService.campaignInvite.findMany.mockResolvedValue([]);
    prismaService.campaignInvite.update.mockResolvedValue({});
  });

  async function loginAsDm(): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(storedDmUser);
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200);
    return login.body.accessToken;
  }

  describe('POST /api/campaigns', () => {
    it('creates a campaign and returns it without internal fields', async () => {
      const token = await loginAsDm();

      await request(app.getHttpServer())
        .post('/api/campaigns')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Curse of Strahd' })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe('camp-1');
          expect(body.name).toBe('Curse of Strahd');
          expect(body.ownerId).toBe('user-1');
        });

      const createArgs = prismaService.campaign.create.mock.calls[0][0];
      expect(createArgs.data.ownerId).toBe('user-1');
      expect(createArgs.data.name).toBe('Curse of Strahd');
    });

    it('makes the creator an owner member', async () => {
      const token = await loginAsDm();

      await request(app.getHttpServer())
        .post('/api/campaigns')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Curse of Strahd' })
        .expect(201);

      const memberArgs = prismaService.campaignMember.create.mock.calls[0][0];
      expect(memberArgs.data.userId).toBe('user-1');
      expect(memberArgs.data.role).toBe('owner');
    });

    it('rejects without authentication with 401', async () => {
      await request(app.getHttpServer())
        .post('/api/campaigns')
        .send({ name: 'Curse of Strahd' })
        .expect(401);
    });

    it('rejects with missing name with 400', async () => {
      const token = await loginAsDm();

      await request(app.getHttpServer())
        .post('/api/campaigns')
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(400);
    });
  });

  describe('GET /api/campaigns', () => {
    it('returns campaigns the user is a member of', async () => {
      const token = await loginAsDm();
      prismaService.campaignMember.findMany.mockResolvedValueOnce([
        {
          campaignId: 'camp-1',
          campaign: {
            id: 'camp-1',
            name: 'Curse of Strahd',
            description: '',
            system: 'dnd5e',
            ownerId: 'user-1',
            status: 'active',
            createdAt: '2026-07-09T00:00:00.000Z',
            updatedAt: '2026-07-09T00:00:00.000Z'
          }
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/campaigns')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe('camp-1');
          expect(body[0].name).toBe('Curse of Strahd');
        });
    });

    it('rejects without authentication with 401', async () => {
      await request(app.getHttpServer())
        .get('/api/campaigns')
        .expect(401);
    });
  });

  describe('GET /api/campaigns/:id', () => {
    it('returns the campaign for a member', async () => {
      const token = await loginAsDm();
      const campaign = {
        id: 'camp-1',
        name: 'Curse of Strahd',
        description: '',
        system: 'dnd5e',
        ownerId: 'user-1',
        status: 'active',
        createdAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
        members: [{ userId: 'user-1', role: 'owner' }]
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);

      await request(app.getHttpServer())
        .get('/api/campaigns/camp-1')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.id).toBe('camp-1');
          expect(body.name).toBe('Curse of Strahd');
        });
    });

    it('rejects non-members with 403', async () => {
      const token = await loginAsDm();
      const campaign = {
        id: 'camp-1',
        name: 'Curse of Strahd',
        description: '',
        system: 'dnd5e',
        ownerId: 'user-2',
        status: 'active',
        createdAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
        members: [{ userId: 'user-2', role: 'owner' }]
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);

      await request(app.getHttpServer())
        .get('/api/campaigns/camp-1')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });

    it('returns 404 when campaign does not exist', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .get('/api/campaigns/missing')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });
  });

  describe('POST /api/campaigns/:id/invites', () => {
    const campaignWithOwner = {
      id: 'camp-1',
      name: 'Curse of Strahd',
      description: '',
      system: 'dnd5e',
      ownerId: 'user-1',
      status: 'active',
      createdAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z',
      members: [{ userId: 'user-1', role: 'owner' }]
    };

    it('creates an invite and returns it without internal fields', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaignWithOwner);
      prismaService.campaignInvite.create.mockResolvedValueOnce({
        id: 'invite-1',
        campaignId: 'camp-1',
        code: 'ABC123XYZ',
        roleOnJoin: 'player',
        expiresAt: null,
        maxUses: 1,
        usedCount: 0,
        requireApproval: false,
        createdBy: 'user-1',
        createdAt: '2026-07-09T00:00:00.000Z'
      });

      await request(app.getHttpServer())
        .post('/api/campaigns/camp-1/invites')
        .set('Authorization', `Bearer ${token}`)
        .send({ roleOnJoin: 'player', maxUses: 1 })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe('invite-1');
          expect(body.campaignId).toBe('camp-1');
          expect(body.code).toBe('ABC123XYZ');
          expect(body.roleOnJoin).toBe('player');
          expect(body.maxUses).toBe(1);
          expect(body.usedCount).toBe(0);
          expect(body.requireApproval).toBe(false);
          expect(body.expiresAt).toBeNull();
        });

      const createArgs = prismaService.campaignInvite.create.mock.calls[0][0];
      expect(createArgs.data.campaignId).toBe('camp-1');
      expect(createArgs.data.createdBy).toBe('user-1');
      expect(createArgs.data.code).toEqual(expect.any(String));
    });

    it('rejects without authentication with 401', async () => {
      await request(app.getHttpServer())
        .post('/api/campaigns/camp-1/invites')
        .send({ roleOnJoin: 'player' })
        .expect(401);
    });

    it('rejects a non-manager with 403', async () => {
      const token = await loginAsDm();
      const campaignWithPlayerOnly = {
        ...campaignWithOwner,
        ownerId: 'user-2',
        members: [{ userId: 'user-1', role: 'player' }]
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaignWithPlayerOnly);

      await request(app.getHttpServer())
        .post('/api/campaigns/camp-1/invites')
        .set('Authorization', `Bearer ${token}`)
        .send({ roleOnJoin: 'player' })
        .expect(403);
    });

    it('returns 404 when campaign does not exist', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post('/api/campaigns/missing/invites')
        .set('Authorization', `Bearer ${token}`)
        .send({ roleOnJoin: 'player' })
        .expect(404);
    });
  });

  describe('GET /api/campaigns/:id/invites', () => {
    const campaignWithOwner = {
      id: 'camp-1',
      name: 'Curse of Strahd',
      description: '',
      system: 'dnd5e',
      ownerId: 'user-1',
      status: 'active',
      createdAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z',
      members: [{ userId: 'user-1', role: 'owner' }]
    };

    it('returns invites for a manager', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaignWithOwner);
      prismaService.campaignInvite.findMany.mockResolvedValueOnce([
        {
          id: 'invite-1',
          campaignId: 'camp-1',
          code: 'ABC123',
          roleOnJoin: 'player',
          expiresAt: null,
          maxUses: 1,
          usedCount: 0,
          requireApproval: false,
          createdBy: 'user-1',
          createdAt: '2026-07-09T00:00:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/campaigns/camp-1/invites')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe('invite-1');
          expect(body[0].code).toBe('ABC123');
        });
    });

    it('rejects without authentication with 401', async () => {
      await request(app.getHttpServer())
        .get('/api/campaigns/camp-1/invites')
        .expect(401);
    });

    it('rejects a non-manager with 403', async () => {
      const token = await loginAsDm();
      const campaignWithPlayerOnly = {
        ...campaignWithOwner,
        ownerId: 'user-2',
        members: [{ userId: 'user-1', role: 'player' }]
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaignWithPlayerOnly);

      await request(app.getHttpServer())
        .get('/api/campaigns/camp-1/invites')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });
  });
});
