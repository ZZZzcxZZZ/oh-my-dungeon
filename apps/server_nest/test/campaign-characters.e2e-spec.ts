import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

describe("campaign characters endpoints", () => {
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
    campaignCharacter: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    campaignCharacterAudit: { create: jest.fn(), findMany: jest.fn() },
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
    prismaService.campaignCharacter.create.mockResolvedValue({});
    prismaService.campaignCharacter.findUnique.mockResolvedValue(null);
    prismaService.campaignCharacter.findMany.mockResolvedValue([]);
    prismaService.campaignCharacter.update.mockResolvedValue({});
    prismaService.campaignCharacterAudit.create.mockResolvedValue({});
    prismaService.campaignCharacterAudit.findMany.mockResolvedValue([]);
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

  describe("POST /api/campaigns/:campaignId/characters/publish", () => {
    it("lets a member publish their local character", async () => {
      const token = await loginAs(storedPlayer);
      const created = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        characterType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10 },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(null);
      prismaService.campaignCharacter.create.mockResolvedValueOnce(created);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/publish")
        .set("Authorization", `Bearer ${token}`)
        .send({
          sourceCharacterId: "char-1",
          characterType: "player",
          baseRevision: 0,
          sheet: { name: "Arannis", currentHp: 10 },
        })
        .expect(201);

      expect(res.body.id).toBe("character-1");
      expect(res.body.ownerUserId).toBe("player-1");
      expect(res.body.revision).toBe(1);
      expect(res.body.sheet).toEqual({ name: "Arannis", currentHp: 10 });
      expect(prismaService.campaignCharacter.create).toHaveBeenCalled();
      expect(prismaService.campaignChange.create).toHaveBeenCalled();
    });

    it("reactivates an archived player character when it is re-published", async () => {
      const token = await loginAs(storedPlayer);
      const archived = {
        id: "character-archived",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-archived",
        characterType: "player",
        status: "archived",
        lifecycle: "persistent",
        visibleToPlayers: true,
        sheetJson: { name: "Arannis", currentHp: 0 },
        revision: 3,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(archived);
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...archived,
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10 },
        revision: 4,
        updatedBy: "player-1",
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/publish")
        .set("Authorization", `Bearer ${token}`)
        .send({
          sourceCharacterId: "char-archived",
          characterType: "player",
          baseRevision: 3,
          sheet: { name: "Arannis", currentHp: 10 },
        })
        .expect(201);

      expect(res.body.status).toBe("active");
      expect(prismaService.campaignCharacter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: "character-archived" },
          data: expect.objectContaining({
            status: "active",
            characterType: "player",
            visibleToPlayers: true,
          }),
        }),
      );
      expect(prismaService.campaignCharacterAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            changedPaths: expect.arrayContaining(["status"]),
          }),
        }),
      );
    });

    it("rejects publishing when the user is not a campaign member", async () => {
      const token = await loginAs(storedStranger);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/publish")
        .set("Authorization", `Bearer ${token}`)
        .send({
          sourceCharacterId: "char-x",
          characterType: "player",
          baseRevision: 0,
          sheet: { name: "Ghost" },
        })
        .expect(403);
    });
  });

  describe("POST /api/campaigns/:campaignId/characters (DM create)", () => {
    it("lets the DM create an NPC character", async () => {
      const token = await loginAs(storedDm);
      const created = {
        id: "character-npc",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "npc",
        status: "active",
        visibleToPlayers: false,
        sheetJson: { name: "Goblin", currentHp: 7 },
        revision: 1,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.create.mockResolvedValueOnce(created);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters")
        .set("Authorization", `Bearer ${token}`)
        .send({
          characterType: "npc",
          sheet: { name: "Goblin", currentHp: 7 },
        })
        .expect(201);

      expect(res.body.id).toBe("character-npc");
      expect(res.body.characterType).toBe("npc");
      expect(res.body.ownerUserId).toBeNull();
      expect(res.body.visibleToPlayers).toBe(false);
      expect(
        prismaService.campaignCharacter.create.mock.calls[0][0].data
          .visibleToPlayers,
      ).toBe(false);
    });

    it("lets the DM create a monster character", async () => {
      const token = await loginAs(storedDm);
      const created = {
        id: "character-monster",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "monster",
        status: "active",
        sheetJson: { name: "Goblin Boss", currentHp: 21, maxHp: 21 },
        revision: 1,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.create.mockResolvedValueOnce(created);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters")
        .set("Authorization", `Bearer ${token}`)
        .send({
          characterType: "monster",
          sheet: { name: "Goblin Boss", currentHp: 21, maxHp: 21 },
        })
        .expect(201);

      expect(res.body.id).toBe("character-monster");
      expect(res.body.characterType).toBe("monster");
    });

    it("rejects persisted temporary characters because one-shot identities belong to messages", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters")
        .set("Authorization", `Bearer ${token}`)
        .send({
          characterType: "npc",
          lifecycle: "temporary",
          sheet: { name: "Street informant" },
        })
        .expect(400);

      expect(prismaService.campaignCharacter.create).not.toHaveBeenCalled();
    });

    it("rejects a player trying to create an NPC", async () => {
      const token = await loginAs(storedPlayer);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters")
        .set("Authorization", `Bearer ${token}`)
        .send({ characterType: "npc", sheet: { name: "Goblin" } })
        .expect(403);
    });
  });

  describe("GET /api/campaigns/:campaignId/characters", () => {
    it("returns characters for a member", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignCharacter.findMany.mockResolvedValueOnce([
        {
          id: "character-1",
          campaignId: "camp-1",
          ownerUserId: "player-1",
          sourceCharacterId: "char-1",
          characterType: "player",
          status: "active",
          visibleToPlayers: true,
          sheetJson: { name: "Arannis" },
          revision: 1,
          updatedBy: "player-1",
          createdAt: new Date("2026-07-14T00:00:00.000Z"),
          updatedAt: new Date("2026-07-14T00:00:00.000Z"),
        },
        {
          id: "hidden-npc",
          campaignId: "camp-1",
          ownerUserId: null,
          sourceCharacterId: null,
          characterType: "npc",
          status: "active",
          visibleToPlayers: false,
          sheetJson: { name: "Secret villain" },
          revision: 1,
          updatedBy: "dm-1",
          createdAt: new Date("2026-07-14T00:00:00.000Z"),
          updatedAt: new Date("2026-07-14T00:00:00.000Z"),
        },
        {
          id: "visible-npc",
          campaignId: "camp-1",
          ownerUserId: null,
          sourceCharacterId: null,
          characterType: "npc",
          status: "active",
          visibleToPlayers: true,
          sheetJson: { name: "Known ally" },
          revision: 1,
          updatedBy: "dm-1",
          createdAt: new Date("2026-07-14T00:00:00.000Z"),
          updatedAt: new Date("2026-07-14T00:00:00.000Z"),
        },
      ]);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/characters")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body).toHaveLength(2);
      expect(res.body[0].id).toBe("character-1");
      expect(res.body[1].id).toBe("visible-npc");
    });

    it("rejects a non-member with 403", async () => {
      const token = await loginAs(storedStranger);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/characters")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });
  });

  describe("PUT /api/campaigns/:campaignId/characters/:characterId", () => {
    it("lets the DM change NPC player visibility", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "npc-visibility",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "npc",
        status: "active",
        lifecycle: "persistent",
        visibleToPlayers: false,
        sheetJson: { name: "Hidden guide" },
        revision: 1,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...existing,
        visibleToPlayers: true,
        revision: 2,
      });

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/characters/npc-visibility")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          sheet: existing.sheetJson,
          visibleToPlayers: true,
        })
        .expect(200);

      expect(res.body.visibleToPlayers).toBe(true);
      expect(prismaService.campaignCharacter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: "npc-visibility" },
          data: expect.objectContaining({ visibleToPlayers: true }),
        }),
      );
    });

    it("lets the DM update an character and bumps revision", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        characterType: "player",
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
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignCharacter.update.mockResolvedValueOnce(updated);

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/characters/character-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1, sheet: { name: "Arannis", currentHp: 7 } })
        .expect(200);

      expect(res.body.revision).toBe(2);
      expect(res.body.sheet).toEqual({ name: "Arannis", currentHp: 7 });
      expect(prismaService.campaignCharacterAudit.create).toHaveBeenCalled();
      expect(prismaService.campaignChange.create).toHaveBeenCalled();
    });

    it("returns 409 with the current character on a stale revision", async () => {
      const token = await loginAs(storedPlayer);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        characterType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10 },
        revision: 5,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/characters/character-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1, sheet: { name: "stale" } })
        .expect(409);

      expect(res.body.current.revision).toBe(5);
    });

    it("lets the owner player update their own character", async () => {
      const token = await loginAs(storedPlayer);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        characterType: "player",
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
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignCharacter.update.mockResolvedValueOnce(updated);

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/characters/character-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1, sheet: { name: "Arannis", currentHp: 9 } })
        .expect(200);

      expect(res.body.revision).toBe(2);
    });

    // Spec §完整管理: 转为常驻 — DM 可以把 temporary 角色转为 persistent。
    it("lets the DM convert a temporary character to persistent via lifecycle field", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "npc",
        status: "active",
        lifecycle: "temporary",
        sheetJson: { name: "Innkeeper" },
        revision: 1,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      const updated = {
        ...existing,
        lifecycle: "persistent",
        revision: 2,
        updatedBy: "dm-1",
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignCharacter.update.mockResolvedValueOnce(updated);

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/characters/character-1")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          sheet: { name: "Innkeeper" },
          lifecycle: "persistent",
        })
        .expect(200);

      expect(res.body.lifecycle).toBe("persistent");
      const args = prismaService.campaignCharacter.update.mock.calls[0][0];
      expect(args.data.lifecycle).toBe("persistent");
    });

    it("rejects a player trying to convert an character lifecycle to persistent", async () => {
      const token = await loginAs(storedPlayer);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "npc",
        status: "active",
        lifecycle: "temporary",
        sheetJson: { name: "Innkeeper" },
        revision: 1,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/characters/character-1")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          sheet: { name: "Innkeeper" },
          lifecycle: "persistent",
        })
        .expect(403);
    });
  });

  describe("POST /api/campaigns/:campaignId/characters/:characterId/archive", () => {
    it("lets the DM archive an character without deleting it", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        characterType: "player",
        status: "active",
        sheetJson: { name: "Arannis" },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...existing,
        status: "archived",
        revision: 2,
        updatedBy: "dm-1",
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/archive")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1 })
        .expect(200);

      expect(res.body.status).toBe("archived");
      expect(prismaService.campaignCharacter.update).toHaveBeenCalled();
      const args = prismaService.campaignCharacter.update.mock.calls[0][0];
      expect(args.data.status).toBe("archived");
    });
  });

  describe("POST /api/campaigns/:campaignId/characters/:characterId/restore", () => {
    it("lets the DM restore an archived character", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "npc",
        status: "archived",
        sheetJson: { name: "Innkeeper" },
        revision: 2,
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...existing,
        status: "active",
        revision: 3,
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/restore")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 2 })
        .expect(200);

      expect(res.body.status).toBe("active");
      const args = prismaService.campaignCharacter.update.mock.calls[0][0];
      expect(args.data.status).toBe("active");
    });
  });

  describe("GET /api/campaigns/:campaignId/characters/:characterId/audits", () => {
    it("returns audit records for a member", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce({
        id: "character-1",
        campaignId: "camp-1",
      });
      prismaService.campaignCharacterAudit.findMany.mockResolvedValueOnce([
        {
          id: "audit-1",
          campaignCharacterId: "character-1",
          campaignId: "camp-1",
          characterUserId: "dm-1",
          baseRevision: 1,
          resultRevision: 2,
          changedPaths: ["currentHp"],
          beforeJson: { currentHp: 10 },
          afterJson: { currentHp: 7 },
          createdAt: new Date("2026-07-14T01:00:00.000Z"),
        },
      ]);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/characters/character-1/audits")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body).toHaveLength(1);
      expect(res.body[0].id).toBe("audit-1");
      expect(res.body[0].changedPaths).toEqual(["currentHp"]);
    });
  });

  describe("POST /api/campaigns/:campaignId/characters/:characterId/runtime-commands", () => {
    it("applies setHp and adjustHp in order", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        sourceCharacterId: "char-1",
        characterType: "player",
        status: "active",
        sheetJson: { name: "Arannis", currentHp: 10, conditions: [] },
        revision: 1,
        updatedBy: "player-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...existing,
        sheetJson: { name: "Arannis", currentHp: 4, conditions: [] },
        revision: 2,
        updatedBy: "dm-1",
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/runtime-commands")
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
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce({
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: "player-1",
        characterType: "player",
        status: "active",
        sheetJson: { currentHp: 10 },
        revision: 1,
        updatedBy: "player-1",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/runtime-commands")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          commands: [{ type: "setWeather", value: "rainy" }],
        })
        .expect(400);
    });
  });

  describe("POST /api/campaigns/:campaignId/characters/:characterId/assign", () => {
    it("lets the DM assign an character to a campaign member", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "unclaimed",
        status: "active",
        sheetJson: { name: "Sidekick" },
        revision: 1,
        updatedBy: "dm-1",
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignMember.findFirst.mockResolvedValueOnce({
        userId: "player-1",
        role: "player",
      });
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...existing,
        ownerUserId: "player-1",
        revision: 2,
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/assign")
        .set("Authorization", `Bearer ${token}`)
        .send({ ownerUserId: "player-1", baseRevision: 1 })
        .expect(200);

      expect(res.body.ownerUserId).toBe("player-1");
    });

    it("rejects assigning an character to a non-member", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce({
        id: "character-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        characterType: "unclaimed",
        status: "active",
        sheetJson: { name: "Sidekick" },
        revision: 1,
        updatedBy: "dm-1",
      });
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/assign")
        .set("Authorization", `Bearer ${token}`)
        .send({ ownerUserId: "stranger-1", baseRevision: 1 })
        .expect(400);
    });
  });
});
