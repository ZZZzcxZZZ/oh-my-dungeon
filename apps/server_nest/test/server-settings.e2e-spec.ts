import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PasswordHashService } from '../src/modules/auth/password-hash.service';

describe('server settings endpoints', () => {
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
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }])
  };
  const passwordHashService = {
    hash: jest.fn().mockResolvedValue('hashed-secret'),
    compare: jest.fn()
  };
  const storedAdminUser = {
    id: 'user-1',
    username: 'ranger',
    email: 'ranger@example.com',
    passwordHash: 'hashed-secret'
  };
  const storedRegularUser = {
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
      id: 'settings-1',
      serverName: 'Friday Table',
      registrationEnabled: true,
      defaultLocale: 'en-US',
      maxUploadSizeMb: 15
    });
    prismaService.serverSetting.create.mockResolvedValue({
      id: 'settings-1',
      serverName: 'Friday Table',
      registrationEnabled: false,
      defaultLocale: 'en-US',
      maxUploadSizeMb: 15
    });
    prismaService.serverSetting.update.mockResolvedValue({
      id: 'settings-1',
      serverName: 'Friday Table',
      registrationEnabled: false,
      defaultLocale: 'en-US',
      maxUploadSizeMb: 15
    });
    prismaService.serverAdmin.findUnique.mockResolvedValue(null);
    prismaService.user.count.mockResolvedValue(1);
    prismaService.user.findFirst.mockResolvedValue(null);
    prismaService.user.findUnique.mockResolvedValue(null);
    prismaService.user.create.mockResolvedValue({
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com'
    });
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.refreshToken.create.mockResolvedValue({});
    prismaService.refreshToken.findUnique.mockResolvedValue(null);
    prismaService.refreshToken.update.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService)
    );
    passwordHashService.hash.mockResolvedValue('hashed-secret');
    passwordHashService.compare.mockResolvedValue(true);
  });

  it('returns the public settings without authentication', async () => {
    prismaService.serverSetting.findFirst.mockResolvedValue({
      id: 'settings-1',
      serverName: 'Friday Table',
      registrationEnabled: true,
      defaultLocale: 'en-US',
      maxUploadSizeMb: 15
    });

    await request(app.getHttpServer())
      .get('/api/server-settings')
      .expect(200)
      .expect(({ body }) => {
        expect(body).toEqual({
          serverName: 'Friday Table',
          registrationEnabled: true,
          defaultLocale: 'en-US',
          maxUploadSizeMb: 15
        });
      });
  });

  it('rejects PATCH without an access token with 401', async () => {
    await request(app.getHttpServer())
      .patch('/api/server-settings')
      .send({ registrationEnabled: false })
      .expect(401);
  });

  it('rejects PATCH with an invalid token with 401', async () => {
    await request(app.getHttpServer())
      .patch('/api/server-settings')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ registrationEnabled: false })
      .expect(401);
  });

  it('rejects PATCH from a non-admin user with 403', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedRegularUser);
    prismaService.serverAdmin.findUnique.mockResolvedValueOnce(null);

    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'player', password: 'p@ssw0rd' })
      .expect(200);

    await request(app.getHttpServer())
      .patch('/api/server-settings')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ registrationEnabled: false })
      .expect(403);
  });

  it('rejects PATCH with a missing registrationEnabled field', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedAdminUser);
    prismaService.serverAdmin.findUnique.mockResolvedValueOnce({
      userId: 'user-1',
      role: 'owner'
    });

    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200);

    await request(app.getHttpServer())
      .patch('/api/server-settings')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({})
      .expect(400);
  });

  it('rejects PATCH when registrationEnabled is not a boolean', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedAdminUser);
    prismaService.serverAdmin.findUnique.mockResolvedValueOnce({
      userId: 'user-1',
      role: 'owner'
    });

    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200);

    await request(app.getHttpServer())
      .patch('/api/server-settings')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ registrationEnabled: 'no' })
      .expect(400);
  });

  it('allows an admin to close registration via PATCH', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedAdminUser);
    prismaService.serverAdmin.findUnique.mockResolvedValueOnce({
      userId: 'user-1',
      role: 'owner'
    });

    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200);

    await request(app.getHttpServer())
      .patch('/api/server-settings')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ registrationEnabled: false })
      .expect(200)
      .expect(({ body }) => {
        expect(body.registrationEnabled).toBe(false);
        expect(body.serverName).toBe('Friday Table');
      });

    expect(prismaService.serverSetting.update).toHaveBeenCalledWith({
      where: { id: 'settings-1' },
      data: { registrationEnabled: false }
    });
  });

  it('blocks registration after an admin closes it', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedAdminUser);
    prismaService.serverAdmin.findUnique.mockResolvedValueOnce({
      userId: 'user-1',
      role: 'owner'
    });

    const login = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200);

    await request(app.getHttpServer())
      .patch('/api/server-settings')
      .set('Authorization', `Bearer ${login.body.accessToken}`)
      .send({ registrationEnabled: false })
      .expect(200);

    prismaService.serverSetting.findFirst.mockResolvedValueOnce({
      registrationEnabled: false
    });

    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        username: 'newbie',
        email: 'newbie@example.com',
        password: 'p@ssw0rd'
      })
      .expect(403);
  });
});
