import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";

describe("legacy content endpoints removed", () => {
  let app: INestApplication;
  const prismaService = {
    user: {
      count: jest.fn(),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    serverAdmin: { create: jest.fn(), findUnique: jest.fn() },
    serverSetting: { findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
    refreshToken: { create: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
    campaign: { findUnique: jest.fn() },
    campaignMember: { findUnique: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }]),
  };
  const passwordHashService = {
    hash: jest.fn().mockResolvedValue("hashed-secret"),
    compare: jest.fn(),
  };
  const storedUser = {
    id: "user-1",
    username: "dm",
    email: "dm@example.com",
    passwordHash: "hashed-secret",
  };

  beforeAll(async () => {
    process.env.JWT_SECRET = "test-secret";
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(prismaService)
      .overrideProvider(PasswordHashService)
      .useValue(passwordHashService)
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix("api", {
      exclude: ["health", ".well-known/dnd-tool-server"],
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
      registrationEnabled: true,
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
      cb(prismaService),
    );
    passwordHashService.compare.mockResolvedValue(true);
  });

  async function login(): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(storedUser);
    const response = await request(app.getHttpServer())
      .post("/api/auth/login")
      .send({ identifier: "dm", password: "p@ssw0rd" })
      .expect(200);
    return response.body.accessToken;
  }

  it("returns 404 for the legacy global package import endpoint", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .post("/api/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({ package: { name: "x", version: "1", items: [] } })
      .expect(404);
  });

  it("returns 404 for the legacy list packages endpoint", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .get("/api/content/packages")
      .set("Authorization", `Bearer ${token}`)
      .expect(404);
  });

  it("returns 404 for the legacy list items endpoint", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .get("/api/content/items")
      .set("Authorization", `Bearer ${token}`)
      .expect(404);
  });

  it("returns 404 for the legacy campaign package import endpoint", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({ package: { name: "x", version: "1", items: [] } })
      .expect(404);
  });

  it("returns 404 for the legacy campaign package enable endpoint", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/packages")
      .set("Authorization", `Bearer ${token}`)
      .send({ packageId: "pkg-1", enabled: true })
      .expect(404);
  });

  it("returns 404 for the legacy campaign overrides endpoint", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/overrides")
      .set("Authorization", `Bearer ${token}`)
      .send({
        baseContentItemId: "item-1",
        overrideType: "disable",
      })
      .expect(404);
  });
});
