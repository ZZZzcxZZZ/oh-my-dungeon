import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PasswordHashService } from '../src/modules/auth/password-hash.service';

describe('encounters endpoints', () => {
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
    npc: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn()
    },
    encounter: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn()
    },
    encounterParticipant: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn()
    },
    characterCampaignBinding: {
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
    username: 'dm',
    email: 'dm@example.com',
    passwordHash: 'hashed-secret'
  };
  const campaign = {
    id: 'camp-1',
    ownerId: 'user-1',
    members: [{ userId: 'user-1', role: 'owner' }]
  };
  const playerCampaign = {
    id: 'camp-1',
    ownerId: 'user-2',
    members: [
      { userId: 'user-1', role: 'player' },
      { userId: 'user-2', role: 'owner' }
    ]
  };
  const npcRow = {
    id: 'npc-1',
    campaignId: 'camp-1',
    contentItemId: null,
    name: 'Goblin Scout',
    publicDescription: 'Small hostile scout.',
    dmNotes: 'Flees at low HP.',
    stats: { hpMax: 7, armorClass: 15 },
    tags: ['goblin'],
    createdBy: 'user-1',
    createdAt: '2026-07-09T00:00:00.000Z',
    updatedAt: '2026-07-09T00:00:00.000Z'
  };
  const participantA = {
    id: 'part-a',
    encounterId: 'enc-1',
    participantType: 'character',
    characterId: 'char-1',
    npcId: null,
    displayName: 'Arannis',
    initiative: 18,
    hpCurrent: 24,
    hpMax: 24,
    armorClass: 15,
    conditions: [],
    isHiddenFromPlayers: false,
    sortOrder: 0,
    snapshot: {},
    createdAt: '2026-07-09T00:00:00.000Z',
    updatedAt: '2026-07-09T00:00:00.000Z'
  };
  const participantB = {
    ...participantA,
    id: 'part-b',
    participantType: 'npc',
    characterId: null,
    npcId: 'npc-1',
    displayName: 'Goblin Scout',
    initiative: 12,
    hpCurrent: 7,
    hpMax: 7,
    armorClass: 15,
    isHiddenFromPlayers: true,
    sortOrder: 1
  };
  const encounterRow = {
    id: 'enc-1',
    campaignId: 'camp-1',
    sessionId: null,
    name: 'Road Ambush',
    status: 'draft',
    round: 0,
    currentTurnParticipantId: null,
    createdBy: 'user-1',
    createdAt: '2026-07-09T00:00:00.000Z',
    updatedAt: '2026-07-09T00:00:00.000Z',
    participants: [participantA, participantB]
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
    passwordHashService.compare.mockResolvedValue(true);
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService)
    );
    prismaService.campaign.findUnique.mockResolvedValue(null);
    prismaService.npc.create.mockResolvedValue(npcRow);
    prismaService.npc.findMany.mockResolvedValue([]);
    prismaService.npc.findUnique.mockResolvedValue(null);
    prismaService.npc.update.mockResolvedValue(npcRow);
    prismaService.encounter.create.mockResolvedValue(encounterRow);
    prismaService.encounter.findMany.mockResolvedValue([]);
    prismaService.encounter.findUnique.mockResolvedValue(null);
    prismaService.encounter.update.mockResolvedValue(encounterRow);
    prismaService.encounterParticipant.create.mockResolvedValue(participantA);
    prismaService.encounterParticipant.findUnique.mockResolvedValue(null);
    prismaService.encounterParticipant.update.mockResolvedValue(participantA);
    prismaService.characterCampaignBinding.findUnique.mockResolvedValue(null);
    prismaService.journalEntry.create.mockResolvedValue({});
  });

  async function login(): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(storedUser);
    const response = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'dm', password: 'p@ssw0rd' })
      .expect(200);
    return response.body.accessToken;
  }

  it('allows a campaign manager to create an npc', async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);

    await request(app.getHttpServer())
      .post('/api/campaigns/camp-1/npcs')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Goblin Scout',
        publicDescription: 'Small hostile scout.',
        dmNotes: 'Flees at low HP.',
        stats: { hpMax: 7, armorClass: 15 },
        tags: ['goblin']
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.id).toBe('npc-1');
        expect(body.name).toBe('Goblin Scout');
      });

    expect(prismaService.npc.create.mock.calls[0][0].data.createdBy).toBe(
      'user-1'
    );
  });

  it('rejects npc creation for a player', async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(playerCampaign);

    await request(app.getHttpServer())
      .post('/api/campaigns/camp-1/npcs')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Goblin Scout' })
      .expect(403);
  });

  it('creates an encounter for a campaign manager', async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.encounter.create.mockResolvedValueOnce({
      ...encounterRow,
      participants: []
    });

    await request(app.getHttpServer())
      .post('/api/campaigns/camp-1/encounters')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Road Ambush' })
      .expect(201)
      .expect(({ body }) => {
        expect(body.id).toBe('enc-1');
        expect(body.name).toBe('Road Ambush');
      });

    expect(prismaService.encounter.create.mock.calls[0][0].data.status).toBe(
      'draft'
    );
  });

  it('adds a character participant to an encounter', async () => {
    const token = await login();
    prismaService.encounter.findUnique.mockResolvedValueOnce({
      ...encounterRow,
      campaign
    });
    prismaService.characterCampaignBinding.findUnique.mockResolvedValueOnce({
      character: {
        id: 'char-1',
        name: 'Arannis',
        currentHp: 24,
        maxHp: 24,
        armorClass: 15
      }
    });

    await request(app.getHttpServer())
      .post('/api/encounters/enc-1/participants')
      .set('Authorization', `Bearer ${token}`)
      .send({
        participantType: 'character',
        characterId: 'char-1',
        initiative: 18
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.characterId).toBe('char-1');
        expect(body.displayName).toBe('Arannis');
      });
  });

  it('filters hidden participants when a player views an encounter', async () => {
    const token = await login();
    prismaService.encounter.findUnique.mockResolvedValueOnce({
      ...encounterRow,
      campaign: playerCampaign
    });

    await request(app.getHttpServer())
      .get('/api/encounters/enc-1')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body.participants).toHaveLength(1);
        expect(body.participants[0].id).toBe('part-a');
      });
  });

  it('starts an encounter and writes journal', async () => {
    const token = await login();
    prismaService.encounter.findUnique.mockResolvedValueOnce({
      ...encounterRow,
      campaign
    });
    prismaService.encounter.update.mockResolvedValueOnce({
      ...encounterRow,
      status: 'active',
      round: 1,
      currentTurnParticipantId: 'part-a'
    });

    await request(app.getHttpServer())
      .post('/api/encounters/enc-1/start')
      .set('Authorization', `Bearer ${token}`)
      .expect(201)
      .expect(({ body }) => {
        expect(body.status).toBe('active');
        expect(body.round).toBe(1);
        expect(body.currentTurnParticipantId).toBe('part-a');
      });

    expect(prismaService.journalEntry.create.mock.calls[0][0].data.type).toBe(
      'encounter_started'
    );
  });

  it('advances turn order and increments round after the last participant', async () => {
    const token = await login();
    prismaService.encounter.findUnique.mockResolvedValueOnce({
      ...encounterRow,
      status: 'active',
      round: 1,
      currentTurnParticipantId: 'part-b',
      campaign
    });
    prismaService.encounter.update.mockResolvedValueOnce({
      ...encounterRow,
      status: 'active',
      round: 2,
      currentTurnParticipantId: 'part-a'
    });

    await request(app.getHttpServer())
      .post('/api/encounters/enc-1/advance-turn')
      .set('Authorization', `Bearer ${token}`)
      .expect(201)
      .expect(({ body }) => {
        expect(body.round).toBe(2);
        expect(body.currentTurnParticipantId).toBe('part-a');
      });
  });

  it('updates participant hp and conditions and writes journal', async () => {
    const token = await login();
    prismaService.encounter.findUnique.mockResolvedValueOnce({
      ...encounterRow,
      campaign
    });
    prismaService.encounterParticipant.findUnique.mockResolvedValueOnce({
      ...participantB,
      encounter: { ...encounterRow, campaign }
    });
    prismaService.encounterParticipant.update.mockResolvedValueOnce({
      ...participantB,
      hpCurrent: 3,
      conditions: ['poisoned']
    });

    await request(app.getHttpServer())
      .patch('/api/encounters/enc-1/participants/part-b')
      .set('Authorization', `Bearer ${token}`)
      .send({ hpCurrent: 3, conditions: ['poisoned'] })
      .expect(200)
      .expect(({ body }) => {
        expect(body.hpCurrent).toBe(3);
        expect(body.conditions).toEqual(['poisoned']);
      });

    expect(prismaService.journalEntry.create.mock.calls[0][0].data.type).toBe(
      'encounter_participant_updated'
    );
  });
});
