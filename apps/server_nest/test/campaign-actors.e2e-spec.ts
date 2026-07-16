import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

describe("campaign actors endpoints", () => {
  let app: INestApplication;

  const campaignRow = {
    id: "camp-1",
    name: "Curse of Strahd",
    description: "",
    system: "dnd5e",
    ownerId: "dm-1",
    status: "active",
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };

  const dmMemberships = [
    { userId: "dm-1", role: "owner", displayName: "DM" },
    { userId: "player-1", role: "player", displayName: "Arannis" },
  ];

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
    campaign: { create: jest.fn(), findUnique: jest.fn(), findMany: jest.fn() },
    campaignMember: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    campaignInvite: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    campaignChatMessage: { create: jest.fn(), findMany: jest.fn() },
    campaignSyncState: { upsert: jest.fn(), findUnique: jest.fn() },
    campaignActor: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    campaignActorAudit: { create: jest.fn(), findMany: jest.fn() },
    campaignContentEntry: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    campaignChange: {
      create: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
    },
    $transaction: jest.fn(),
    $queryRaw: jest.fn().mockResolvedValue([{ health_check: 1 }]),
  };
  const passwordHashService = {
    hash: jest.fn().mockResolvedValue("hashed-secret"),
    compare: jest.fn(),
  };
  const campaignsGateway = {
    broadcastToCampaign: jest.fn(),
    broadcastChange: jest.fn(),
  };

  const storedDm = {
    id: "dm-1",
    username: "dm",
    email: "dm@example.com",
    passwordHash: "hashed-secret",
  };
  const storedPlayer = {
    id: "player-1",
    username: "player",
    email: "player@example.com",
    passwordHash: "hashed-secret",
  };
  const storedStranger = {
    id: "stranger-1",
    username: "stranger",
    email: "stranger@example.com",
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
      .overrideProvider(CampaignsGateway)
      .useValue(campaignsGateway)
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
    prismaService.user.create.mockResolvedValue(storedDm);
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.refreshToken.create.mockResolvedValue({});
    prismaService.refreshToken.findUnique.mockResolvedValue(null);
    prismaService.refreshToken.update.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService),
    );
    passwordHashService.hash.mockResolvedValue("hashed-secret");
    passwordHashService.compare.mockResolvedValue(true);

    prismaService.campaign.findUnique.mockImplementation(async (args: any) => {
      if (args.where.id === "camp-1") {
        return { ...campaignRow, members: dmMemberships };
      }
      return null;
    });
    prismaService.campaignMember.findUnique.mockResolvedValue(null);
    prismaService.campaignMember.findFirst.mockResolvedValue(null);
    prismaService.campaignMember.findMany.mockResolvedValue([]);
    prismaService.campaignInvite.create.mockResolvedValue({});
    prismaService.campaignInvite.findUnique.mockResolvedValue(null);
    prismaService.campaignInvite.findFirst.mockResolvedValue(null);
    prismaService.campaignInvite.findMany.mockResolvedValue([]);
    prismaService.campaignInvite.update.mockResolvedValue({});
    prismaService.campaignChatMessage.create.mockResolvedValue({});
    prismaService.campaignChatMessage.findMany.mockResolvedValue([]);

    prismaService.campaignSyncState.upsert.mockImplementation(
      async (args: any) => ({
        campaignId: args.where.campaignId,
        cursor: BigInt(1),
      }),
    );
    prismaService.campaignActor.create.mockResolvedValue({});
    prismaService.campaignActor.findUnique.mockResolvedValue(null);
    prismaService.campaignActor.findMany.mockResolvedValue([]);
    prismaService.campaignActor.update.mockResolvedValue({});
    prismaService.campaignActorAudit.create.mockResolvedValue({});
    prismaService.campaignActorAudit.findMany.mockResolvedValue([]);
    prismaService.campaignContentEntry.create.mockResolvedValue({});
    prismaService.campaignContentEntry.findUnique.mockResolvedValue(null);
    prismaService.campaignContentEntry.findMany.mockResolvedValue([]);
    prismaService.campaignContentEntry.update.mockResolvedValue({});
    prismaService.campaignContentEntry.delete.mockResolvedValue({});
    prismaService.campaignChange.create.mockImplementation(async (args: any) => ({
      id: "change-id",
      campaignId: args.data.campaignId,
      cursor: args.data.cursor,
      entityType: args.data.entityType,
      entityId: args.data.entityId,
      operation: args.data.operation,
      revision: args.data.revision,
      createdAt: new Date(),
    }));
    prismaService.campaignChange.findMany.mockResolvedValue([]);
    prismaService.campaignChange.count.mockResolvedValue(0);
  });

  async function loginAs(user: {
    id: string;
    username: string;
    email: string;
    passwordHash: string;
  }): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(user);
    const login = await request(app.getHttpServer())
      .post("/api/auth/login")
      .send({ identifier: user.username, password: "p@ssw0rd" })
      .expect(200);
    return login.body.accessToken;
  }

  describe("POST /api/campaigns/:campaignId/actors/publish", () => {
    it("lets a member publish their local character", async () => {
      const token = await loginAs(storedPlayer);
      const created = {
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10 },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(null);
      prismaService.campaignActor.create.mockResolvedValueOnce(created);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/publish")
        .set("Authorization", `Bearer ${token}`)
        .send({
          sourceCharacterId: "char-1",
          actorType: "player",
          baseRevision: 0,
          sheet: { name: "Arannis", currentHp: 10 },
        })
        .expect(201);

      expect(res.body.id).toBe("actor-1");
      expect(res.body.ownerUserId).toBe("player-1");
      expect(res.body.revision).toBe(1);
      expect(res.body.sheet).toEqual({ name: "Arannis", currentHp: 10 });
      expect(prismaService.campaignActor.create).toHaveBeenCalled();
      expect(prismaService.campaignChange.create).toHaveBeenCalled();
    });

    it("rejects publishing when the user is not a campaign member", async () => {
      const token = await loginAs(storedStranger);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/publish")
        .set("Authorization", `Bearer ${token}`)
        .send({
          sourceCharacterId: "char-x",
          actorType: "player",
          baseRevision: 0,
          sheet: { name: "Ghost" },
        })
        .expect(403);
    });
  });

  describe("POST /api/campaigns/:campaignId/actors (DM create)", () => {
    it("lets the DM create an NPC actor", async () => {
      const token = await loginAs(storedDm);
      const created = {
        id: "actor-npc",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        actorType: "npc",
        status: "active",
        sheetJson: { name: "Goblin", currentHp: 7 },
        revision: 1,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignActor.create.mockResolvedValueOnce(created);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors")
        .set("Authorization", `Bearer ${token}`)
        .send({
          actorType: "npc",
          sheet: { name: "Goblin", currentHp: 7 },
        })
        .expect(201);

      expect(res.body.id).toBe("actor-npc");
      expect(res.body.actorType).toBe("npc");
      expect(res.body.ownerUserId).toBeNull();
    });

    it("keeps an explicitly temporary NPC distinct from persistent actors", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.create.mockResolvedValueOnce({
        id: "actor-temp",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        actorType: "npc",
        status: "active",
        lifecycle: "temporary",
        sheetJson: { name: "Street informant" },
        revision: 1,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors")
        .set("Authorization", `Bearer ${token}`)
        .send({
          actorType: "npc",
          lifecycle: "temporary",
          sheet: { name: "Street informant" },
        })
        .expect(201);

      expect(res.body.lifecycle).toBe("temporary");
      expect(prismaService.campaignActor.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ lifecycle: "temporary" }),
        }),
      );
    });

    it("rejects a player trying to create an NPC", async () => {
      const token = await loginAs(storedPlayer);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors")
        .set("Authorization", `Bearer ${token}`)
        .send({ actorType: "npc", sheet: { name: "Goblin" } })
        .expect(403);
    });
  });

  describe("GET /api/campaigns/:campaignId/actors", () => {
    it("returns actors for a member", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignActor.findMany.mockResolvedValueOnce([
        {
          id: "actor-1",
          campaignId: "camp-1",
          ownerUserId: "player-1",
          sourceCharacterId: "char-1",
          actorType: "player",
          status: "active",
          sheetJson: { name: "Arannis" },
          revision: 1,
          updatedBy: "player-1",
          createdAt: new Date("2026-07-14T00:00:00.000Z"),
          updatedAt: new Date("2026-07-14T00:00:00.000Z"),
        },
      ]);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/actors")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body).toHaveLength(1);
      expect(res.body[0].id).toBe("actor-1");
    });

    it("rejects a non-member with 403", async () => {
      const token = await loginAs(storedStranger);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/actors")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });
  });

  describe("PUT /api/campaigns/:campaignId/actors/:actorId", () => {
    it("lets the DM update an actor and bumps revision", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10 },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      const updated = {
        ...existing,
        sheetJson: { name: "Arannis", currentHp: 7 },
        revision: 2,
        updatedBy: "dm-1",
        updatedAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignActor.update.mockResolvedValueOnce(updated);

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/actors/actor-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1, sheet: { name: "Arannis", currentHp: 7 } })
        .expect(200);

      expect(res.body.revision).toBe(2);
      expect(res.body.sheet).toEqual({ name: "Arannis", currentHp: 7 });
      expect(prismaService.campaignActorAudit.create).toHaveBeenCalled();
      expect(prismaService.campaignChange.create).toHaveBeenCalled();
    });

    it("returns 409 with the current actor on a stale revision", async () => {
      const token = await loginAs(storedPlayer);
      const existing = {
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10 },
        revision: 5,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(existing);

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/actors/actor-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1, sheet: { name: "stale" } })
        .expect(409);

      expect(res.body.current.revision).toBe(5);
    });

    it("lets the owner player update their own actor", async () => {
      const token = await loginAs(storedPlayer);
      const existing = {
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10 },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      const updated = {
        ...existing,
        sheetJson: { name: "Arannis", currentHp: 9 },
        revision: 2,
        updatedBy: "player-1",
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignActor.update.mockResolvedValueOnce(updated);

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/actors/actor-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1, sheet: { name: "Arannis", currentHp: 9 } })
        .expect(200);

      expect(res.body.revision).toBe(2);
    });
  });

  describe("POST /api/campaigns/:campaignId/actors/:actorId/archive", () => {
    it("lets the DM archive an actor without deleting it", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Arannis" },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...existing,
        status: "archived",
        revision: 2,
        updatedBy: "dm-1",
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/archive")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1 })
        .expect(200);

      expect(res.body.status).toBe("archived");
      expect(prismaService.campaignActor.update).toHaveBeenCalled();
      const args = prismaService.campaignActor.update.mock.calls[0][0];
      expect(args.data.status).toBe("archived");
    });
  });

  describe("GET /api/campaigns/:campaignId/actors/:actorId/audits", () => {
    it("returns audit records for a member", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
      });
      prismaService.campaignActorAudit.findMany.mockResolvedValueOnce([
        {
          id: "audit-1",
          campaignActorId: "actor-1",
          campaignId: "camp-1",
          actorUserId: "dm-1",
          baseRevision: 1,
          resultRevision: 2,
          changedPaths: ["currentHp"],
          beforeJson: { currentHp: 10 },
          afterJson: { currentHp: 7 },
          createdAt: new Date("2026-07-14T01:00:00.000Z"),
        },
      ]);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/actors/actor-1/audits")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body).toHaveLength(1);
      expect(res.body[0].id).toBe("audit-1");
      expect(res.body[0].changedPaths).toEqual(["currentHp"]);
    });
  });

  describe("POST /api/campaigns/:campaignId/actors/:actorId/runtime-commands", () => {
    it("applies setHp and adjustHp in order", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10, conditions: [] },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...existing,
        sheetJson: { name: "Arannis", currentHp: 4, conditions: [] },
        revision: 2,
        updatedBy: "dm-1",
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/runtime-commands")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          commands: [
            { type: "setHp", value: 7 },
            { type: "adjustHp", delta: -3 },
          ],
        })
        .expect(200);

      expect(res.body.revision).toBe(2);
      expect(res.body.sheet.currentHp).toBe(4);
    });

    it("rejects unknown command types with 400", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        actorType: "player",
        status: "active",
        sheetJson: { currentHp: 10 },
        revision: 1,
        updatedBy: "player-1",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/runtime-commands")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          commands: [{ type: "setWeather", value: "rainy" }],
        })
        .expect(400);
    });
  });

  describe("POST /api/campaigns/:campaignId/actors/:actorId/assign", () => {
    it("lets the DM assign an actor to a campaign member", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        actorType: "unclaimed",
        status: "active",
        sheetJson: { name: "Sidekick" },
        revision: 1,
        updatedBy: "dm-1",
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignMember.findFirst.mockResolvedValueOnce({
        userId: "player-1",
        role: "player",
      });
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...existing,
        ownerUserId: "player-1",
        revision: 2,
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/assign")
        .set("Authorization", `Bearer ${token}`)
        .send({ ownerUserId: "player-1", baseRevision: 1 })
        .expect(200);

      expect(res.body.ownerUserId).toBe("player-1");
    });

    it("rejects assigning an actor to a non-member", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        actorType: "unclaimed",
        status: "active",
        sheetJson: { name: "Sidekick" },
        revision: 1,
        updatedBy: "dm-1",
      });
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/assign")
        .set("Authorization", `Bearer ${token}`)
        .send({ ownerUserId: "stranger-1", baseRevision: 1 })
        .expect(400);
    });
  });
});
