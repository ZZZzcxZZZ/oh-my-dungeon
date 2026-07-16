import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

describe("campaign content sync endpoints", () => {
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
      updateMany: jest.fn(),
      delete: jest.fn(),
      count: jest.fn(),
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
    prismaService.campaignContentEntry.updateMany.mockResolvedValue({ count: 1 });
    prismaService.campaignContentEntry.delete.mockResolvedValue({});
    prismaService.campaignContentEntry.count.mockResolvedValue(0);
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

  describe("POST /api/campaigns/:campaignId/content/entries", () => {
    it("lets the DM create a content entry", async () => {
      const token = await loginAs(storedDm);
      const created = {
        id: "entry-1",
        campaignId: "camp-1",
        type: "location",
        slug: "moon-harbor",
        name: "月港",
        entryJson: {
          body: [{ type: "paragraph", text: "港口描述" }],
          tags: ["港口"],
        },
        revision: 1,
        createdBy: "dm-1",
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
        deletedAt: null,
      };
      prismaService.campaignContentEntry.findUnique.mockResolvedValueOnce(null);
      prismaService.campaignContentEntry.create.mockResolvedValueOnce(created);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "moon-harbor",
          name: "月港",
          entry: {
            body: [{ type: "paragraph", text: "港口描述" }],
            tags: ["港口"],
          },
        })
        .expect(201);

      expect(res.body.id).toBe("entry-1");
      expect(res.body.slug).toBe("moon-harbor");
      expect(res.body.revision).toBe(1);
      expect(res.body.entry).toEqual({
        body: [{ type: "paragraph", text: "港口描述" }],
        tags: ["港口"],
      });
      expect(prismaService.campaignContentEntry.create).toHaveBeenCalled();
      expect(prismaService.campaignChange.create).toHaveBeenCalled();
    });

    it("rejects a player with 403", async () => {
      const token = await loginAs(storedPlayer);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "moon-harbor",
          name: "月港",
          entry: { body: [{ type: "paragraph", text: "x" }] },
        })
        .expect(403);
    });

    it("rejects a non-member with 403", async () => {
      const token = await loginAs(storedStranger);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "x",
          name: "x",
          entry: { body: [{ type: "paragraph", text: "x" }] },
        })
        .expect(403);
    });

    it("returns 409 on duplicate slug", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignContentEntry.findUnique.mockResolvedValueOnce({
        id: "existing-1",
        campaignId: "camp-1",
        type: "location",
        slug: "moon-harbor",
        name: "旧月港",
        entryJson: {},
        revision: 1,
        createdBy: "dm-1",
        updatedBy: "dm-1",
        createdAt: new Date(),
        updatedAt: new Date(),
        deletedAt: null,
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "moon-harbor",
          name: "新月港",
          entry: { body: [{ type: "paragraph", text: "x" }] },
        })
        .expect(409);
    });

    it("restores a soft-deleted entry when its slug is created again", async () => {
      const token = await loginAs(storedDm);
      const deleted = {
        id: "entry-deleted",
        campaignId: "camp-1",
        type: "location",
        slug: "moon-harbor",
        name: "Old harbor",
        entryJson: { body: [] },
        revision: 2,
        createdBy: "dm-1",
        updatedBy: "dm-1",
        createdAt: new Date(),
        updatedAt: new Date(),
        deletedAt: new Date(),
      };
      const restored = {
        ...deleted,
        name: "Moon Harbor",
        entryJson: { body: [{ type: "paragraph", text: "Restored" }] },
        revision: 3,
        deletedAt: null,
      };
      prismaService.campaignContentEntry.findUnique.mockResolvedValueOnce(deleted);
      prismaService.campaignContentEntry.update.mockResolvedValueOnce(restored);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "moon-harbor",
          name: "Moon Harbor",
          entry: { body: [{ type: "paragraph", text: "Restored" }] },
        })
        .expect(201);

      expect(prismaService.campaignContentEntry.create).not.toHaveBeenCalled();
      expect(prismaService.campaignContentEntry.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: "entry-deleted" },
          data: expect.objectContaining({ deletedAt: null, revision: 3 }),
        }),
      );
    });

    it("returns 400 with JSON path on invalid content block type", async () => {
      const token = await loginAs(storedDm);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "bad-block",
          name: "坏块",
          entry: {
            body: [{ type: "html", html: "<b>nope</b>" }],
          },
        })
        .expect(400);

      expect(res.body.message).toContain("body");
    });

    it("returns 400 when entry has forbidden baseEntryId field", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "forbidden",
          name: "禁止字段",
          entry: {
            body: [{ type: "paragraph", text: "x" }],
            baseEntryId: "phb:spell-1",
          },
        })
        .expect(400);
    });

    it("returns 400 when top-level body has forbidden patch field", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "forbidden-patch",
          name: "禁止patch",
          patch: { hp: 99 },
          entry: {
            body: [{ type: "paragraph", text: "x" }],
          },
        })
        .expect(400);
    });
  });

  describe("POST /api/campaigns/:campaignId/content/entries/validate", () => {
    it("returns valid:true for a well-formed entry without writing", async () => {
      const token = await loginAs(storedDm);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries/validate")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "validate-ok",
          name: "校验通过",
          entry: {
            body: [{ type: "paragraph", text: "ok" }],
          },
        })
        .expect(200);

      expect(res.body.valid).toBe(true);
      expect(prismaService.campaignContentEntry.create).not.toHaveBeenCalled();
    });

    it("returns valid:false with errors for invalid entry", async () => {
      const token = await loginAs(storedDm);

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/content/entries/validate")
        .set("Authorization", `Bearer ${token}`)
        .send({
          type: "location",
          slug: "validate-bad",
          name: "校验失败",
          entry: {
            body: [{ type: "unknown-block", text: "x" }],
          },
        })
        .expect(200);

      expect(res.body.valid).toBe(false);
      expect(res.body.errors.length).toBeGreaterThan(0);
      expect(prismaService.campaignContentEntry.create).not.toHaveBeenCalled();
    });
  });

  describe("GET /api/campaigns/:campaignId/content/entries", () => {
    it("returns entries for a member", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignContentEntry.findMany.mockResolvedValueOnce([
        {
          id: "entry-1",
          campaignId: "camp-1",
          type: "location",
          slug: "moon-harbor",
          name: "月港",
          entryJson: { body: [{ type: "paragraph", text: "x" }] },
          revision: 1,
          createdBy: "dm-1",
          updatedBy: "dm-1",
          createdAt: new Date("2026-07-14T00:00:00.000Z"),
          updatedAt: new Date("2026-07-14T00:00:00.000Z"),
          deletedAt: null,
        },
      ]);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body).toHaveLength(1);
      expect(res.body[0].id).toBe("entry-1");
      expect(res.body[0].slug).toBe("moon-harbor");
    });

    it("rejects a non-member with 403", async () => {
      const token = await loginAs(storedStranger);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });

    it("excludes soft-deleted entries by default", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignContentEntry.findMany.mockResolvedValueOnce([]);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/content/entries")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body).toHaveLength(0);
      const args = prismaService.campaignContentEntry.findMany.mock.calls[0][0];
      expect(args.where.deletedAt).toBeNull();
    });
  });

  describe("PUT /api/campaigns/:campaignId/content/entries/:entryId", () => {
    it("lets the DM update an entry and bumps revision", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "entry-1",
        campaignId: "camp-1",
        type: "location",
        slug: "moon-harbor",
        name: "月港",
        entryJson: { body: [{ type: "paragraph", text: "old" }] },
        revision: 1,
        createdBy: "dm-1",
        updatedBy: "dm-1",
        createdAt: new Date("2026-07-14T00:00:00.000Z"),
        updatedAt: new Date("2026-07-14T00:00:00.000Z"),
        deletedAt: null,
      };
      const updated = {
        ...existing,
        entryJson: { body: [{ type: "paragraph", text: "new" }] },
        revision: 2,
        updatedBy: "dm-1",
        updatedAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignContentEntry.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignContentEntry.updateMany.mockResolvedValueOnce({ count: 1 });

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/content/entries/entry-1")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          entry: { body: [{ type: "paragraph", text: "new" }] },
        })
        .expect(200);

      expect(res.body.revision).toBe(2);
      expect(prismaService.campaignChange.create).toHaveBeenCalled();
    });

    it("returns 409 when a concurrent update wins after the initial read", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "entry-1", campaignId: "camp-1", type: "location", slug: "moon-harbor",
        name: "Moon Harbor", entryJson: {}, revision: 1, createdBy: "dm-1",
        updatedBy: "dm-1", createdAt: new Date(), updatedAt: new Date(), deletedAt: null,
      };
      const current = { ...existing, revision: 2, updatedBy: "player-1" };
      prismaService.campaignContentEntry.findUnique
        .mockResolvedValueOnce(existing)
        .mockResolvedValueOnce(current);
      prismaService.campaignContentEntry.updateMany.mockResolvedValueOnce({ count: 0 });

      const res = await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/content/entries/entry-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ baseRevision: 1, entry: { body: [] } })
        .expect(409);

      expect(res.body.current.revision).toBe(2);
      expect(prismaService.campaignChange.create).not.toHaveBeenCalled();
    });

    it("returns 409 on stale revision", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignContentEntry.findUnique.mockResolvedValueOnce({
        id: "entry-1",
        campaignId: "camp-1",
        type: "location",
        slug: "moon-harbor",
        name: "月港",
        entryJson: {},
        revision: 5,
        createdBy: "dm-1",
        updatedBy: "dm-1",
        createdAt: new Date(),
        updatedAt: new Date(),
        deletedAt: null,
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/content/entries/entry-1")
        .set("Authorization", `Bearer ${token}`)
        .send({
          baseRevision: 1,
          entry: { body: [{ type: "paragraph", text: "stale" }] },
        })
        .expect(409);
    });
  });

  describe("DELETE /api/campaigns/:campaignId/content/entries/:entryId", () => {
    it("lets the DM soft-delete an entry producing a tombstone", async () => {
      const token = await loginAs(storedDm);
      const existing = {
        id: "entry-1",
        campaignId: "camp-1",
        type: "location",
        slug: "moon-harbor",
        name: "月港",
        entryJson: {},
        revision: 1,
        createdBy: "dm-1",
        updatedBy: "dm-1",
        createdAt: new Date(),
        updatedAt: new Date(),
        deletedAt: null,
      };
      const tombstoned = {
        ...existing,
        revision: 2,
        deletedAt: new Date("2026-07-14T02:00:00.000Z"),
      };
      prismaService.campaignContentEntry.findUnique.mockResolvedValueOnce(existing);
      prismaService.campaignContentEntry.updateMany.mockResolvedValueOnce({ count: 1 });

      const res = await request(app.getHttpServer())
        .delete("/api/campaigns/camp-1/content/entries/entry-1")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body.deletedAt).not.toBeNull();
      const updateArgs = prismaService.campaignContentEntry.updateMany.mock.calls[0][0];
      expect(updateArgs.data.deletedAt).toBeInstanceOf(Date);
      expect(prismaService.campaignChange.create).toHaveBeenCalled();
      const changeArgs = prismaService.campaignChange.create.mock.calls[0][0];
      expect(changeArgs.data.operation).toBe("delete");
    });

    it("rejects a player with 403", async () => {
      const token = await loginAs(storedPlayer);

      await request(app.getHttpServer())
        .delete("/api/campaigns/camp-1/content/entries/entry-1")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });
  });

  describe("GET /api/campaigns/:campaignId/changes", () => {
    it("returns changes with entityType for a member", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignChange.findMany.mockResolvedValueOnce([
        {
          id: "change-1",
          campaignId: "camp-1",
          cursor: BigInt(1),
          entityType: "content",
          entityId: "entry-1",
          operation: "upsert",
          revision: 1,
          createdAt: new Date("2026-07-14T00:00:00Z"),
        },
      ]);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/changes?cursor=0")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body.items).toHaveLength(1);
      expect(res.body.items[0].entityType).toBe("content");
      expect(res.body.items[0].cursor).toBe("1");
      expect(res.body.nextCursor).toBe("1");
      expect(res.body.hasMore).toBe(false);
    });

    it("paginates with nextCursor without skipping items", async () => {
      const token = await loginAs(storedPlayer);
      const rows = Array.from({ length: 101 }, (_, index) => ({
        id: `change-${index + 1}`,
        campaignId: "camp-1",
        cursor: BigInt(index + 1),
        entityType: "content",
        entityId: `entry-${index + 1}`,
        operation: "upsert",
        revision: 1,
        createdAt: new Date(),
      }));
      prismaService.campaignChange.findMany.mockResolvedValueOnce(rows);

      const res = await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/changes?cursor=0&limit=100")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(res.body.items).toHaveLength(100);
      expect(res.body.hasMore).toBe(true);
      expect(res.body.nextCursor).toBe("100");
      // First item's cursor must be 1, not 2 — no items skipped
      expect(res.body.items[0].cursor).toBe("1");
      expect(res.body.items[99].cursor).toBe("100");
    });

    it("rejects a non-member with 403", async () => {
      const token = await loginAs(storedStranger);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/changes?cursor=0")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });
  });
});
