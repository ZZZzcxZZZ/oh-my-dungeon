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
        expect(body.websocketUrl).toBe('ws://localhost:3000/campaigns');
        expect(body.registrationEnabled).toBe(true);
        expect(body.supportedSystems).toEqual(['dnd5e']);
        expect(body.apiVersion).toBe('1');
        expect(body.features).toEqual(
          expect.arrayContaining([
            'campaignArchives',
            'campaignActors',
            'campaignChat'
          ])
        );
      });
  });

  it('does not expose orphaned session check-request routes', async () => {
    await request(app.getHttpServer())
      .get('/api/sessions/removed-session/check-requests')
      .expect(404);
    await request(app.getHttpServer())
      .post('/api/check-requests/removed-request/responses')
      .send({})
      .expect(404);
  });
});
