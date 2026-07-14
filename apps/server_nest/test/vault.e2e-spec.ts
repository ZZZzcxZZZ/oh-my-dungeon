import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";

describe("vault endpoints", () => {
  let app: INestApplication;
  const prismaService = {
    user: {
      count: jest.fn(),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
    },
    serverAdmin: {
      create: jest.fn(),
      findUnique: jest.fn(),
    },
    serverSetting: {
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    refreshToken: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    campaign: {
      findUnique: jest.fn(),
    },
    campaignMember: {
      findUnique: jest.fn(),
    },
    journalEntry: {
      create: jest.fn(),
    },
    vaultEntity: {
      upsert: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      delete: jest.fn(),
    },
    vaultChange: {
      createMany: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      deleteMany: jest.fn(),
    },
    vaultOperation: {
      upsert: jest.fn(),
    },
    vaultDevice: {
      upsert: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
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
    prismaService.$transaction.mockImplementation(async (cb: (tx: typeof prismaService) => Promise<unknown>) =>
      cb(prismaService),
    );
    passwordHashService.compare.mockResolvedValue(true);
    prismaService.campaign.findUnique.mockResolvedValue(null);
    prismaService.campaignMember.findUnique.mockResolvedValue(null);
    prismaService.journalEntry.create.mockResolvedValue({});
    prismaService.vaultEntity.upsert.mockResolvedValue({});
    prismaService.vaultEntity.findUnique.mockResolvedValue(null);
    prismaService.vaultEntity.findMany.mockResolvedValue([]);
    prismaService.vaultEntity.delete.mockResolvedValue({});
    prismaService.vaultChange.createMany.mockResolvedValue({ count: 0 });
    prismaService.vaultChange.findMany.mockResolvedValue([]);
    prismaService.vaultChange.count.mockResolvedValue(0);
    prismaService.vaultChange.deleteMany.mockResolvedValue({ count: 0 });
    prismaService.vaultOperation.upsert.mockResolvedValue({});
    prismaService.vaultDevice.upsert.mockResolvedValue({});
    prismaService.vaultDevice.findUnique.mockResolvedValue(null);
    prismaService.vaultDevice.findMany.mockResolvedValue([]);
    prismaService.vaultDevice.update.mockResolvedValue({});
    prismaService.vaultDevice.delete.mockResolvedValue({});
  });

  async function login(): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(storedUser);
    const response = await request(app.getHttpServer())
      .post("/api/auth/login")
      .send({ identifier: "dm", password: "p@ssw0rd" })
      .expect(200);
    return response.body.accessToken;
  }

  it("pushes an operation once and returns changes after the cursor", async () => {
    const token = await login();
    prismaService.vaultOperation.upsert.mockResolvedValue({});
    prismaService.vaultEntity.upsert.mockResolvedValue({
      id: "ve-1",
      userId: "user-1",
      entityType: "character",
      entityId: "character-1",
      payload: { name: "Arannis" },
      revision: 1,
      deletedAt: null,
      updatedAt: new Date(),
    });
    prismaService.vaultChange.createMany.mockResolvedValue({ count: 1 });
    prismaService.vaultDevice.upsert.mockResolvedValue({});
    prismaService.vaultChange.findMany.mockResolvedValue([]);
    prismaService.vaultChange.count.mockResolvedValue(0);

    const operation = {
      operationId: "op-1",
      entityType: "character",
      entityId: "character-1",
      baseRevision: 0,
      operation: "upsert",
      payload: { name: "Arannis" },
    };
    await request(app.getHttpServer())
      .post("/api/vault/push")
      .set("Authorization", `Bearer ${token}`)
      .set("X-Device-Id", "device-1")
      .send({ operations: [operation, operation] })
      .expect(200);

    expect(prismaService.vaultOperation.upsert).toHaveBeenCalledTimes(1);

    prismaService.vaultChange.findMany.mockResolvedValue([
      {
        cursor: BigInt(1),
        userId: "user-1",
        entityType: "character",
        entityId: "character-1",
        operation: "upsert",
        payload: { name: "Arannis" },
        revision: 1,
        createdAt: new Date(),
      },
    ]);
    prismaService.vaultChange.count.mockResolvedValue(0);

    const response = await request(app.getHttpServer())
      .get("/api/vault/changes?cursor=0")
      .set("Authorization", `Bearer ${token}`)
      .set("X-Device-Id", "device-1")
      .expect(200);
    expect(response.body.changes).toHaveLength(1);
    expect(response.body.changes[0].entityId).toBe("character-1");
    expect(response.body.changes[0].cursor).toBe("1");
  });

  it("requires X-Device-Id header", async () => {
    const token = await login();
    await request(app.getHttpServer())
      .post("/api/vault/push")
      .set("Authorization", `Bearer ${token}`)
      .send({ operations: [] })
      .expect(400);
  });

  it("isolates entities between users", async () => {
    const token = await login();
    prismaService.vaultChange.findMany.mockResolvedValue([]);
    prismaService.vaultChange.count.mockResolvedValue(0);
    prismaService.vaultDevice.upsert.mockResolvedValue({});

    const response = await request(app.getHttpServer())
      .get("/api/vault/changes?cursor=0")
      .set("Authorization", `Bearer ${token}`)
      .set("X-Device-Id", "device-1")
      .expect(200);
    expect(response.body.changes).toEqual([]);
    expect(prismaService.vaultChange.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userId: "user-1" }),
      }),
    );
  });

  it("returns 409 on revision conflict", async () => {
    const token = await login();
    prismaService.vaultOperation.upsert.mockResolvedValue({});
    prismaService.vaultEntity.upsert.mockImplementation(() => {
      throw { code: "P2002" };
    });
    prismaService.vaultDevice.upsert.mockResolvedValue({});

    const operation = {
      operationId: "op-conflict",
      entityType: "character",
      entityId: "character-conflict",
      baseRevision: 3,
      operation: "upsert",
      payload: { name: "Conflict" },
    };
    await request(app.getHttpServer())
      .post("/api/vault/push")
      .set("Authorization", `Bearer ${token}`)
      .set("X-Device-Id", "device-1")
      .send({ operations: [operation] })
      .expect(409);
  });

  it("lists and revokes devices", async () => {
    const token = await login();
    prismaService.vaultDevice.findMany.mockResolvedValue([
      {
        id: "dev-1",
        userId: "user-1",
        deviceId: "device-1",
        name: "Desktop",
        platform: "windows",
        lastCursor: BigInt(5),
        lastSeenAt: new Date(),
        revokedAt: null,
      },
      {
        id: "dev-2",
        userId: "user-1",
        deviceId: "device-2",
        name: "Laptop",
        platform: "web",
        lastCursor: BigInt(3),
        lastSeenAt: new Date(),
        revokedAt: null,
      },
    ]);
    prismaService.vaultDevice.findUnique.mockResolvedValue({
      id: "dev-2",
      userId: "user-1",
      deviceId: "device-2",
      name: "Laptop",
      platform: "web",
      lastCursor: BigInt(3),
      lastSeenAt: new Date(),
      revokedAt: null,
    });

    const listResponse = await request(app.getHttpServer())
      .get("/api/vault/devices")
      .set("Authorization", `Bearer ${token}`)
      .set("X-Device-Id", "device-1")
      .expect(200);
    expect(listResponse.body).toHaveLength(2);

    await request(app.getHttpServer())
      .delete("/api/vault/devices/device-2")
      .set("Authorization", `Bearer ${token}`)
      .set("X-Device-Id", "device-1")
      .expect(204);
    expect(prismaService.vaultDevice.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { deviceId: "device-2" },
        data: expect.objectContaining({ revokedAt: expect.any(Date) }),
      }),
    );
  });

  it("prevents revoking the current device", async () => {
    const token = await login();
    await request(app.getHttpServer())
      .delete("/api/vault/devices/device-1")
      .set("Authorization", `Bearer ${token}`)
      .set("X-Device-Id", "device-1")
      .expect(400);
  });
});
