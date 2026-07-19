import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PasswordHashService } from '../src/modules/auth/password-hash.service';

describe('check request endpoints', () => {
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
    session: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn()
    },
    sessionMember: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn()
    },
    chatMessage: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn()
    },
    diceRoll: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn()
    },
    journalEntry: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn()
    },
    checkRequest: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn()
    },
    checkResponse: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn()
    },
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }])
  };
  const passwordHashService = {
    hash: jest.fn().mockResolvedValue('hashed-secret'),
    compare: jest.fn()
  };

  const dmUser = {
    id: 'user-1',
    username: 'dm',
    email: 'dm@example.com',
    passwordHash: 'hashed-secret'
  };
  const playerUser = {
    id: 'user-2',
    username: 'player',
    email: 'player@example.com',
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
    prismaService.user.count.mockResolvedValue(2);
    prismaService.user.findFirst.mockResolvedValue(null);
    prismaService.user.findUnique.mockResolvedValue(null);
    prismaService.user.create.mockResolvedValue(dmUser);
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.refreshToken.create.mockResolvedValue({});
    prismaService.refreshToken.findUnique.mockResolvedValue(null);
    prismaService.refreshToken.update.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService)
    );
    passwordHashService.hash.mockResolvedValue('hashed-secret');
    passwordHashService.compare.mockResolvedValue(true);
    prismaService.campaign.findUnique.mockResolvedValue(null);
    prismaService.session.findUnique.mockResolvedValue(null);
    prismaService.checkRequest.create.mockResolvedValue(checkRequestRow);
    prismaService.checkRequest.findUnique.mockResolvedValue(null);
    prismaService.checkRequest.findMany.mockResolvedValue([]);
    prismaService.checkRequest.update.mockResolvedValue({
      ...checkRequestRow,
      status: 'closed'
    });
    prismaService.checkResponse.create.mockResolvedValue(checkResponseRow);
    prismaService.checkResponse.findUnique.mockResolvedValue(null);
    prismaService.checkResponse.findFirst.mockResolvedValue(null);
    prismaService.checkResponse.findMany.mockResolvedValue([]);
    prismaService.chatMessage.create.mockResolvedValue({});
    prismaService.diceRoll.create.mockResolvedValue({
      id: 'roll-1',
      sessionId: 'sess-1',
      actorId: 'user-2',
      actorName: 'Ireena',
      notation: '1d20+2',
      total: 17,
      components: [{ notation: '1d20', results: [15] }],
      visibility: 'public',
      createdAt: '2026-07-09T00:00:00.000Z'
    });
    prismaService.journalEntry.create.mockResolvedValue({});
  });

  async function loginAs(user: typeof dmUser): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(user);
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: user.username, password: 'p@ssw0rd' })
      .expect(200);
    return login.body.accessToken;
  }

  it('lets a dm create an all-player perception check request', async () => {
    const token = await loginAs(dmUser);
    prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);

    const response = await request(app.getHttpServer())
      .post('/api/sessions/sess-1/check-requests')
      .set('Authorization', `Bearer ${token}`)
      .send({
        label: 'Perception',
        checkType: 'skill',
        skill: 'perception',
        dc: 15,
        dcVisibility: 'public',
        targetMode: 'all'
      })
      .expect(201);

    expect(response.body).toMatchObject({
      id: 'check-1',
      sessionId: 'sess-1',
      label: 'Perception',
      dc: 15,
      targetMode: 'all',
      status: 'open',
      responses: []
    });
    expect(prismaService.checkRequest.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          sessionId: 'sess-1',
          requestedBy: 'user-1',
          label: 'Perception'
        })
      })
    );
  });

  it('lets a player list visible check requests', async () => {
    const token = await loginAs(playerUser);
    prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
    prismaService.checkRequest.findMany.mockResolvedValueOnce([
      { ...checkRequestRow, responses: [] }
    ]);

    const response = await request(app.getHttpServer())
      .get('/api/sessions/sess-1/check-requests')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body).toHaveLength(1);
    expect(response.body[0]).toMatchObject({
      id: 'check-1',
      label: 'Perception',
      dc: 15
    });
  });

  it('lets a player respond once and writes roll, chat, and journal rows', async () => {
    const randomSpy = jest.spyOn(Math, 'random').mockReturnValue(0.7);
    const token = await loginAs(playerUser);
    prismaService.checkRequest.findUnique.mockResolvedValueOnce({
      ...checkRequestRow,
      session: sessionRow,
      responses: []
    });

    const response = await request(app.getHttpServer())
      .post('/api/check-requests/check-1/responses')
      .set('Authorization', `Bearer ${token}`)
      .send({ actorName: 'Ireena', modifier: 2 })
      .expect(201);

    expect(response.body).toMatchObject({
      requestId: 'check-1',
      responderId: 'user-2',
      notation: '1d20+2',
      total: 17,
      result: 'success'
    });
    expect(prismaService.diceRoll.create).toHaveBeenCalled();
    expect(prismaService.chatMessage.create).toHaveBeenCalled();
    expect(prismaService.journalEntry.create).toHaveBeenCalled();
    randomSpy.mockRestore();
  });

  it('rejects duplicate player responses', async () => {
    const token = await loginAs(playerUser);
    prismaService.checkRequest.findUnique.mockResolvedValueOnce({
      ...checkRequestRow,
      session: sessionRow,
      responses: [{ ...checkResponseRow, responderId: 'user-2' }]
    });

    await request(app.getHttpServer())
      .post('/api/check-requests/check-1/responses')
      .set('Authorization', `Bearer ${token}`)
      .send({ actorName: 'Ireena', modifier: 2 })
      .expect(409);
  });

  it('rejects responses from users outside explicit targets', async () => {
    const token = await loginAs(playerUser);
    prismaService.checkRequest.findUnique.mockResolvedValueOnce({
      ...checkRequestRow,
      targetMode: 'users',
      targetUserIds: ['user-3'],
      session: sessionRow,
      responses: []
    });

    await request(app.getHttpServer())
      .post('/api/check-requests/check-1/responses')
      .set('Authorization', `Bearer ${token}`)
      .send({ actorName: 'Ireena', modifier: 2 })
      .expect(403);
  });

  it('lets a dm close a check request', async () => {
    const token = await loginAs(dmUser);
    prismaService.checkRequest.findUnique.mockResolvedValueOnce({
      ...checkRequestRow,
      session: sessionRow,
      responses: []
    });

    const response = await request(app.getHttpServer())
      .post('/api/check-requests/check-1/close')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(response.body.status).toBe('closed');
    expect(prismaService.checkRequest.update).toHaveBeenCalledWith({
      where: { id: 'check-1' },
      data: { status: 'closed' },
      include: { responses: true }
    });
  });
});

