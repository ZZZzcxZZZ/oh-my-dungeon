import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('server metadata endpoints', () => {
  let app: INestApplication;
  const prismaService = {
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }])
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule]
    })
      .overrideProvider(PrismaService)
      .useValue(prismaService)
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

  it('reports health status', async () => {
    await request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect(({ body }) => {
        expect(body.status).toBe('ok');
        expect(body.service).toBe('dnd-table-server');
        expect(body.database.status).toBe('ok');
        expect(prismaService.$queryRaw).toHaveBeenCalled();
      });
  });

  it('exposes well-known server metadata for client discovery', async () => {
    await request(app.getHttpServer())
      .get('/.well-known/dnd-tool-server')
      .expect(200)
      .expect(({ body }) => {
        expect(body.name).toBe('D&D Table Tool');
        expect(body.version).toBe('0.1.0');
        expect(body.apiBaseUrl).toBe('http://localhost:3000/api');
        expect(body.websocketUrl).toBe('ws://localhost:3000/realtime');
        expect(body.registrationEnabled).toBe(true);
        expect(body.supportedSystems).toEqual(['dnd5e']);
      });
  });

  it('lists rooms through the API namespace', async () => {
    await request(app.getHttpServer()).get('/api/rooms').expect(200).expect([]);
  });

  it('rejects room creation from player mode', async () => {
    await request(app.getHttpServer())
      .post('/api/rooms')
      .set('x-client-mode', 'player')
      .send({ name: 'Friday One Shot' })
      .expect(403)
      .expect(({ body }) => {
        expect(body.message).toBe('Only DM mode can create rooms');
      });
  });

  it('rejects room creation without a name', async () => {
    await request(app.getHttpServer())
      .post('/api/rooms')
      .set('x-client-mode', 'dm')
      .send({ name: '   ' })
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toBe('Room name is required');
      });
  });

  it('creates rooms from dm mode', async () => {
    await request(app.getHttpServer())
      .post('/api/rooms')
      .set('x-client-mode', 'dm')
      .send({ name: 'Friday One Shot' })
      .expect(201)
      .expect(({ body }) => {
        expect(body.id).toEqual(expect.any(String));
        expect(body.name).toBe('Friday One Shot');
        expect(body.status).toBe('open');
        expect(body.system).toBe('dnd5e');
      });

    await request(app.getHttpServer())
      .get('/api/rooms')
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0].name).toBe('Friday One Shot');
      });
  });

  it('records and lists dice rolls for a room', async () => {
    let roomId = '';

    await request(app.getHttpServer())
      .post('/api/rooms')
      .set('x-client-mode', 'dm')
      .send({ name: 'Roll Test Room' })
      .expect(201)
      .expect(({ body }) => {
        roomId = body.id as string;
      });

    let rollId = '';

    await request(app.getHttpServer())
      .post(`/api/rooms/${roomId}/rolls`)
      .set('x-client-mode', 'player')
      .send({ notation: 'd20', total: 17, actorName: 'Ada' })
      .expect(201)
      .expect(({ body }) => {
        rollId = body.id as string;
        expect(body.roomId).toBe(roomId);
        expect(body.notation).toBe('d20');
        expect(body.total).toBe(17);
        expect(body.actorName).toBe('Ada');
        expect(body.actorMode).toBe('player');
        expect(body.createdAt).toEqual(expect.any(String));
      });

    await request(app.getHttpServer())
      .get(`/api/rooms/${roomId}/rolls`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toEqual([
          expect.objectContaining({
            id: rollId,
            roomId,
            notation: 'd20',
            total: 17,
            actorName: 'Ada',
            actorMode: 'player'
          })
        ]);
      });
  });

  it('rejects dice rolls for an unknown room', async () => {
    await request(app.getHttpServer())
      .post('/api/rooms/missing-room/rolls')
      .set('x-client-mode', 'player')
      .send({ notation: 'd20', total: 17, actorName: 'Ada' })
      .expect(404)
      .expect(({ body }) => {
        expect(body.message).toBe('Room not found');
      });
  });

  it('rejects invalid dice roll data', async () => {
    let roomId = '';

    await request(app.getHttpServer())
      .post('/api/rooms')
      .set('x-client-mode', 'dm')
      .send({ name: 'Invalid Roll Room' })
      .expect(201)
      .expect(({ body }) => {
        roomId = body.id as string;
      });

    await request(app.getHttpServer())
      .post(`/api/rooms/${roomId}/rolls`)
      .set('x-client-mode', 'player')
      .send({ notation: '   ', total: 'high', actorName: 'Ada' })
      .expect(400)
      .expect(({ body }) => {
        expect(body.message).toBe('Dice roll notation and total are required');
      });
  });
});
