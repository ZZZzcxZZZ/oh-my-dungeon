import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PasswordHashService } from '../src/modules/auth/password-hash.service';

describe('characters endpoints', () => {
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
      findUnique: jest.fn()
    },
    campaignMember: {
      findUnique: jest.fn(),
      findMany: jest.fn()
    },
    character: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn()
    },
    characterCampaignBinding: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn()
    },
    journalEntry: {
      create: jest.fn()
    },
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }])
  };
  const passwordHashService = {
    hash: jest.fn().mockResolvedValue('hashed-secret'),
    compare: jest.fn()
  };
  const storedUser = {
    id: 'user-1',
    username: 'ranger',
    email: 'ranger@example.com',
    passwordHash: 'hashed-secret'
  };
  const campaign = {
    id: 'camp-1',
    ownerId: 'user-1',
    members: [{ userId: 'user-1', role: 'owner' }]
  };
  const characterRow = {
    id: 'char-1',
    ownerUserId: 'user-1',
    name: 'Arannis',
    avatarUrl: null,
    system: 'dnd5e',
    level: 3,
    classSummary: 'Ranger',
    raceSummary: 'Elf',
    currentHp: 24,
    maxHp: 24,
    armorClass: 15,
    speed: 30,
    initiativeBonus: 2,
    abilities: {
      str: 10,
      dex: 14,
      con: 12,
      int: 10,
      wis: 14,
      cha: 8
    },
    saves: {},
    skills: {},
    inventory: [],
    currency: {},
    notes: '',
    data: {},
    createdAt: '2026-07-09T00:00:00.000Z',
    updatedAt: '2026-07-09T00:00:00.000Z'
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
    prismaService.user.create.mockResolvedValue(storedUser);
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.refreshToken.create.mockResolvedValue({});
    prismaService.refreshToken.findUnique.mockResolvedValue(null);
    prismaService.refreshToken.update.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService)
    );
    passwordHashService.compare.mockResolvedValue(true);
    prismaService.campaign.findUnique.mockResolvedValue(null);
    prismaService.campaignMember.findUnique.mockResolvedValue(null);
    prismaService.campaignMember.findMany.mockResolvedValue([]);
    prismaService.character.create.mockResolvedValue(characterRow);
    prismaService.character.findMany.mockResolvedValue([]);
    prismaService.character.findUnique.mockResolvedValue(null);
    prismaService.character.update.mockResolvedValue(characterRow);
    prismaService.characterCampaignBinding.create.mockResolvedValue({
      id: 'bind-1',
      campaignId: 'camp-1',
      characterId: 'char-1',
      userId: 'user-1',
      visibility: 'party',
      status: 'active',
      dmNotes: '',
      joinedAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z'
    });
    prismaService.characterCampaignBinding.findMany.mockResolvedValue([]);
    prismaService.characterCampaignBinding.findUnique.mockResolvedValue(null);
    prismaService.journalEntry.create.mockResolvedValue({});
  });

  async function login(): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(storedUser);
    const response = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200);
    return response.body.accessToken;
  }

  it('creates a character for the current user', async () => {
    const token = await login();

    await request(app.getHttpServer())
      .post('/api/characters')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Arannis',
        level: 3,
        classSummary: 'Ranger',
        raceSummary: 'Elf',
        currentHp: 24,
        maxHp: 24,
        armorClass: 15
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.id).toBe('char-1');
        expect(body.ownerUserId).toBe('user-1');
        expect(body.name).toBe('Arannis');
        expect(body.level).toBe(3);
      });

    const createArgs = prismaService.character.create.mock.calls[0][0];
    expect(createArgs.data.ownerUserId).toBe('user-1');
    expect(createArgs.data.name).toBe('Arannis');
    expect(createArgs.data.system).toBe('dnd5e');
  });

  it('lists characters owned by the current user', async () => {
    const token = await login();
    prismaService.character.findMany.mockResolvedValueOnce([characterRow]);

    await request(app.getHttpServer())
      .get('/api/characters')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0].id).toBe('char-1');
      });

    expect(prismaService.character.findMany.mock.calls[0][0].where).toEqual({
      ownerUserId: 'user-1'
    });
  });

  it('updates an owned character and writes a campaign journal entry when a campaign id is provided', async () => {
    const token = await login();
    prismaService.character.findUnique.mockResolvedValueOnce(characterRow);
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.campaignMember.findUnique.mockResolvedValueOnce({
      id: 'cm-1',
      campaignId: 'camp-1',
      userId: 'user-1',
      role: 'owner'
    });
    prismaService.character.update.mockResolvedValueOnce({
      ...characterRow,
      level: 4,
      currentHp: 30,
      maxHp: 30
    });

    await request(app.getHttpServer())
      .patch('/api/characters/char-1')
      .set('Authorization', `Bearer ${token}`)
      .send({
        campaignId: 'camp-1',
        level: 4,
        currentHp: 30,
        maxHp: 30
      })
      .expect(200)
      .expect(({ body }) => {
        expect(body.id).toBe('char-1');
        expect(body.level).toBe(4);
        expect(body.currentHp).toBe(30);
      });

    const updateArgs = prismaService.character.update.mock.calls[0][0];
    expect(updateArgs.where).toEqual({ id: 'char-1' });
    expect(updateArgs.data.level).toBe(4);
    expect(updateArgs.data.currentHp).toBe(30);
    const journalArgs = prismaService.journalEntry.create.mock.calls[0][0];
    expect(journalArgs.data.campaignId).toBe('camp-1');
    expect(journalArgs.data.type).toBe('character_updated');
    expect(journalArgs.data.refId).toBe('char-1');
  });

  it('binds an owned character to a campaign the user has joined', async () => {
    const token = await login();
    prismaService.character.findUnique.mockResolvedValueOnce(characterRow);
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.campaignMember.findUnique.mockResolvedValueOnce({
      id: 'cm-1',
      campaignId: 'camp-1',
      userId: 'user-1',
      role: 'owner'
    });

    await request(app.getHttpServer())
      .post('/api/characters/char-1/campaign-bindings')
      .set('Authorization', `Bearer ${token}`)
      .send({ campaignId: 'camp-1' })
      .expect(201)
      .expect(({ body }) => {
        expect(body.id).toBe('bind-1');
        expect(body.characterId).toBe('char-1');
        expect(body.campaignId).toBe('camp-1');
      });
  });

  it('lists campaign characters for a campaign manager', async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.characterCampaignBinding.findMany.mockResolvedValueOnce([
      {
        id: 'bind-1',
        campaignId: 'camp-1',
        characterId: 'char-1',
        userId: 'user-1',
        visibility: 'party',
        status: 'active',
        dmNotes: '',
        joinedAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
        character: characterRow
      }
    ]);

    await request(app.getHttpServer())
      .get('/api/campaigns/camp-1/characters')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0].character.id).toBe('char-1');
        expect(body[0].character.name).toBe('Arannis');
      });
  });

  it('allows a campaign manager to adjust character hp and writes journal', async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.characterCampaignBinding.findUnique.mockResolvedValueOnce({
      id: 'bind-1',
      campaignId: 'camp-1',
      characterId: 'char-1',
      userId: 'user-2',
      visibility: 'party',
      status: 'active',
      dmNotes: '',
      character: { ...characterRow, ownerUserId: 'user-2', currentHp: 18 }
    });
    prismaService.character.update.mockResolvedValueOnce({
      ...characterRow,
      ownerUserId: 'user-2',
      currentHp: 12
    });

    await request(app.getHttpServer())
      .post('/api/campaigns/camp-1/characters/char-1/hp')
      .set('Authorization', `Bearer ${token}`)
      .send({ delta: -6 })
      .expect(201)
      .expect(({ body }) => {
        expect(body.id).toBe('char-1');
        expect(body.currentHp).toBe(12);
      });

    const updateArgs = prismaService.character.update.mock.calls[0][0];
    expect(updateArgs.where).toEqual({ id: 'char-1' });
    expect(updateArgs.data.currentHp).toBe(12);
    const journalArgs = prismaService.journalEntry.create.mock.calls[0][0];
    expect(journalArgs.data.campaignId).toBe('camp-1');
    expect(journalArgs.data.type).toBe('character_hp_changed');
    expect(journalArgs.data.summary).toContain('18 -> 12');
  });
});
