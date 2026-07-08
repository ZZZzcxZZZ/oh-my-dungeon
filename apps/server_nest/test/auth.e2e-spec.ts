import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { PasswordHashService } from '../src/modules/auth/password-hash.service';

describe('auth register endpoint', () => {
  let app: INestApplication;
  const prismaService = {
    user: {
      count: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn()
    },
    serverAdmin: {
      create: jest.fn()
    },
    serverSetting: {
      findFirst: jest.fn()
    },
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }])
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule]
    })
      .overrideProvider(PrismaService)
      .useValue(prismaService)
      .overrideProvider(PasswordHashService)
      .useValue({ hash: jest.fn().mockResolvedValue('hashed-secret') })
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
    prismaService.user.count.mockResolvedValue(0);
    prismaService.user.findFirst.mockResolvedValue(null);
    prismaService.user.create.mockResolvedValue({
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com'
    });
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService)
    );
  });

  it('registers a new user and returns the user without password fields', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        username: 'ranger',
        email: 'ranger@example.com',
        password: 'p@ssw0rd'
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.user).toEqual({
          id: 'user-1',
          username: 'ranger',
          email: 'ranger@example.com'
        });
        expect(body.isFirstUser).toBe(true);
        expect(body.passwordHash).toBeUndefined();
      });

    const createArgs = prismaService.user.create.mock.calls[0][0];
    expect(createArgs.data.passwordHash).toBe('hashed-secret');
    expect(createArgs.data.password).toBeUndefined();
    expect(prismaService.serverAdmin.create).toHaveBeenCalledWith({
      data: { userId: 'user-1', role: 'owner' }
    });
  });

  it('rejects registration with missing username', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: 'ranger@example.com', password: 'p@ssw0rd' })
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toBe('Username is required');
      });
  });

  it('rejects registration with an empty password', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        username: 'ranger',
        email: 'ranger@example.com',
        password: '   '
      })
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toBe('Password is required');
      });
  });

  it('rejects registration with an invalid email', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        username: 'ranger',
        email: 'not-an-email',
        password: 'p@ssw0rd'
      })
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toBe('A valid email is required');
      });
  });

  it('rejects a duplicate username with 409', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce({ id: 'existing-user' });

    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        username: 'ranger',
        email: 'ranger@example.com',
        password: 'p@ssw0rd'
      })
      .expect(409)
      .expect(({ body }) => {
        expect(body.message).toBe('Username already exists');
      });
  });

  it('rejects a duplicate email with 409', async () => {
    prismaService.user.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ id: 'existing-user' });

    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        username: 'ranger',
        email: 'ranger@example.com',
        password: 'p@ssw0rd'
      })
      .expect(409)
      .expect(({ body }) => {
        expect(body.message).toBe('Email already exists');
      });
  });

  it('rejects registration when the registration switch is off', async () => {
    prismaService.serverSetting.findFirst.mockResolvedValueOnce({
      registrationEnabled: false
    });

    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        username: 'ranger',
        email: 'ranger@example.com',
        password: 'p@ssw0rd'
      })
      .expect(403)
      .expect(({ body }) => {
        expect(body.message).toBe('Registration is disabled');
      });
  });
});
