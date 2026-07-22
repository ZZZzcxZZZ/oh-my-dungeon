import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

describe("campaigns endpoints", () => {
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
      create: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    campaignMember: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    campaignInvite: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    campaignChatMessage: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      count: jest.fn(),
      update: jest.fn(),
    },
    journalEntry: {
      create: jest.fn(),
      findMany: jest.fn(),
    },
    campaignActor: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
    },
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
  const storedDmUser = {
    id: "user-1",
    username: "ranger",
    email: "ranger@example.com",
    passwordHash: "hashed-secret",
  };
  const storedPlayerUser = {
    id: "user-2",
    username: "bard",
    email: "bard@example.com",
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
    prismaService.campaignActor.findUnique.mockReset();
    prismaService.campaignActor.findUnique.mockResolvedValue(null);
    prismaService.campaignActor.findMany.mockResolvedValue([]);
    prismaService.campaignActor.create.mockReset();
    prismaService.campaignActor.create.mockResolvedValue({});
    prismaService.$queryRaw.mockResolvedValue([{ health_check: 1 }]);
    prismaService.serverSetting.findFirst.mockResolvedValue({
      registrationEnabled: true,
    });
    prismaService.user.count.mockResolvedValue(1);
    prismaService.user.findFirst.mockResolvedValue(null);
    prismaService.user.findUnique.mockResolvedValue(null);
    prismaService.user.create.mockResolvedValue(storedDmUser);
    prismaService.serverAdmin.create.mockResolvedValue({});
    prismaService.refreshToken.create.mockResolvedValue({});
    prismaService.refreshToken.findUnique.mockResolvedValue(null);
    prismaService.refreshToken.update.mockResolvedValue({});
    prismaService.$transaction.mockImplementation(async (cb: any) =>
      cb(prismaService),
    );
    passwordHashService.hash.mockResolvedValue("hashed-secret");
    passwordHashService.compare.mockResolvedValue(true);
    prismaService.campaign.create.mockResolvedValue({
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
    });
    prismaService.campaign.findUnique.mockResolvedValue(null);
    prismaService.campaign.findMany.mockResolvedValue([]);
    prismaService.campaignMember.create.mockResolvedValue({});
    prismaService.campaignMember.findUnique.mockResolvedValue(null);
    prismaService.campaignMember.findFirst.mockResolvedValue(null);
    prismaService.campaignMember.findMany.mockResolvedValue([]);
    prismaService.campaignMember.update.mockResolvedValue({});
    prismaService.campaignInvite.create.mockResolvedValue({});
    prismaService.campaignInvite.findUnique.mockResolvedValue(null);
    prismaService.campaignInvite.findFirst.mockResolvedValue(null);
    prismaService.campaignInvite.findMany.mockResolvedValue([]);
    prismaService.campaignInvite.update.mockResolvedValue({});
    prismaService.campaignChatMessage.create.mockResolvedValue({});
    prismaService.campaignChatMessage.findMany.mockResolvedValue([]);
    prismaService.campaignChatMessage.findFirst.mockResolvedValue(null);
    prismaService.campaignChatMessage.count.mockResolvedValue(0);
    prismaService.campaignChatMessage.update.mockResolvedValue({});
    prismaService.journalEntry.create.mockResolvedValue({});
    prismaService.journalEntry.findMany.mockResolvedValue([]);
    prismaService.campaignArchiveEntry.create.mockResolvedValue({
      id: "archive-1",
      campaignId: "camp-1",
      kind: "clue",
      title: "The silver key",
      summary: "Found below the chapel.",
      payload: {},
      visibility: "members",
      pinned: false,
      createdBy: "user-1",
      updatedBy: "user-1",
      createdAt: "2026-07-16T00:00:00.000Z",
      updatedAt: "2026-07-16T00:00:00.000Z",
      deletedAt: null,
    });
    prismaService.campaignArchiveEntry.findMany.mockResolvedValue([]);
    prismaService.campaignArchiveEntry.findFirst.mockResolvedValue(null);
    prismaService.campaignArchiveEntry.update.mockResolvedValue({});
  });

  async function loginAsDm(): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(storedDmUser);
    const login = await request(app.getHttpServer())
      .post("/api/auth/login")
      .send({ identifier: "ranger", password: "p@ssw0rd" })
      .expect(200);
    return login.body.accessToken;
  }

  async function loginAs(user: typeof storedDmUser): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(user);
    const login = await request(app.getHttpServer())
      .post("/api/auth/login")
      .send({ identifier: user.username, password: "p@ssw0rd" })
      .expect(200);
    return login.body.accessToken;
  }

  describe("POST /api/campaigns", () => {
    it("creates a campaign and returns it without internal fields", async () => {
      const token = await loginAsDm();

      await request(app.getHttpServer())
        .post("/api/campaigns")
        .set("Authorization", `Bearer ${token}`)
        .send({ name: "Curse of Strahd" })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("camp-1");
          expect(body.name).toBe("Curse of Strahd");
          expect(body.ownerId).toBe("user-1");
        });

      const createArgs = prismaService.campaign.create.mock.calls[0][0];
      expect(createArgs.data.ownerId).toBe("user-1");
      expect(createArgs.data.name).toBe("Curse of Strahd");
    });

    it("makes the creator an owner member", async () => {
      const token = await loginAsDm();

      await request(app.getHttpServer())
        .post("/api/campaigns")
        .set("Authorization", `Bearer ${token}`)
        .send({ name: "Curse of Strahd" })
        .expect(201);

      const memberArgs = prismaService.campaignMember.create.mock.calls[0][0];
      expect(memberArgs.data.userId).toBe("user-1");
      expect(memberArgs.data.role).toBe("owner");
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer())
        .post("/api/campaigns")
        .send({ name: "Curse of Strahd" })
        .expect(401);
    });

    it("rejects with missing name with 400", async () => {
      const token = await loginAsDm();

      await request(app.getHttpServer())
        .post("/api/campaigns")
        .set("Authorization", `Bearer ${token}`)
        .send({})
        .expect(400);
    });
  });

  describe("GET /api/campaigns", () => {
    it("returns campaigns the user is a member of", async () => {
      const token = await loginAsDm();
      prismaService.campaignMember.findMany.mockResolvedValueOnce([
        {
          campaignId: "camp-1",
          campaign: {
            id: "camp-1",
            name: "Curse of Strahd",
            description: "",
            system: "dnd5e",
            ownerId: "user-1",
            status: "active",
            createdAt: "2026-07-09T00:00:00.000Z",
            updatedAt: "2026-07-09T00:00:00.000Z",
            members: [
              {
                userId: "user-1",
                role: "owner",
                displayName: "ranger",
              },
            ],
            chatMessages: [],
          },
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("camp-1");
          expect(body[0].name).toBe("Curse of Strahd");
          expect(body[0].lastMessage).toBeNull();
          expect(body[0].unreadCount).toBe(0);
          expect(body[0].memberPreview).toEqual([
            {
              userId: "user-1",
              displayName: "ranger",
              role: "owner",
            },
          ]);
        });
    });

    it("returns lastMessage and memberPreview when populated", async () => {
      const token = await loginAsDm();
      prismaService.campaignMember.findMany.mockResolvedValueOnce([
        {
          campaignId: "camp-1",
          campaign: {
            id: "camp-1",
            name: "Curse of Strahd",
            description: "",
            system: "dnd5e",
            ownerId: "user-1",
            status: "active",
            createdAt: "2026-07-09T00:00:00.000Z",
            updatedAt: "2026-07-09T00:00:00.000Z",
            members: [
              {
                userId: "user-1",
                role: "owner",
                displayName: "ranger",
              },
              {
                userId: "user-2",
                role: "player",
                displayName: "bard",
              },
            ],
            chatMessages: [
              {
                id: "msg-1",
                campaignId: "camp-1",
                senderId: "user-2",
                campaignActorId: null,
                displayName: "bard",
                avatarUrl: null,
                kind: "say",
                content: "Hello world",
                createdAt: "2026-07-12T00:00:00.000Z",
              },
            ],
          },
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body[0].lastMessage).toEqual({
            id: "msg-1",
            campaignId: "camp-1",
            senderId: "user-2",
            campaignActorId: null,
            displayName: "bard",
            avatarUrl: null,
            speakerMode: "actor",
            delegatedByUserId: null,
            speakerAvatarAssetId: null,
            publicHealthState: null,
            publicHealthFraction: null,
            ooc: false,
            kind: "say",
            content: "Hello world",
            actionSnapshot: null,
            eventData: null,
            createdAt: "2026-07-12T00:00:00.000Z",
          });
          expect(body[0].memberPreview).toHaveLength(2);
          expect(body[0].memberPreview[0]).toEqual({
            userId: "user-1",
            displayName: "ranger",
            role: "owner",
          });
        });
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer()).get("/api/campaigns").expect(401);
    });
  });

  describe("GET /api/campaigns/:id", () => {
    it("returns the campaign for a member", async () => {
      const token = await loginAsDm();
      const campaign = {
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [{ userId: "user-1", role: "owner" }],
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.id).toBe("camp-1");
          expect(body.name).toBe("Curse of Strahd");
        });
    });

    it("rejects non-members with 403", async () => {
      const token = await loginAsDm();
      const campaign = {
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-2",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [{ userId: "user-2", role: "owner" }],
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });

    it("returns 404 when campaign does not exist", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .get("/api/campaigns/missing")
        .set("Authorization", `Bearer ${token}`)
        .expect(404);
    });
  });

  describe("POST /api/campaigns/:id/invites", () => {
    const campaignWithOwner = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [{ userId: "user-1", role: "owner" }],
    };

    it("creates an invite and returns it without internal fields", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignInvite.create.mockResolvedValueOnce({
        id: "invite-1",
        campaignId: "camp-1",
        code: "ABC123XYZ",
        roleOnJoin: "player",
        expiresAt: null,
        maxUses: 1,
        usedCount: 0,
        requireApproval: false,
        createdBy: "user-1",
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/invites")
        .set("Authorization", `Bearer ${token}`)
        .send({ roleOnJoin: "player", maxUses: 1 })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("invite-1");
          expect(body.campaignId).toBe("camp-1");
          expect(body.code).toBe("ABC123XYZ");
          expect(body.roleOnJoin).toBe("player");
          expect(body.maxUses).toBe(1);
          expect(body.usedCount).toBe(0);
          expect(body.requireApproval).toBe(false);
          expect(body.expiresAt).toBeNull();
        });

      const createArgs = prismaService.campaignInvite.create.mock.calls[0][0];
      expect(createArgs.data.campaignId).toBe("camp-1");
      expect(createArgs.data.createdBy).toBe("user-1");
      expect(createArgs.data.code).toEqual(expect.any(String));
    });

    it("always creates player invites even when a manager submits dm", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignInvite.create.mockResolvedValueOnce({
        id: "invite-1",
        campaignId: "camp-1",
        code: "ABC123XYZ",
        roleOnJoin: "player",
        expiresAt: null,
        maxUses: 1,
        usedCount: 0,
        requireApproval: false,
        createdBy: "user-1",
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/invites")
        .set("Authorization", `Bearer ${token}`)
        .send({ roleOnJoin: "dm" })
        .expect(201);

      expect(
        prismaService.campaignInvite.create.mock.calls[0][0].data.roleOnJoin,
      ).toBe("player");
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/invites")
        .send({ roleOnJoin: "player" })
        .expect(401);
    });

    it("rejects a non-manager with 403", async () => {
      const token = await loginAsDm();
      const campaignWithPlayerOnly = {
        ...campaignWithOwner,
        ownerId: "user-2",
        members: [{ userId: "user-1", role: "player" }],
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithPlayerOnly,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/invites")
        .set("Authorization", `Bearer ${token}`)
        .send({ roleOnJoin: "player" })
        .expect(403);
    });

    it("returns 404 when campaign does not exist", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/missing/invites")
        .set("Authorization", `Bearer ${token}`)
        .send({ roleOnJoin: "player" })
        .expect(404);
    });
  });

  describe("GET /api/campaigns/:id/invites", () => {
    const campaignWithOwner = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [{ userId: "user-1", role: "owner" }],
    };

    it("returns invites for a manager", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignInvite.findMany.mockResolvedValueOnce([
        {
          id: "invite-1",
          campaignId: "camp-1",
          code: "ABC123",
          roleOnJoin: "player",
          expiresAt: null,
          maxUses: 1,
          usedCount: 0,
          requireApproval: false,
          createdBy: "user-1",
          createdAt: "2026-07-09T00:00:00.000Z",
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/invites")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("invite-1");
          expect(body[0].code).toBe("ABC123");
        });
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/invites")
        .expect(401);
    });

    it("rejects a non-manager with 403", async () => {
      const token = await loginAsDm();
      const campaignWithPlayerOnly = {
        ...campaignWithOwner,
        ownerId: "user-2",
        members: [{ userId: "user-1", role: "player" }],
      };
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithPlayerOnly,
      );

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/invites")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });
  });

  describe("campaign chat messages", () => {
    it("requires a player character binding before roleplay messages", async () => {
      const token = await loginAs(storedPlayerUser);
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [
          { userId: "user-1", role: "owner" },
          {
            userId: "user-2",
            role: "player",
            boundActorId: null,
            activeSpeakerActorId: null,
            speakerMode: "ooc",
          },
        ],
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({ kind: "say", content: "I draw my sword." })
        .expect(403);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("uses the saved DM speaker actor when a message omits campaignActorId", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [
          {
            userId: "user-1",
            role: "owner",
            activeSpeakerActorId: "npc-1",
            speakerMode: "actor",
          },
        ],
      });
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "npc-1",
        campaignId: "camp-1",
        ownerUserId: null,
        actorType: "npc",
        status: "active",
        sheetJson: { name: "The Innkeeper", currentHp: 8, maxHp: 8 },
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-speaker",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: "npc-1",
        displayName: "The Innkeeper",
        avatarUrl: null,
        kind: "say",
        content: "Welcome to the tavern.",
        speakerMode: "actor",
        publicHealthState: "healthy",
        publicHealthFraction: 1,
        ooc: false,
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({ kind: "say", content: "Welcome to the tavern." })
        .expect(201)
        .expect(({ body }) => {
          expect(body.campaignActorId).toBe("npc-1");
          expect(body.displayName).toBe("The Innkeeper");
          expect(body.speakerMode).toBe("actor");
          expect(body.publicHealthState).toBe("healthy");
          expect(body.publicHealthFraction).toBe(1);
        });

      expect(
        prismaService.campaignChatMessage.create.mock.calls[0][0].data
          .publicHealthFraction,
      ).toBe(1);
    });

    it("persists narrator messages with the narrator identity", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [
          {
            userId: "user-1",
            role: "owner",
            speakerMode: "narrator",
            activeSpeakerActorId: null,
          },
        ],
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-narrator",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: null,
        displayName: "旁白 / DM",
        avatarUrl: null,
        kind: "say",
        content: "The door closes behind you.",
        speakerMode: "narrator",
        publicHealthState: null,
        ooc: false,
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({ kind: "say", content: "The door closes behind you." })
        .expect(201);

      expect(
        prismaService.campaignChatMessage.create.mock.calls[0][0].data,
      ).toEqual(
        expect.objectContaining({
          campaignActorId: null,
          displayName: "旁白 / DM",
          speakerMode: "narrator",
        }),
      );
    });
    const campaignWithOwner = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [{ userId: "user-1", role: "owner" }],
    };

    it("lists messages directly under a campaign without a session", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignChatMessage.findMany.mockResolvedValueOnce([
        {
          id: "msg-1",
          campaignId: "camp-1",
          senderId: "user-1",
          campaignActorId: "actor-1",
          displayName: "Arannis",
          avatarUrl: null,
          kind: "say",
          content: "今晚从酒馆开始",
          createdAt: "2026-07-09T00:00:00.000Z",
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0]).toMatchObject({
            id: "msg-1",
            campaignId: "camp-1",
            senderId: "user-1",
            campaignActorId: "actor-1",
            displayName: "Arannis",
            avatarUrl: null,
            kind: "say",
            content: "今晚从酒馆开始",
            createdAt: "2026-07-09T00:00:00.000Z",
          });
        });
    });

    it("searches campaign messages on the server for a campaign member", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1", ownerId: "user-1", members: [{ userId: "user-1", role: "owner" }],
      });
      prismaService.campaignChatMessage.findMany.mockResolvedValueOnce([]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/messages?query=chapel")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(prismaService.campaignChatMessage.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { campaignId: "camp-1", content: { contains: "chapel", mode: "insensitive" } },
        }),
      );
    });

    it("creates action messages directly under a campaign", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "user-1",
        sheetJson: { name: "Arannis", avatarUrl: null },
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-2",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: "actor-1",
        displayName: "Arannis",
        avatarUrl: null,
        kind: "action",
        content: "推开吱呀作响的木门",
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "action",
          content: "推开吱呀作响的木门",
          campaignActorId: "actor-1",
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("msg-2");
          expect(body.kind).toBe("action");
          expect(body.displayName).toBe("Arannis");
        });

      const createArgs =
        prismaService.campaignChatMessage.create.mock.calls[0][0];
      expect(createArgs.data).toMatchObject({
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: "actor-1",
        displayName: "Arannis",
        avatarUrl: null,
        kind: "action",
        content: "推开吱呀作响的木门",
      });
      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledWith(
        "camp-1",
        "campaign:message:new",
        expect.objectContaining({
          id: "msg-2",
          campaignId: "camp-1",
          kind: "action",
          displayName: "Arannis",
        }),
      );
    });

    it("preserves structured roll messages instead of coercing them to say", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "user-1",
        sheetJson: { name: "Arannis", avatarUrl: null },
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-roll",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: "actor-1",
        displayName: "Arannis",
        avatarUrl: null,
        kind: "roll",
        content: "察觉 17",
        eventData: {
          notation: "1d20+5",
          total: 17,
          label: "察觉",
        },
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "roll",
          content: "察觉 17",
          campaignActorId: "actor-1",
          eventData: {
            notation: "1d20+5",
            total: 17,
            label: "察觉",
          },
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body.kind).toBe("roll");
          expect(body.eventData).toEqual({
            notation: "1d20+5",
            total: 17,
            label: "察觉",
          });
        });

      expect(
        prismaService.campaignChatMessage.create.mock.calls[0][0].data,
      ).toMatchObject({
        kind: "roll",
        eventData: {
          notation: "1d20+5",
          total: 17,
          label: "察觉",
        },
      });
    });

    it("allows the owner to request a player actor skill check", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-player",
        campaignId: "camp-1",
        ownerUserId: "user-2",
        sheetJson: { name: "Mira" },
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-check",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: null,
        displayName: "ranger",
        avatarUrl: null,
        kind: "checkRequest",
        content: "请 Mira 进行察觉检定",
        eventData: {
          targetActorId: "actor-player",
          checkType: "skill",
          checkKey: "察觉",
          label: "察觉检定",
          dc: 15,
          rollMode: "normal",
        },
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "checkRequest",
          content: "请 Mira 进行察觉检定",
          eventData: {
            targetActorId: "actor-player",
            checkType: "skill",
            checkKey: "察觉",
            label: "察觉检定",
            dc: 15,
            rollMode: "normal",
          },
        })
        .expect(201);

      expect(
        prismaService.campaignChatMessage.create.mock.calls[0][0].data,
      ).toMatchObject({
        kind: "checkRequest",
        eventData: {
          targetActorId: "actor-player",
          checkType: "skill",
          checkKey: "察觉",
          dc: 15,
        },
      });
    });

    it("rejects system messages from players", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        ...campaignWithOwner,
        ownerId: "user-2",
        members: [{ userId: "user-1", role: "player" }],
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "system",
          content: "Mira 获得长剑",
          eventData: { eventType: "itemGranted" },
        })
        .expect(403);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("derives an action snapshot from the campaign actor sheet", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "user-1",
        revision: 3,
        sheetJson: {
          name: "Arannis",
          avatarUrl: null,
          data: {
            actions: [
              {
                id: "action-surge",
                name: "动作如潮",
                entryId: "guide:feature/action-surge",
                formula: "1/use",
              },
            ],
          },
        },
      });
      const actionSnapshot = {
        id: "action-surge",
        name: "动作如潮",
        entryId: "guide:feature/action-surge",
        formula: "1/use",
        actorRevision: 3,
      };
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-action",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: "actor-1",
        displayName: "Arannis",
        avatarUrl: null,
        kind: "action",
        content: "动作如潮",
        actionSnapshot,
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "action",
          content: "伪造的动作名",
          campaignActorId: "actor-1",
          actionId: "action-surge",
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body.content).toBe("动作如潮");
          expect(body.actionSnapshot).toEqual(actionSnapshot);
        });

      expect(
        prismaService.campaignChatMessage.create.mock.calls[0][0].data,
      ).toMatchObject({
        content: "动作如潮",
        actionSnapshot,
      });
    });

    it("rejects an action id missing from the campaign actor sheet", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "user-1",
        revision: 3,
        sheetJson: { name: "Arannis", data: { actions: [] } },
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "action",
          content: "伪造动作",
          campaignActorId: "actor-1",
          actionId: "not-owned",
        })
        .expect(400);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("ignores client-sent displayName and derives from actor sheet", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "user-1",
        sheetJson: { name: "Arannis", avatarUrl: null },
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-3",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: "actor-1",
        displayName: "Arannis",
        avatarUrl: null,
        kind: "say",
        content: "test",
        createdAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          content: "test",
          campaignActorId: "actor-1",
          displayName: "HACKED",
          avatarUrl: "http://evil",
        })
        .expect(201);

      const createArgs =
        prismaService.campaignChatMessage.create.mock.calls[0][0];
      expect(createArgs.data.displayName).toBe("Arannis");
      expect(createArgs.data.avatarUrl).toBeNull();
      expect(createArgs.data.campaignActorId).toBe("actor-1");
    });

    it("rejects actor from different campaign", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "other-campaign",
        ownerUserId: "user-1",
        sheetJson: {},
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          content: "test",
          campaignActorId: "actor-1",
        })
        .expect(400);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("rejects campaign chat access for non-members", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        ...campaignWithOwner,
        ownerId: "user-2",
        members: [{ userId: "user-2", role: "owner" }],
      });

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });

    it("atomically creates a temporary actor with the first draft message", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        ...campaignWithOwner,
        members: [
          {
            userId: "user-1",
            role: "owner",
            boundActorId: null,
            activeSpeakerActorId: null,
            speakerMode: "ooc",
          },
        ],
      });
      const createdActorRow = {
        id: "temp-actor-1",
        campaignId: "camp-1",
        ownerUserId: null,
        sourceCharacterId: null,
        actorType: "npc",
        status: "active",
        lifecycle: "temporary",
        avatarAssetId: null,
        healthVisibility: "ownerAndDm",
        sheetJson: { name: "旅店老板", currentHp: 1, maxHp: 1, avatarUrl: null },
        revision: 1,
        updatedBy: "user-1",
      };
      prismaService.campaignActor.create.mockResolvedValueOnce(createdActorRow);
      prismaService.campaignMember.update.mockResolvedValueOnce({
        userId: "user-1",
        activeSpeakerActorId: "temp-actor-1",
        speakerMode: "actor",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-draft-1",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: "temp-actor-1",
        displayName: "旅店老板",
        avatarUrl: null,
        speakerMode: "actor",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: "healthy",
        publicHealthFraction: 1,
        ooc: false,
        kind: "say",
        content: "欢迎光临",
        actionSnapshot: null,
        eventData: null,
        createdAt: "2026-07-17T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "say",
          content: "欢迎光临",
          draftActor: { displayName: "旅店老板" },
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body.campaignActorId).toBe("temp-actor-1");
          expect(body.displayName).toBe("旅店老板");
          expect(body.speakerMode).toBe("actor");
          expect(body.publicHealthState).toBe("healthy");
          expect(body.publicHealthFraction).toBe(1);
        });

      const actorCreateArgs = prismaService.campaignActor.create.mock.calls[0][0];
      expect(actorCreateArgs.data.lifecycle).toBe("temporary");
      expect(actorCreateArgs.data.actorType).toBe("npc");
      expect(actorCreateArgs.data.sheetJson.name).toBe("旅店老板");
      expect(actorCreateArgs.data.status).toBe("active");

      const memberUpdateArgs =
        prismaService.campaignMember.update.mock.calls[0][0];
      expect(memberUpdateArgs.data.activeSpeakerActorId).toBe("temp-actor-1");
      expect(memberUpdateArgs.data.speakerMode).toBe("actor");

      const messageCreateArgs =
        prismaService.campaignChatMessage.create.mock.calls[0][0];
      expect(messageCreateArgs.data.campaignActorId).toBe("temp-actor-1");
      expect(messageCreateArgs.data.displayName).toBe("旅店老板");
      expect(messageCreateArgs.data.kind).toBe("say");
    });

    it("rejects draftActor from non-managers", async () => {
      const token = await loginAs(storedPlayerUser);
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        ...campaignWithOwner,
        members: [
          {
            userId: "user-1",
            role: "owner",
          },
          {
            userId: "user-2",
            role: "player",
            boundActorId: null,
            activeSpeakerActorId: null,
            speakerMode: "ooc",
          },
        ],
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "say",
          content: "测试",
          draftActor: { displayName: "伪装者" },
        })
        .expect(403);

      expect(prismaService.campaignActor.create).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("leaves no orphan actor when the draft transaction fails", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        ...campaignWithOwner,
        members: [
          {
            userId: "user-1",
            role: "owner",
            boundActorId: null,
            activeSpeakerActorId: null,
            speakerMode: "ooc",
          },
        ],
      });
      prismaService.campaignActor.create.mockRejectedValueOnce(
        new Error("db write failure"),
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "say",
          content: "欢迎光临",
          draftActor: { displayName: "旅店老板" },
        })
        .expect(500);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });
  });

  describe("GET /api/campaigns/:id/check-requests", () => {
    const campaignWithOwner = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [{ userId: "user-1", role: "owner" }],
    };

    it("returns check requests with their responses", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignChatMessage.findMany.mockResolvedValueOnce([
        {
          id: "msg-roll-1",
          campaignId: "camp-1",
          senderId: "user-2",
          campaignActorId: "actor-player",
          displayName: "Mira",
          avatarUrl: null,
          speakerMode: "actor",
          delegatedByUserId: null,
          speakerAvatarAssetId: null,
          publicHealthState: null,
          ooc: false,
          kind: "roll",
          content: "察觉 17",
          actionSnapshot: null,
          eventData: { requestId: "msg-check-1", total: 17, label: "察觉" },
          createdAt: "2026-07-09T00:01:00.000Z",
        },
        {
          id: "msg-check-1",
          campaignId: "camp-1",
          senderId: "user-1",
          campaignActorId: null,
          displayName: "ranger",
          avatarUrl: null,
          speakerMode: "narrator",
          delegatedByUserId: null,
          speakerAvatarAssetId: null,
          publicHealthState: null,
          ooc: false,
          kind: "checkRequest",
          content: "请 Mira 进行察觉检定",
          actionSnapshot: null,
          eventData: {
            targetActorId: "actor-player",
            checkType: "skill",
            checkKey: "察觉",
            label: "察觉检定",
            dc: 15,
            rollMode: "normal",
          },
          createdAt: "2026-07-09T00:00:00.000Z",
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/check-requests")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].message.id).toBe("msg-check-1");
          expect(body[0].message.kind).toBe("checkRequest");
          expect(body[0].status).toBe("open");
          expect(body[0].responses).toHaveLength(1);
          expect(body[0].responses[0].id).toBe("msg-roll-1");
          expect(body[0].responses[0].eventData.requestId).toBe("msg-check-1");
        });
    });

    it("returns empty list when no check requests exist", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignChatMessage.findMany.mockResolvedValueOnce([]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/check-requests")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toEqual([]);
        });
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/check-requests")
        .expect(401);
    });
  });

  describe("GET /api/campaigns/:id/journal", () => {
    const campaignWithOwner = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [{ userId: "user-1", role: "owner" }],
    };

    it("returns journal entries ordered by createdAt asc", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.journalEntry.findMany.mockResolvedValueOnce([
        {
          id: "je-1",
          campaignId: "camp-1",
          sessionId: null,
          type: "check_request",
          summary: "请 Mira 进行察觉检定",
          refId: "msg-check-1",
          createdAt: "2026-07-09T00:00:00.000Z",
        },
        {
          id: "je-2",
          campaignId: "camp-1",
          sessionId: null,
          type: "roll",
          summary: "Mira 察觉 17",
          refId: "msg-roll-1",
          createdAt: "2026-07-09T00:01:00.000Z",
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/journal")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(2);
          expect(body[0].id).toBe("je-1");
          expect(body[0].type).toBe("check_request");
          expect(body[0].summary).toBe("请 Mira 进行察觉检定");
          expect(body[0].refId).toBe("msg-check-1");
          expect(body[1].id).toBe("je-2");
        });
    });

    it("filters by type when query param provided", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.journalEntry.findMany.mockResolvedValueOnce([]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/journal?type=roll")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(prismaService.journalEntry.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            campaignId: "camp-1",
            type: "roll",
          }),
        }),
      );
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/journal")
        .expect(401);
    });
  });

  describe("POST /api/campaigns/:id/messages journal side-effects", () => {
    const campaignWithOwner = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [{ userId: "user-1", role: "owner" }],
    };

    it("writes a journal entry when sending a system message", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-sys-1",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: null,
        displayName: "旁白 / DM",
        avatarUrl: null,
        speakerMode: "narrator",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: null,
        ooc: false,
        kind: "system",
        content: "夜幕降临",
        actionSnapshot: null,
        eventData: null,
        createdAt: "2026-07-09T00:05:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "system",
          content: "夜幕降临",
        })
        .expect(201);

      expect(prismaService.journalEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            campaignId: "camp-1",
            type: "system",
            summary: "夜幕降临",
            refId: "msg-sys-1",
          }),
        }),
      );
      expect(prismaService.$transaction).toHaveBeenCalledTimes(1);
    });

    it("writes a journal entry when sending a checkRequest message", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-mira",
        campaignId: "camp-1",
        ownerUserId: "user-2",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Mira" },
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-check-1",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: null,
        displayName: "旁白 / DM",
        avatarUrl: null,
        speakerMode: "narrator",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: null,
        ooc: false,
        kind: "checkRequest",
        content: "请 Mira 进行察觉检定",
        actionSnapshot: null,
        eventData: {
          targetActorId: "actor-mira",
          checkType: "skill",
          checkKey: "察觉",
          label: "察觉检定",
          dc: 15,
          rollMode: "normal",
        },
        createdAt: "2026-07-09T00:06:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "checkRequest",
          content: "请 Mira 进行察觉检定",
          eventData: {
            targetActorId: "actor-mira",
            checkType: "skill",
            checkKey: "察觉",
            label: "察觉检定",
            dc: 15,
            rollMode: "normal",
          },
        })
        .expect(201);

      expect(prismaService.journalEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            campaignId: "camp-1",
            type: "check_request",
            refId: "msg-check-1",
          }),
        }),
      );
    });

    it("writes a journal entry when sending a roll message", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-roll-1",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: null,
        displayName: "ranger",
        avatarUrl: null,
        speakerMode: "actor",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: null,
        ooc: false,
        kind: "roll",
        content: "攻击 18",
        actionSnapshot: null,
        eventData: { notation: "1d20+5", total: 18, label: "攻击" },
        createdAt: "2026-07-09T00:07:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "roll",
          content: "攻击 18",
          eventData: { notation: "1d20+5", total: 18, label: "攻击" },
        })
        .expect(201);

      expect(prismaService.journalEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            campaignId: "camp-1",
            type: "roll",
            refId: "msg-roll-1",
          }),
        }),
      );
    });

    it("does not write a journal entry for plain say messages", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwner,
      );
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-say-1",
        campaignId: "camp-1",
        senderId: "user-1",
        campaignActorId: null,
        displayName: "ranger",
        avatarUrl: null,
        speakerMode: "actor",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: null,
        ooc: false,
        kind: "say",
        content: "大家好",
        actionSnapshot: null,
        eventData: null,
        createdAt: "2026-07-09T00:08:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "say",
          content: "大家好",
        })
        .expect(201);

      expect(prismaService.journalEntry.create).not.toHaveBeenCalled();
    });
  });

  describe("POST /api/campaigns/:id/messages check request response", () => {
    const campaignWithOwnerAndPlayer = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [
        { userId: "user-1", role: "owner" },
        {
          userId: "user-2",
          role: "player",
          boundActorId: "actor-player",
          activeSpeakerActorId: "actor-player",
          speakerMode: "actor",
        },
      ],
    };

    it("rejects a duplicate response with 409", async () => {
      const token = await loginAs(storedPlayerUser);
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwnerAndPlayer,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-player",
        campaignId: "camp-1",
        ownerUserId: "user-2",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Mira", avatarUrl: null },
      });
      // 原始 checkRequest 消息存在
      prismaService.campaignChatMessage.findFirst
        .mockResolvedValueOnce({
          id: "msg-check-1",
          campaignId: "camp-1",
          kind: "checkRequest",
          eventData: {
            targetActorId: "actor-player",
            checkType: "skill",
            checkKey: "察觉",
            rollMode: "normal",
          },
        })
        // 玩家已响应过
        .mockResolvedValueOnce({
          id: "msg-roll-prev",
          campaignId: "camp-1",
          senderId: "user-2",
          kind: "roll",
          eventData: { requestId: "msg-check-1", total: 12 },
        });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "roll",
          content: "察觉 15",
          campaignActorId: "actor-player",
          eventData: {
            requestId: "msg-check-1",
            total: 15,
            label: "察觉",
          },
        })
        .expect(409);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("rejects a response to a non-existent check request with 400", async () => {
      const token = await loginAs(storedPlayerUser);
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwnerAndPlayer,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-player",
        campaignId: "camp-1",
        ownerUserId: "user-2",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Mira", avatarUrl: null },
      });
      prismaService.campaignChatMessage.findFirst.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "roll",
          content: "察觉 15",
          campaignActorId: "actor-player",
          eventData: {
            requestId: "msg-missing",
            total: 15,
            label: "察觉",
          },
        })
        .expect(400);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("rejects a response sent as a different actor than the request target", async () => {
      const token = await loginAs(storedPlayerUser);
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwnerAndPlayer,
      );
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-player",
        campaignId: "camp-1",
        ownerUserId: "user-2",
        actorType: "player",
        status: "active",
        sheetJson: { name: "Mira", avatarUrl: null },
      });
      prismaService.campaignChatMessage.findFirst
        .mockResolvedValueOnce({
          id: "msg-check-other",
          campaignId: "camp-1",
          kind: "checkRequest",
          eventData: { targetActorId: "actor-other", status: "open" },
        })
        .mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "roll",
          content: "察觉 15",
          campaignActorId: "actor-player",
          eventData: {
            requestId: "msg-check-other",
            total: 15,
            label: "察觉",
          },
        })
        .expect(403);

      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });
  });

  describe("campaign workspace membership", () => {
    it("lets a member bind their own active player actor", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [{ userId: "user-1", role: "owner" }],
      });
      prismaService.campaignActor.findUnique.mockResolvedValueOnce({
        id: "actor-1",
        campaignId: "camp-1",
        ownerUserId: "user-1",
        actorType: "player",
        status: "active",
      });
      prismaService.campaignMember.findFirst.mockResolvedValueOnce({
        id: "member-1",
        campaignId: "camp-1",
        userId: "user-1",
        role: "owner",
        displayName: "ranger",
        boundActorId: null,
        activeSpeakerActorId: null,
        speakerMode: "boundActor",
        lastReadAt: null,
        joinedAt: "2026-07-09T00:00:00.000Z",
      });
      prismaService.campaignMember.update.mockResolvedValueOnce({
        id: "member-1",
        campaignId: "camp-1",
        userId: "user-1",
        role: "owner",
        displayName: "ranger",
        boundActorId: "actor-1",
        activeSpeakerActorId: "actor-1",
        speakerMode: "boundActor",
        lastReadAt: null,
        joinedAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/members/user-1/binding")
        .set("Authorization", `Bearer ${token}`)
        .send({ actorId: "actor-1" })
        .expect(200)
        .expect(({ body }) => {
          expect(body.boundActorId).toBe("actor-1");
          expect(body.activeSpeakerActorId).toBe("actor-1");
          expect(body.speakerMode).toBe("boundActor");
        });

      expect(prismaService.campaignMember.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: "member-1" },
          data: expect.objectContaining({
            boundActorId: "actor-1",
            activeSpeakerActorId: "actor-1",
          }),
        }),
      );
    });

    it("returns a viewer-scoped campaign workspace context", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [
          {
            id: "member-1",
            userId: "user-1",
            role: "owner",
            displayName: "ranger",
            boundActorId: "actor-1",
            activeSpeakerActorId: "actor-1",
            speakerMode: "boundActor",
            lastReadAt: null,
            joinedAt: "2026-07-09T00:00:00.000Z",
          },
        ],
      });
      prismaService.campaignActor.findMany.mockResolvedValueOnce([
        {
          id: "actor-1",
          campaignId: "camp-1",
          ownerUserId: "user-1",
          actorType: "player",
          status: "active",
          lifecycle: "persistent",
          avatarAssetId: null,
          healthVisibility: "ownerAndDm",
          sheetJson: { name: "Ranger", currentHp: 12, maxHp: 18 },
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/context")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body.membership.boundActorId).toBe("actor-1");
          expect(body.capabilities.canManageCampaign).toBe(true);
          expect(body.actors).toEqual([
            expect.objectContaining({
              id: "actor-1",
              displayName: "Ranger",
              publicHealthState: "healthy",
            }),
          ]);
        });
    });

    it("lets a DM select narrator as the active speaker", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [
          {
            id: "member-1",
            userId: "user-1",
            role: "owner",
            displayName: "ranger",
            boundActorId: null,
            activeSpeakerActorId: null,
            speakerMode: "ooc",
            lastReadAt: null,
            joinedAt: "2026-07-09T00:00:00.000Z",
          },
        ],
      });
      prismaService.campaignMember.update.mockResolvedValueOnce({
        id: "member-1",
        campaignId: "camp-1",
        userId: "user-1",
        role: "owner",
        displayName: "ranger",
        boundActorId: null,
        activeSpeakerActorId: null,
        speakerMode: "narrator",
        lastReadAt: null,
        joinedAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/speaker")
        .set("Authorization", `Bearer ${token}`)
        .send({ speakerMode: "narrator" })
        .expect(200)
        .expect(({ body }) => {
          expect(body.speakerMode).toBe("narrator");
          expect(body.activeSpeakerActorId).toBeNull();
        });
    });

    it("marks a campaign read using the authenticated member, not a client timestamp", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce({
        id: "camp-1",
        name: "Curse of Strahd",
        description: "",
        system: "dnd5e",
        ownerId: "user-1",
        status: "active",
        createdAt: "2026-07-09T00:00:00.000Z",
        updatedAt: "2026-07-09T00:00:00.000Z",
        members: [{ id: "member-1", userId: "user-1", role: "owner", displayName: "ranger" }],
      });
      prismaService.campaignMember.update.mockResolvedValueOnce({
        id: "member-1",
        campaignId: "camp-1",
        userId: "user-1",
        role: "owner",
        displayName: "ranger",
        lastReadAt: "2026-07-16T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/read")
        .set("Authorization", `Bearer ${token}`)
        .send({})
        .expect(201);

      expect(prismaService.campaignMember.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: "member-1" },
          data: { lastReadAt: expect.any(Date) },
        }),
      );
    });
  });

  describe("campaign archive endpoints", () => {
    const campaignWithOwnerAndPlayer = {
      id: "camp-1",
      name: "Curse of Strahd",
      description: "",
      system: "dnd5e",
      ownerId: "user-1",
      status: "active",
      createdAt: "2026-07-09T00:00:00.000Z",
      updatedAt: "2026-07-09T00:00:00.000Z",
      members: [
        { userId: "user-1", role: "owner" },
        { userId: "user-2", role: "player" },
      ],
    };

    it("lets campaign members list shared archive entries", async () => {
      const token = await loginAs(storedPlayerUser);
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwnerAndPlayer,
      );
      prismaService.campaignArchiveEntry.findMany.mockResolvedValueOnce([
        {
          id: "archive-1",
          campaignId: "camp-1",
          kind: "clue",
          title: "The silver key",
          summary: "Found below the chapel.",
          payload: {},
          pinned: false,
          updatedAt: "2026-07-16T00:00:00.000Z",
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0]).toMatchObject({
            id: "archive-1",
            kind: "clue",
            title: "The silver key",
          });
        });

      expect(prismaService.campaignArchiveEntry.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ campaignId: "camp-1", deletedAt: null }),
        }),
      );
    });

    it("lets a DM create a shared archive entry", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwnerAndPlayer,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${token}`)
        .send({
          kind: "clue",
          title: "  The silver key  ",
          summary: "Found below the chapel.",
          payload: { location: "chapel" },
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body.title).toBe("The silver key");
          expect(body.kind).toBe("clue");
        });

      expect(prismaService.campaignArchiveEntry.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            campaignId: "camp-1",
            title: "The silver key",
            createdBy: "user-1",
          }),
        }),
      );
    });

    it("rejects player archive creation and unknown archive kinds", async () => {
      const playerToken = await loginAs(storedPlayerUser);
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwnerAndPlayer,
      );
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${playerToken}`)
        .send({ kind: "clue", title: "A private note" })
        .expect(403);

      const dmToken = await loginAsDm();
      prismaService.campaign.findUnique.mockResolvedValueOnce(
        campaignWithOwnerAndPlayer,
      );
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/archives")
        .set("Authorization", `Bearer ${dmToken}`)
        .send({ kind: "map", title: "Not a supported category" })
        .expect(400);
    });

    it("lets a DM edit and archive a shared entry without deleting its history", async () => {
      const token = await loginAsDm();
      prismaService.campaign.findUnique
        .mockResolvedValueOnce(campaignWithOwnerAndPlayer)
        .mockResolvedValueOnce(campaignWithOwnerAndPlayer);
      prismaService.campaignArchiveEntry.findFirst
        .mockResolvedValueOnce({
          id: "archive-1",
          campaignId: "camp-1",
          kind: "clue",
          title: "The silver key",
          deletedAt: null,
        })
        .mockResolvedValueOnce({
          id: "archive-1",
          campaignId: "camp-1",
          kind: "clue",
          title: "The silver key (identified)",
          deletedAt: null,
        });
      prismaService.campaignArchiveEntry.update
        .mockResolvedValueOnce({
          id: "archive-1",
          campaignId: "camp-1",
          kind: "clue",
          title: "The silver key (identified)",
          summary: "It opens the crypt.",
          payload: {},
          pinned: true,
          updatedAt: "2026-07-16T01:00:00.000Z",
        })
        .mockResolvedValueOnce({ id: "archive-1", deletedAt: new Date() });

      await request(app.getHttpServer())
        .put("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .send({
          title: "The silver key (identified)",
          summary: "It opens the crypt.",
          pinned: true,
        })
        .expect(200)
        .expect(({ body }) => expect(body.pinned).toBe(true));

      await request(app.getHttpServer())
        .delete("/api/campaigns/camp-1/archives/archive-1")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(prismaService.campaignArchiveEntry.update).toHaveBeenLastCalledWith(
        expect.objectContaining({
          where: { id: "archive-1" },
          data: expect.objectContaining({ deletedAt: expect.any(Date) }),
        }),
      );
    });
  });

  describe("POST /api/campaigns/join", () => {
    const validInvite = {
      id: "invite-1",
      campaignId: "camp-1",
      code: "ABC123",
      roleOnJoin: "player",
      expiresAt: null,
      maxUses: 1,
      usedCount: 0,
      requireApproval: false,
      createdBy: "user-1",
      createdAt: "2026-07-09T00:00:00.000Z",
    };

    it("joins a campaign with a valid invite code", async () => {
      const token = await loginAsDm();
      prismaService.campaignInvite.findUnique.mockResolvedValueOnce(
        validInvite,
      );
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);
      prismaService.campaignMember.create.mockResolvedValueOnce({
        id: "member-1",
        campaignId: "camp-1",
        userId: "user-1",
        role: "player",
        displayName: "ranger",
        joinedAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .set("Authorization", `Bearer ${token}`)
        .send({ code: "ABC123" })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("member-1");
          expect(body.campaignId).toBe("camp-1");
          expect(body.userId).toBe("user-1");
          expect(body.role).toBe("player");
          expect(body.displayName).toBe("ranger");
        });

      const createArgs = prismaService.campaignMember.create.mock.calls[0][0];
      expect(createArgs.data.campaignId).toBe("camp-1");
      expect(createArgs.data.role).toBe("player");
      const updateArgs = prismaService.campaignInvite.update.mock.calls[0][0];
      expect(updateArgs.data.usedCount).toEqual({ increment: 1 });
    });

    it("forces legacy dm invites to join as player", async () => {
      const token = await loginAsDm();
      prismaService.campaignInvite.findUnique.mockResolvedValueOnce({
        ...validInvite,
        roleOnJoin: "dm",
      });
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);
      prismaService.campaignMember.create.mockResolvedValueOnce({
        id: "member-1",
        campaignId: "camp-1",
        userId: "user-1",
        role: "player",
        displayName: "ranger",
        joinedAt: "2026-07-09T00:00:00.000Z",
      });

      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .set("Authorization", `Bearer ${token}`)
        .send({ code: "ABC123" })
        .expect(201);

      expect(
        prismaService.campaignMember.create.mock.calls[0][0].data.role,
      ).toBe("player");
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .send({ code: "ABC123" })
        .expect(401);
    });

    it("rejects with missing code with 400", async () => {
      const token = await loginAsDm();

      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .set("Authorization", `Bearer ${token}`)
        .send({})
        .expect(400);
    });

    it("rejects with 404 when invite does not exist", async () => {
      const token = await loginAsDm();
      prismaService.campaignInvite.findUnique.mockResolvedValueOnce(null);
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .set("Authorization", `Bearer ${token}`)
        .send({ code: "NOPE" })
        .expect(404);
    });

    it("rejects with 403 when invite has expired", async () => {
      const token = await loginAsDm();
      prismaService.campaignInvite.findUnique.mockResolvedValueOnce({
        ...validInvite,
        expiresAt: new Date("2020-01-01T00:00:00.000Z"),
      });
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .set("Authorization", `Bearer ${token}`)
        .send({ code: "ABC123" })
        .expect(403);
    });

    it("rejects with 403 when invite has reached its usage limit", async () => {
      const token = await loginAsDm();
      prismaService.campaignInvite.findUnique.mockResolvedValueOnce({
        ...validInvite,
        maxUses: 1,
        usedCount: 1,
      });
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .set("Authorization", `Bearer ${token}`)
        .send({ code: "ABC123" })
        .expect(403);
    });

    it("returns the existing membership if already a member", async () => {
      const token = await loginAsDm();
      prismaService.campaignInvite.findUnique.mockResolvedValueOnce(
        validInvite,
      );
      prismaService.campaignMember.findFirst
        .mockResolvedValueOnce({
          userId: "user-1",
          role: "player",
        })
        .mockResolvedValueOnce({
          id: "member-1",
          campaignId: "camp-1",
          userId: "user-1",
          role: "player",
          displayName: "ranger",
          boundActorId: null,
          activeSpeakerActorId: null,
          speakerMode: "boundActor",
          lastReadAt: null,
          joinedAt: "2026-07-09T00:00:00.000Z",
        });

      await request(app.getHttpServer())
        .post("/api/campaigns/join")
        .set("Authorization", `Bearer ${token}`)
        .send({ code: "ABC123" })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("member-1");
          expect(body.role).toBe("player");
          expect(body.boundActorId).toBeNull();
          expect(body.activeSpeakerActorId).toBeNull();
          expect(body.speakerMode).toBe("boundActor");
          expect(body.lastReadAt).toBeNull();
        });

      expect(prismaService.campaignMember.create).not.toHaveBeenCalled();
    });
  });
});
