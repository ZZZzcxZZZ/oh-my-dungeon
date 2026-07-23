import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

// Plan 2026-07-23 task 3: dedicated archive e2e tests for wiki content,
// creator-based edit permissions, and full-text search across
// title/summary/body/tags. Independent from campaigns.e2e-spec.ts.
describe("campaign archive wiki endpoints", () => {
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
    { userId: "dm-2", role: "dm", displayName: "Co-DM" },
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
    campaignArchiveEntry: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      update: jest.fn(),
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
  };

  const storedDm = {
    id: "dm-1",
    username: "dm",
    email: "dm@example.com",
    passwordHash: "hashed-secret",
  };
  const storedCoDm = {
    id: "dm-2",
    username: "codm",
    email: "codm@example.com",
    passwordHash: "hashed-secret",
  };
  const storedPlayer = {
    id: "player-1",
    username: "player",
    email: "player@example.com",
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

    prismaService.campaignArchiveEntry.create.mockResolvedValue({
      id: "archive-1",
      campaignId: "camp-1",
      kind: "document",
      title: "Untitled",
      summary: "",
      payload: {},
      visibility: "members",
      pinned: false,
      createdBy: "dm-1",
      updatedBy: "dm-1",
      createdAt: "2026-07-16T00:00:00.000Z",
      updatedAt: "2026-07-16T00:00:00.000Z",
      deletedAt: null,
    });
    prismaService.campaignArchiveEntry.findMany.mockResolvedValue([]);
    prismaService.campaignArchiveEntry.findFirst.mockResolvedValue(null);
    prismaService.campaignArchiveEntry.update.mockResolvedValue({});
  });

  async function loginAs(user: typeof storedDm): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(user);
    const login = await request(app.getHttpServer())
      .post("/api/auth/login")
      .send({ identifier: user.username, password: "p@ssw0rd" })
      .expect(200);
    return login.body.accessToken;
  }

  describe("wiki content fields", () => {
    it("stores bodyBlocks, tags, links, and attachmentRefs inside payload on create", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignArchiveEntry.create.mockImplementationOnce(
        async (args: any) => ({
          id: "archive-1",
          campaignId: "camp-1",
          kind: args.data.kind,
          title: args.data.title,
          summary: args.data.summary,
          payload: args.data.payload,
          visibility: "members",
          pinned: false,
          createdBy: "dm-1",
          updatedBy: "dm-1",
          createdAt: "2026-07-16T00:00:00.000Z",
          updatedAt: "2026-07-16T00:00:00.000Z",
          deletedAt: null,
        }),
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "document",
          title: "Vallaki Gazetteer",
          summary: "Notes on the town of Vallaki.",
          bodyBlocks: [
            { type: "paragraph", text: "The town square hosts a weekly festival." },
            { type: "heading", text: "Notable Locations" },
          ],
          tags: ["vallaki", "barovia"],
          links: [
            { kind: "actor", id: "actor-1", label: "Ireena" },
          ],
          attachmentRefs: [
            { kind: "image", id: "asset-1", label: "Town Map" },
          ],
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body.title).toBe("Vallaki Gazetteer");
        });

      const createArgs = prismaService.campaignArchiveEntry.create.mock.calls[0][0];
      expect(createArgs.data.payload).toMatchObject({
        bodyBlocks: [
          { type: "paragraph", text: "The town square hosts a weekly festival." },
          { type: "heading", text: "Notable Locations" },
        ],
        tags: ["vallaki", "barovia"],
        links: [{ kind: "actor", id: "actor-1", label: "Ireena" }],
        attachmentRefs: [{ kind: "image", id: "asset-1", label: "Town Map" }],
      });
      expect(createArgs.data.createdBy).toBe("dm-1");
    });

    it("updates bodyBlocks, tags, links, and attachmentRefs on edit", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignArchiveEntry.findFirst.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "Vallaki Gazetteer",
        summary: "",
        payload: { tags: ["vallaki"] },
        pinned: false,
        createdBy: "dm-1",
        deletedAt: null,
      });
      prismaService.campaignArchiveEntry.update.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "Vallaki Gazetteer",
        summary: "Updated notes.",
        payload: {
          bodyBlocks: [{ type: "paragraph", text: "Updated text." }],
          tags: ["vallaki", "barovia"],
          links: [],
          attachmentRefs: [],
        },
        pinned: false,
        createdBy: "dm-1",
        updatedBy: "dm-1",
        updatedAt: "2026-07-16T01:00:00.000Z",
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .send({
          summary: "Updated notes.",
          bodyBlocks: [{ type: "paragraph", text: "Updated text." }],
          tags: ["vallaki", "barovia"],
          links: [],
          attachmentRefs: [],
        })
        .expect(200)
        .expect(({ body }) => {
          expect(body.payload.tags).toEqual(["vallaki", "barovia"]);
          expect(body.payload.bodyBlocks).toHaveLength(1);
        });

      const updateArgs = prismaService.campaignArchiveEntry.update.mock.calls[0][0];
      expect(updateArgs.data.payload).toMatchObject({
        bodyBlocks: [{ type: "paragraph", text: "Updated text." }],
        tags: ["vallaki", "barovia"],
      });
    });

    it("rejects invalid bodyBlocks and tags shapes", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "document",
          title: "Bad entry",
          bodyBlocks: "not-an-array",
        })
        .expect(400);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "document",
          title: "Bad entry",
          tags: ["valid", 123],
        })
        .expect(400);
    });

    // Plan 2026-07-23 task 4.1: element-level validation for bodyBlocks.
    // Without this, malformed bodyBlocks entries silently filter out on
    // the client (whereType<Map>) and the body section disappears.
    it("rejects bodyBlocks with non-object elements", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "document",
          title: "Bad blocks",
          bodyBlocks: ["just a string"],
        })
        .expect(400);
    });

    it("rejects bodyBlocks elements missing the type field", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "document",
          title: "Bad blocks",
          bodyBlocks: [{ text: "missing type field" }],
        })
        .expect(400);
    });

    it("rejects bodyBlocks elements with non-string type field", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "document",
          title: "Bad blocks",
          bodyBlocks: [{ type: 123, text: "wrong type" }],
        })
        .expect(400);
    });

    it("accepts well-formed bodyBlocks with paragraph and heading types", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "document",
          title: "Good blocks",
          bodyBlocks: [
            { type: "paragraph", text: "Hello world." },
            { type: "heading", text: "Section", level: 2 },
            { type: "list", items: ["a", "b"] },
          ],
        })
        .expect(201);
    });

    it("rejects malformed bodyBlocks on update", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignArchiveEntry.findFirst.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "Existing",
        summary: "",
        payload: {},
        pinned: false,
        createdBy: "dm-1",
        deletedAt: null,
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .send({
          bodyBlocks: [{ missing: "type" }],
        })
        .expect(400);
    });
  });

  describe("creator-based edit permissions", () => {
    it("lets the creator edit their own entry even if they are now a player", async () => {
      // dm-2 created the entry but is now a player (role changed from dm to
      // player). canManageCampaign would fail, but creator check passes.
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findFirst.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "Old note",
        summary: "",
        payload: {},
        pinned: false,
        createdBy: "player-1",
        deletedAt: null,
      });
      prismaService.campaignArchiveEntry.update.mockResolvedValueOnce({
        id: "archive-1",
        title: "Updated note",
        payload: {},
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ title: "Updated note" })
        .expect(200);
    });

    it("rejects edits from non-creator players", async () => {
      const token = await loginAs(storedPlayer);
      // Entry created by dm-1, player-1 is neither creator nor manager.
      prismaService.campaignArchiveEntry.findFirst.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "DM's note",
        summary: "",
        payload: {},
        pinned: false,
        createdBy: "dm-1",
        deletedAt: null,
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ title: "Hacked" })
        .expect(403);
    });

    it("lets a co-DM (manager) edit any entry", async () => {
      const token = await loginAs(storedCoDm);
      prismaService.campaignArchiveEntry.findFirst.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "DM's note",
        summary: "",
        payload: {},
        pinned: false,
        createdBy: "dm-1",
        deletedAt: null,
      });
      prismaService.campaignArchiveEntry.update.mockResolvedValueOnce({
        id: "archive-1",
        title: "Co-DM edit",
        payload: {},
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .send({ title: "Co-DM edit" })
        .expect(200);
    });

    it("lets the creator archive their own entry", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findFirst.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "Player's note",
        summary: "",
        payload: {},
        pinned: false,
        createdBy: "player-1",
        deletedAt: null,
      });
      prismaService.campaignArchiveEntry.update.mockResolvedValueOnce({
        id: "archive-1",
        deletedAt: new Date(),
      });

      await request(app.getHttpServer())
        .delete("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);
    });

    it("rejects archive deletion from non-creator players", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findFirst.mockResolvedValueOnce({
        id: "archive-1",
        campaignId: "camp-1",
        kind: "document",
        title: "DM's note",
        summary: "",
        payload: {},
        pinned: false,
        createdBy: "dm-1",
        deletedAt: null,
      });

      await request(app.getHttpServer())
        .delete("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });
  });

  describe("full-text search", () => {
    const entries = [
      {
        id: "a-1",
        campaignId: "camp-1",
        kind: "document",
        title: "Vallaki Gazetteer",
        summary: "Notes on the town.",
        payload: {
          bodyBlocks: [{ type: "paragraph", text: "The festival of the Burning Sun." }],
          tags: ["vallaki"],
        },
        pinned: false,
        createdBy: "dm-1",
        updatedAt: "2026-07-16T00:00:00.000Z",
        deletedAt: null,
      },
      {
        id: "a-2",
        campaignId: "camp-1",
        kind: "clue",
        title: "The Silver Key",
        summary: "Found in the chapel.",
        payload: {
          bodyBlocks: [{ type: "paragraph", text: "Opens the crypt beneath Vallaki." }],
          tags: ["crypt", "key"],
        },
        pinned: true,
        createdBy: "dm-1",
        updatedAt: "2026-07-16T01:00:00.000Z",
        deletedAt: null,
      },
      {
        id: "a-3",
        campaignId: "camp-1",
        kind: "location",
        title: "Castle Ravenloft",
        summary: "Strahd's domain.",
        payload: {
          bodyBlocks: [],
          tags: ["ravenloft"],
        },
        pinned: false,
        createdBy: "dm-1",
        updatedAt: "2026-07-16T02:00:00.000Z",
        deletedAt: null,
      },
    ];

    it("matches entries by title", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findMany.mockResolvedValueOnce(entries);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/archives?q=silver")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("a-2");
        });
    });

    it("matches entries by summary", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findMany.mockResolvedValueOnce(entries);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/archives?q=chapel")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("a-2");
        });
    });

    it("matches entries by body text", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findMany.mockResolvedValueOnce(entries);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/archives?q=festival")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("a-1");
        });
    });

    it("matches entries by tag", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findMany.mockResolvedValueOnce(entries);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/archives?q=ravenloft")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("a-3");
        });
    });

    it("returns all entries when no query is provided", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findMany.mockResolvedValueOnce(entries);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(3);
        });
    });

    it("combines kind filter with search query", async () => {
      const token = await loginAs(storedPlayer);
      prismaService.campaignArchiveEntry.findMany.mockResolvedValueOnce(
        entries.filter((e) => e.kind === "clue"),
      );

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/archives?kind=clue&q=crypt")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("a-2");
        });
    });
  });
});
