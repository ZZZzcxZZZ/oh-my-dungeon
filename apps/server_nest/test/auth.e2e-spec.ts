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

describe('auth login endpoint', () => {
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
    refreshToken: {
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
    prismaService.user.count.mockResolvedValue(0);
    prismaService.user.findFirst.mockResolvedValue(null);
    prismaService.user.create.mockResolvedValue({
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com'
    });
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.refreshToken.create.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService)
    );
    passwordHashService.hash.mockResolvedValue('hashed-secret');
    passwordHashService.compare.mockResolvedValue(true);
  });

  it('logs in with a username and returns tokens without passwordHash', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedUser);

    const result = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'p@ssw0rd' })
      .expect(200)
      .then((r) => r.body);

    expect(result.user).toEqual({
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com'
    });
    expect(result.accessToken).toEqual(expect.any(String));
    expect(result.refreshToken).toEqual(expect.any(String));
    expect(result.user).not.toHaveProperty('passwordHash');
    expect(prismaService.refreshToken.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'user-1',
        tokenHash: expect.any(String),
        expiresAt: expect.any(Date)
      })
    });
    const createArgs = prismaService.refreshToken.create.mock.calls[0][0];
    expect(createArgs.data.token).toBeUndefined();
  });

  it('logs in with an email identifier', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedUser);

    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger@example.com', password: 'p@ssw0rd' })
      .expect(200);
  });

  it('rejects a missing identifier with 400', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ password: 'p@ssw0rd' })
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toBe('Identifier is required');
      });
  });

  it('rejects a missing password with 400', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger' })
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toBe('Password is required');
      });
  });

  it('rejects an unknown identifier with 401', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(null);

    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ghost', password: 'p@ssw0rd' })
      .expect(401)
      .expect(({ body }) => {
        expect(body.message).toBe('Invalid credentials');
      });
  });

  it('rejects a wrong password with 401', async () => {
    prismaService.user.findFirst.mockResolvedValueOnce(storedUser);
    passwordHashService.compare.mockResolvedValueOnce(false);

    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ identifier: 'ranger', password: 'wrong' })
      .expect(401)
      .expect(({ body }) => {
        expect(body.message).toBe('Invalid credentials');
      });
  });
});
