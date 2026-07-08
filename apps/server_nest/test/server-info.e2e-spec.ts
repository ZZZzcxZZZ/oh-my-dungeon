import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request = require('supertest');
import { AppModule } from '../src/app.module';

describe('server metadata endpoints', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule]
    }).compile();

    app = moduleRef.createNestApplication();
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
});