const campaignRow = {
  id: 'camp-1',
  name: 'Curse of Strahd',
  description: '',
  system: 'dnd5e',
  ownerId: 'user-1',
  status: 'active',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  members: [
    { userId: 'user-1', role: 'owner' },
    { userId: 'user-2', role: 'player' }
  ]
};

const sessionRow = {
  id: 'sess-1',
  campaignId: 'camp-1',
  name: 'Session 1',
  status: 'active',
  startedAt: '2026-07-09T00:00:00.000Z',
  endedAt: null,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  campaign: campaignRow,
  members: [
    {
      id: 'sm-1',
      sessionId: 'sess-1',
      userId: 'user-1',
      role: 'owner',
      joinedAt: '2026-07-09T00:00:00.000Z',
      leftAt: null
    },
    {
      id: 'sm-2',
      sessionId: 'sess-1',
      userId: 'user-2',
      role: 'player',
      joinedAt: '2026-07-09T00:00:00.000Z',
      leftAt: null
    }
  ]
};

const checkRequestRow = {
  id: 'check-1',
  sessionId: 'sess-1',
  requestedBy: 'user-1',
  label: 'Perception',
  checkType: 'skill',
  ability: null,
  skill: 'perception',
  dc: 15,
  dcVisibility: 'public',
  targetMode: 'all',
  targetUserIds: [],
  targetCharacterIds: [],
  status: 'open',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  responses: []
};

const checkResponseRow = {
  id: 'response-1',
  requestId: 'check-1',
  responderId: 'user-2',
  characterId: null,
  notation: '1d20+2',
  total: 17,
  components: [{ notation: '1d20', results: [15] }],
  result: 'success',
  createdAt: '2026-07-09T00:00:00.000Z'
};
