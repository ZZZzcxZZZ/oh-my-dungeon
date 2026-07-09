import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PasswordHashService } from '../src/modules/auth/password-hash.service';
import { SessionsGateway } from '../src/modules/realtime/sessions.gateway';

describe('sessions endpoints', () => {
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
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }])
  };
  const passwordHashService = {
    hash: jest.fn().mockResolvedValue('hashed-secret'),
    compare: jest.fn()
  };
  const sessionsGateway = {
    broadcastToSession: jest.fn(),
    broadcastToSessionManagers: jest.fn()
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
      .overrideProvider(SessionsGateway)
      .useValue(sessionsGateway)
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
    prismaService.campaign.create.mockResolvedValue({});
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
    prismaService.session.create.mockResolvedValue({});
    prismaService.session.findUnique.mockResolvedValue(null);
    prismaService.session.findMany.mockResolvedValue([]);
    prismaService.session.update.mockResolvedValue({});
    prismaService.sessionMember.create.mockResolvedValue({});
    prismaService.sessionMember.findUnique.mockResolvedValue(null);
    prismaService.sessionMember.findFirst.mockResolvedValue(null);
    prismaService.sessionMember.findMany.mockResolvedValue([]);
    prismaService.sessionMember.update.mockResolvedValue({});
    prismaService.chatMessage.create.mockResolvedValue({});
    prismaService.chatMessage.findUnique.mockResolvedValue(null);
    prismaService.chatMessage.findFirst.mockResolvedValue(null);
    prismaService.chatMessage.findMany.mockResolvedValue([]);
    prismaService.chatMessage.update.mockResolvedValue({});
    prismaService.diceRoll.create.mockResolvedValue({});
    prismaService.diceRoll.findUnique.mockResolvedValue(null);
    prismaService.diceRoll.findFirst.mockResolvedValue(null);
    prismaService.diceRoll.findMany.mockResolvedValue([]);
    prismaService.diceRoll.update.mockResolvedValue({});
    prismaService.journalEntry.create.mockResolvedValue({});
    prismaService.journalEntry.findUnique.mockResolvedValue(null);
    prismaService.journalEntry.findFirst.mockResolvedValue(null);
    prismaService.journalEntry.findMany.mockResolvedValue([]);
    prismaService.journalEntry.update.mockResolvedValue({});
  });

  async function loginAsDm(): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(storedDmUser);
    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200);
    return login.body.accessToken;
  }

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

  const sessionRow = {
    id: 'sess-1',
    campaignId: 'camp-1',
    name: 'Session 1: Village of Barovia',
    status: 'scheduled',
    startedAt: null,
    endedAt: null,
    createdAt: '2026-07-09T00:00:00.000Z',
    updatedAt: '2026-07-09T00:00:00.000Z',
    campaign: campaignWithOwner,
    members: [
      { id: 'sm-1', sessionId: 'sess-1', userId: 'user-1', role: 'owner', joinedAt: '2026-07-09T00:00:00.000Z', leftAt: null }
    ]
  };

  describe('POST /api/campaigns/:campaignId/sessions', () => {
    it('creates a session and adds the creator as a session member', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaignWithOwner);
      prismaService.campaignMember.findUnique.mockResolvedValueOnce({
        id: 'cm-1',
        campaignId: 'camp-1',
        userId: 'user-1',
        role: 'owner'
      });
      prismaService.session.create.mockResolvedValueOnce({
        id: 'sess-1',
        campaignId: 'camp-1',
        name: 'Session 1',
        status: 'scheduled',
        startedAt: null,
        endedAt: null,
        createdAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z'
      });

      await request(app.getHttpServer())
        .post('/api/campaigns/camp-1/sessions')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Session 1' })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe('sess-1');
          expect(body.campaignId).toBe('camp-1');
          expect(body.name).toBe('Session 1');
          expect(body.status).toBe('scheduled');
        });

      const createArgs = prismaService.session.create.mock.calls[0][0];
      expect(createArgs.data.campaignId).toBe('camp-1');
      expect(createArgs.data.name).toBe('Session 1');
      const memberArgs = prismaService.sessionMember.create.mock.calls[0][0];
      expect(memberArgs.data.sessionId).toBe('sess-1');
      expect(memberArgs.data.userId).toBe('user-1');
      expect(memberArgs.data.role).toBe('owner');
    });

    it('rejects without authentication with 401', async () => {
      await request(app.getHttpServer())
        .post('/api/campaigns/camp-1/sessions')
        .send({ name: 'Session 1' })
        .expect(401);
    });

    it('rejects with missing name with 400', async () => {
      const token = await loginAsDm();
      await request(app.getHttpServer())
        .post('/api/campaigns/camp-1/sessions')
        .set('Authorization', `Bearer ${token}`)
        .send({})
        .expect(400);
    });

    it('rejects a player with 403', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        ...campaignWithOwner,
        ownerId: 'user-2',
        members: [{ userId: 'user-1', role: 'player' }]
      });

      await request(app.getHttpServer())
        .post('/api/campaigns/camp-1/sessions')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Session 1' })
        .expect(403);
    });

    it('returns 404 when campaign does not exist', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post('/api/campaigns/missing/sessions')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Session 1' })
        .expect(404);
    });
  });

  describe('GET /api/campaigns/:campaignId/sessions', () => {
    it('returns sessions for a campaign member', async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaignWithOwner);
      prismaService.session.findMany.mockResolvedValueOnce([
        {
          id: 'sess-1',
          campaignId: 'camp-1',
          name: 'Session 1',
          status: 'scheduled',
          startedAt: null,
          endedAt: null,
          createdAt: '2026-07-09T00:00:00.000Z',
          updatedAt: '2026-07-09T00:00:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/campaigns/camp-1/sessions')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe('sess-1');
          expect(body[0].name).toBe('Session 1');
        });
    });

    it('rejects without authentication with 401', async () => {
      await request(app.getHttpServer())
        .get('/api/campaigns/camp-1/sessions')
        .expect(401);
    });
  });

  describe('GET /api/sessions/:id', () => {
    it('returns the session with members and recent messages', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.chatMessage.findMany.mockResolvedValueOnce([
        {
          id: 'msg-1',
          sessionId: 'sess-1',
          senderId: 'user-1',
          kind: 'text',
          visibility: 'public',
          content: 'hello',
          createdAt: '2026-07-09T00:00:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.id).toBe('sess-1');
          expect(body.members).toHaveLength(1);
          expect(body.members[0].userId).toBe('user-1');
          expect(body.recentMessages).toHaveLength(1);
          expect(body.recentMessages[0].content).toBe('hello');
        });
    });

    it('rejects non-members with 403', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce({
        ...sessionRow,
        campaign: {
          ...campaignWithOwner,
          ownerId: 'user-2',
          members: [{ userId: 'user-2', role: 'owner' }]
        }
      });

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });

    it('returns 404 when session does not exist', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .get('/api/sessions/missing')
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });

    it('filters dm-visibility recent messages for non-managers', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce({
        ...sessionRow,
        campaign: {
          ...campaignWithOwner,
          ownerId: 'user-2',
          members: [{ userId: 'user-1', role: 'player' }]
        }
      });
      prismaService.chatMessage.findMany.mockResolvedValueOnce([
        {
          id: 'msg-2',
          sessionId: 'sess-1',
          senderId: 'user-2',
          kind: 'text',
          visibility: 'dm',
          content: 'dm note',
          createdAt: '2026-07-09T00:01:00.000Z'
        },
        {
          id: 'msg-1',
          sessionId: 'sess-1',
          senderId: 'user-2',
          kind: 'text',
          visibility: 'public',
          content: 'public note',
          createdAt: '2026-07-09T00:00:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.recentMessages).toHaveLength(1);
          expect(body.recentMessages[0].visibility).toBe('public');
        });
    });
  });

  describe('POST /api/sessions/:id/start', () => {
    it('starts a session and writes a journal entry', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.session.update.mockResolvedValueOnce({
        ...sessionRow,
        status: 'active',
        startedAt: '2026-07-09T01:00:00.000Z'
      });

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/start')
        .set('Authorization', `Bearer ${token}`)
        .expect(201)
        .expect(({ body }) => {
          expect(body.status).toBe('active');
          expect(body.startedAt).toBe('2026-07-09T01:00:00.000Z');
        });

      const updateArgs = prismaService.session.update.mock.calls[0][0];
      expect(updateArgs.data.status).toBe('active');
      expect(updateArgs.data.startedAt).toEqual(expect.any(Date));
      const journalArgs = prismaService.journalEntry.create.mock.calls[0][0];
      expect(journalArgs.data.sessionId).toBe('sess-1');
      expect(journalArgs.data.type).toBe('session_started');
    });

    it('rejects a player with 403', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce({
        ...sessionRow,
        campaign: {
          ...campaignWithOwner,
          ownerId: 'user-2',
          members: [{ userId: 'user-1', role: 'player' }]
        }
      });

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/start')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });
  });

  describe('POST /api/sessions/:id/end', () => {
    it('ends a session and writes a journal entry', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.session.update.mockResolvedValueOnce({
        ...sessionRow,
        status: 'ended',
        endedAt: '2026-07-09T02:00:00.000Z'
      });

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/end')
        .set('Authorization', `Bearer ${token}`)
        .expect(201)
        .expect(({ body }) => {
          expect(body.status).toBe('ended');
          expect(body.endedAt).toBe('2026-07-09T02:00:00.000Z');
        });

      const journalArgs = prismaService.journalEntry.create.mock.calls[0][0];
      expect(journalArgs.data.type).toBe('session_ended');
    });
  });

  describe('POST /api/sessions/:id/messages', () => {
    it('creates a public message', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.chatMessage.create.mockResolvedValueOnce({
        id: 'msg-1',
        sessionId: 'sess-1',
        senderId: 'user-1',
        kind: 'text',
        visibility: 'public',
        content: 'hello world',
        createdAt: '2026-07-09T00:00:00.000Z'
      });

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/messages')
        .set('Authorization', `Bearer ${token}`)
        .send({ content: 'hello world' })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe('msg-1');
          expect(body.content).toBe('hello world');
          expect(body.visibility).toBe('public');
        });

      const createArgs = prismaService.chatMessage.create.mock.calls[0][0];
      expect(createArgs.data.senderId).toBe('user-1');
      expect(createArgs.data.visibility).toBe('public');
    });

    it('allows dm to send a dm-visibility message', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/messages')
        .set('Authorization', `Bearer ${token}`)
        .send({ content: 'secret note', visibility: 'dm' })
        .expect(201);

      const createArgs = prismaService.chatMessage.create.mock.calls[0][0];
      expect(createArgs.data.visibility).toBe('dm');
    });

    it('rejects a player sending a dm-visibility message with 403', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce({
        ...sessionRow,
        campaign: {
          ...campaignWithOwner,
          ownerId: 'user-2',
          members: [{ userId: 'user-1', role: 'player' }]
        }
      });

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/messages')
        .set('Authorization', `Bearer ${token}`)
        .send({ content: 'secret note', visibility: 'dm' })
        .expect(403);
    });
  });

  describe('GET /api/sessions/:id/messages', () => {
    it('filters dm-visibility messages for non-managers', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce({
        ...sessionRow,
        campaign: {
          ...campaignWithOwner,
          ownerId: 'user-2',
          members: [{ userId: 'user-1', role: 'player' }]
        }
      });
      prismaService.chatMessage.findMany.mockResolvedValueOnce([
        {
          id: 'msg-1',
          sessionId: 'sess-1',
          senderId: 'user-2',
          kind: 'text',
          visibility: 'public',
          content: 'public note',
          createdAt: '2026-07-09T00:00:00.000Z'
        },
        {
          id: 'msg-2',
          sessionId: 'sess-1',
          senderId: 'user-2',
          kind: 'text',
          visibility: 'dm',
          content: 'dm note',
          createdAt: '2026-07-09T00:01:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1/messages')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].visibility).toBe('public');
        });
    });

    it('returns dm-visibility messages for managers', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.chatMessage.findMany.mockResolvedValueOnce([
        {
          id: 'msg-1',
          sessionId: 'sess-1',
          senderId: 'user-1',
          kind: 'text',
          visibility: 'public',
          content: 'public note',
          createdAt: '2026-07-09T00:00:00.000Z'
        },
        {
          id: 'msg-2',
          sessionId: 'sess-1',
          senderId: 'user-1',
          kind: 'text',
          visibility: 'dm',
          content: 'dm note',
          createdAt: '2026-07-09T00:01:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1/messages')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(2);
        });
    });
  });

  describe('POST /api/sessions/:id/rolls', () => {
    it('creates a public roll and writes a journal entry', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.diceRoll.create.mockResolvedValueOnce({
        id: 'roll-1',
        sessionId: 'sess-1',
        actorId: 'user-1',
        actorName: 'ranger',
        notation: 'd20',
        total: 1,
        components: [{ notation: '1d20', results: [1] }],
        visibility: 'public',
        createdAt: '2026-07-09T00:00:00.000Z'
      });

      const randomSpy = jest.spyOn(Math, 'random').mockReturnValue(0);

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/rolls')
        .set('Authorization', `Bearer ${token}`)
        .send({ notation: 'd20', actorName: 'ranger' })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe('roll-1');
          expect(body.notation).toBe('d20');
          expect(body.total).toBe(1);
          expect(body.components).toHaveLength(1);
        });

      randomSpy.mockRestore();

      const createArgs = prismaService.diceRoll.create.mock.calls[0][0];
      expect(createArgs.data.actorId).toBe('user-1');
      expect(createArgs.data.total).toBe(1);
      expect(createArgs.data.components[0].results).toEqual([1]);
      const journalArgs = prismaService.journalEntry.create.mock.calls[0][0];
      expect(journalArgs.data.type).toBe('roll');
      expect(journalArgs.data.refId).toBe('roll-1');
    });

    it('parses compound notation like 2d6+3', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);

      const randomSpy = jest.spyOn(Math, 'random').mockReturnValue(0);

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/rolls')
        .set('Authorization', `Bearer ${token}`)
        .send({ notation: '2d6+3', actorName: 'ranger' })
        .expect(201);

      randomSpy.mockRestore();

      const createArgs = prismaService.diceRoll.create.mock.calls[0][0];
      expect(createArgs.data.total).toBe(5);
      expect(createArgs.data.components).toHaveLength(2);
      expect(createArgs.data.components[0].results).toEqual([1, 1]);
    });

    it('rejects a player rolling dm dice with 403', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce({
        ...sessionRow,
        campaign: {
          ...campaignWithOwner,
          ownerId: 'user-2',
          members: [{ userId: 'user-1', role: 'player' }]
        }
      });

      await request(app.getHttpServer())
        .post('/api/sessions/sess-1/rolls')
        .set('Authorization', `Bearer ${token}`)
        .send({ notation: 'd20', actorName: 'ranger', visibility: 'blind' })
        .expect(403);
    });
  });

  describe('GET /api/sessions/:id/rolls', () => {
    it('filters dm and blind rolls for non-managers', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce({
        ...sessionRow,
        campaign: {
          ...campaignWithOwner,
          ownerId: 'user-2',
          members: [{ userId: 'user-1', role: 'player' }]
        }
      });
      prismaService.diceRoll.findMany.mockResolvedValueOnce([
        {
          id: 'roll-1',
          sessionId: 'sess-1',
          actorId: 'user-2',
          actorName: 'dm',
          notation: 'd20',
          total: 15,
          components: [{ notation: '1d20', results: [15] }],
          visibility: 'public',
          createdAt: '2026-07-09T00:00:00.000Z'
        },
        {
          id: 'roll-2',
          sessionId: 'sess-1',
          actorId: 'user-2',
          actorName: 'dm',
          notation: 'd20',
          total: 5,
          components: [{ notation: '1d20', results: [5] }],
          visibility: 'dm',
          createdAt: '2026-07-09T00:01:00.000Z'
        },
        {
          id: 'roll-3',
          sessionId: 'sess-1',
          actorId: 'user-2',
          actorName: 'dm',
          notation: 'd20',
          total: 1,
          components: [{ notation: '1d20', results: [1] }],
          visibility: 'blind',
          createdAt: '2026-07-09T00:02:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1/rolls')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].visibility).toBe('public');
        });
    });

    it('returns all rolls for managers', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.diceRoll.findMany.mockResolvedValueOnce([
        {
          id: 'roll-1',
          sessionId: 'sess-1',
          actorId: 'user-1',
          actorName: 'ranger',
          notation: 'd20',
          total: 15,
          components: [{ notation: '1d20', results: [15] }],
          visibility: 'public',
          createdAt: '2026-07-09T00:00:00.000Z'
        },
        {
          id: 'roll-2',
          sessionId: 'sess-1',
          actorId: 'user-1',
          actorName: 'ranger',
          notation: 'd20',
          total: 5,
          components: [{ notation: '1d20', results: [5] }],
          visibility: 'dm',
          createdAt: '2026-07-09T00:01:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1/rolls')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(2);
        });
    });
  });

  describe('GET /api/sessions/:id/journal', () => {
    it('returns journal entries for a session member', async () => {
      const token = await loginAsDm();
      prismaService.session.findUnique.mockResolvedValueOnce(sessionRow);
      prismaService.journalEntry.findMany.mockResolvedValueOnce([
        {
          id: 'je-1',
          sessionId: 'sess-1',
          type: 'session_started',
          summary: 'Session "Session 1" started',
          refId: null,
          createdAt: '2026-07-09T01:00:00.000Z'
        },
        {
          id: 'je-2',
          sessionId: 'sess-1',
          type: 'roll',
          summary: 'ranger rolled d20 = 1',
          refId: 'roll-1',
          createdAt: '2026-07-09T01:05:00.000Z'
        }
      ]);

      await request(app.getHttpServer())
        .get('/api/sessions/sess-1/journal')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(2);
          expect(body[0].type).toBe('session_started');
          expect(body[1].type).toBe('roll');
          expect(body[1].refId).toBe('roll-1');
        });
    });

    it('rejects without authentication with 401', async () => {
      await request(app.getHttpServer())
        .get('/api/sessions/sess-1/journal')
        .expect(401);
    });
  });
});
