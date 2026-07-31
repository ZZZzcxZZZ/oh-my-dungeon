import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

// Plan 2026-07-23 task 5.3: campaign conversations (main / direct / group).
// Covers listing, direct creation, group creation (DM-only), archive/rename,
// and participant-scoped message visibility. Follows the campaign-archives
// e2e-spec pattern: mock PrismaService, log in via /api/auth/login, then
// drive the REST endpoints with supertest.
describe("campaign conversation endpoints", () => {
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

  const campaignMembers = [
    { userId: "dm-1", role: "owner", displayName: "DM" },
    { userId: "player-1", role: "player", displayName: "Arannis" },
    { userId: "player-2", role: "player", displayName: "Bree" },
  ];

  const mainConversation = {
    id: "conv-main",
    campaignId: "camp-1",
    kind: "main",
    title: "",
    mainKey: "main",
    directKey: null,
    participantIds: [],
    createdBy: "dm-1",
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
    archivedAt: null,
  };

  const prismaService = {
    user: {
      count: jest.fn(),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
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
    campaignConversation: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      upsert: jest.fn(),
      update: jest.fn(),
    },
    campaignConversationRead: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
    },
    journalEntry: { create: jest.fn(), findMany: jest.fn() },
    campaignCharacter: { findUnique: jest.fn(), findMany: jest.fn(), create: jest.fn() },
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
    broadcastToUsers: jest.fn(),
  };

  const storedDm = {
    id: "dm-1",
    username: "dm",
    email: "dm@example.com",
    passwordHash: "hashed-secret",
  };
  const storedPlayer1 = {
    id: "player-1",
    username: "arannis",
    email: "arannis@example.com",
    passwordHash: "hashed-secret",
  };
  const storedPlayer2 = {
    id: "player-2",
    username: "bree",
    email: "bree@example.com",
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
    jest.resetAllMocks();
    prismaService.$queryRaw.mockResolvedValue([{ health_check: 1 }]);
    prismaService.serverSetting.findFirst.mockResolvedValue({
      registrationEnabled: true,
    });
    prismaService.user.count.mockResolvedValue(1);
    prismaService.user.findFirst.mockResolvedValue(null);
    prismaService.user.findUnique.mockResolvedValue(null);
    prismaService.user.findMany.mockResolvedValue([]);
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
        return { ...campaignRow, members: campaignMembers };
      }
      return null;
    });

    prismaService.campaignMember.findFirst.mockResolvedValue(null);
    prismaService.campaignMember.findMany.mockResolvedValue([]);
    prismaService.campaignMember.update.mockResolvedValue({});

    prismaService.campaignConversation.upsert.mockResolvedValue(mainConversation);
    prismaService.campaignConversation.findMany.mockResolvedValue([]);
    prismaService.campaignConversation.findFirst.mockResolvedValue(null);
    prismaService.campaignConversation.create.mockResolvedValue(mainConversation);
    prismaService.campaignConversation.update.mockResolvedValue(mainConversation);
    prismaService.campaignConversationRead.findUnique.mockResolvedValue(null);
    prismaService.campaignConversationRead.upsert.mockResolvedValue({});

    prismaService.campaignChatMessage.create.mockResolvedValue({});
    prismaService.campaignChatMessage.findMany.mockResolvedValue([]);
    prismaService.campaignChatMessage.findFirst.mockResolvedValue(null);
    prismaService.campaignChatMessage.count.mockResolvedValue(0);
    prismaService.campaignChatMessage.update.mockResolvedValue({});

    prismaService.campaignCharacter.findUnique.mockResolvedValue(null);
    prismaService.campaignCharacter.findMany.mockResolvedValue([]);
    prismaService.journalEntry.create.mockResolvedValue({});
    prismaService.journalEntry.findMany.mockResolvedValue([]);
    prismaService.campaignArchiveEntry.create.mockResolvedValue({});
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

  describe("GET /api/campaigns/:campaignId/conversations", () => {
    it("returns the main conversation for any member", async () => {
      const token = await loginAs(storedPlayer1);
      prismaService.campaignMember.findFirst.mockResolvedValueOnce({
        userId: "player-1",
        role: "player",
        lastReadAt: null,
      });
      prismaService.campaignConversation.findMany.mockResolvedValueOnce([
        mainConversation,
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/conversations")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("conv-main");
          expect(body[0].kind).toBe("main");
          expect(body[0].participantIds).toEqual([]);
          expect(body[0].lastMessage).toBeNull();
          expect(body[0].unreadCount).toBe(0);
        });
      expect(prismaService.campaignConversation.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { campaignId: "camp-1", archivedAt: null },
        }),
      );
    });

    it("uses a conversation-specific read cursor for unread messages", async () => {
      const token = await loginAs(storedPlayer1);
      prismaService.campaignConversation.findMany.mockResolvedValueOnce([
        mainConversation,
      ]);
      prismaService.campaignConversationRead.findUnique.mockResolvedValueOnce({
        lastReadAt: new Date("2026-07-15T00:00:00.000Z"),
      });

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/conversations")
        .set("Authorization", `Bearer ${token}`)
        .expect(200);

      expect(prismaService.campaignConversationRead.findUnique)
        .toHaveBeenCalledWith({
          where: {
            conversationId_userId: {
              conversationId: "conv-main",
              userId: "player-1",
            },
          },
        });
      expect(prismaService.campaignChatMessage.count).toHaveBeenCalledWith({
        where: expect.objectContaining({
          createdAt: { gt: new Date("2026-07-15T00:00:00.000Z") },
        }),
      });
    });

    it("marks only the selected conversation as read", async () => {
      const token = await loginAs(storedPlayer1);
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        mainConversation,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/conversations/conv-main/read")
        .set("Authorization", `Bearer ${token}`)
        .expect(201);

      expect(prismaService.campaignConversationRead.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            conversationId_userId: {
              conversationId: "conv-main",
              userId: "player-1",
            },
          },
        }),
      );
    });

    it("rejects without authentication with 401", async () => {
      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/conversations")
        .expect(401);
    });
  });

  describe("POST /api/campaigns/:campaignId/conversations/direct", () => {
    it("creates a direct conversation between two members", async () => {
      const token = await loginAs(storedPlayer1);
      const directConversation = {
        id: "conv-direct",
        campaignId: "camp-1",
        kind: "direct",
        title: "",
        mainKey: null,
        directKey: "player-1:player-2",
        participantIds: ["player-1", "player-2"],
        createdBy: "player-1",
        createdAt: new Date("2026-07-15T00:00:00.000Z"),
        updatedAt: new Date("2026-07-15T00:00:00.000Z"),
        archivedAt: null,
      };
      // Other user (player-2) is a campaign member.
      prismaService.campaignMember.findFirst.mockResolvedValueOnce({
        userId: "player-2",
        role: "player",
        displayName: "Bree",
        boundCharacterId: null,
      }).mockResolvedValueOnce({
        userId: "player-2",
        role: "player",
        displayName: "Bree",
        boundCharacterId: null,
      });
      prismaService.campaignConversation.upsert.mockResolvedValueOnce(
        directConversation,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/conversations/direct")
        .set("Authorization", `Bearer ${token}`)
        .send({ otherUserId: "player-2" })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("conv-direct");
          expect(body.kind).toBe("direct");
          expect(body.title).toBe("Bree");
          expect(body.participantIds).toEqual(["player-1", "player-2"]);
        });

      const upsertArgs = prismaService.campaignConversation.upsert.mock.calls[0][0];
      // Sorted pair key dedupes the 1:1 channel regardless of initiator.
      expect(upsertArgs.where.campaignId_directKey.directKey).toBe(
        "player-1:player-2",
      );
      expect(upsertArgs.create.participantIds).toEqual(["player-1", "player-2"]);
    });

    it("rejects creating a direct conversation with a non-member", async () => {
      const token = await loginAs(storedPlayer1);
      // player-2 is not found as a member.
      prismaService.campaignMember.findFirst.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/conversations/direct")
        .set("Authorization", `Bearer ${token}`)
        .send({ otherUserId: "player-2" })
        .expect(404);
    });

    it("non-participant cannot see a direct conversation in the list", async () => {
      const token = await loginAs(storedPlayer2);
      // A direct channel between dm-1 and player-1 that player-2 must not see.
      const exclusiveDirect = {
        id: "conv-exclusive",
        campaignId: "camp-1",
        kind: "direct",
        title: "",
        mainKey: null,
        directKey: "dm-1:player-1",
        participantIds: ["dm-1", "player-1"],
        createdBy: "dm-1",
        createdAt: new Date("2026-07-15T00:00:00.000Z"),
        updatedAt: new Date("2026-07-15T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignMember.findFirst.mockResolvedValueOnce({
        userId: "player-2",
        role: "player",
        lastReadAt: null,
      });
      prismaService.campaignConversation.findMany.mockResolvedValueOnce([
        mainConversation,
        exclusiveDirect,
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/conversations")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          // player-2 sees only the main room, not the dm-1↔player-1 channel.
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("conv-main");
        });
    });
  });

  describe("POST /api/campaigns/:campaignId/conversations/group", () => {
    it("lets a DM create a group conversation", async () => {
      const token = await loginAs(storedDm);
      const groupConversation = {
        id: "conv-group",
        campaignId: "camp-1",
        kind: "group",
        title: "Party Planning",
        mainKey: null,
        directKey: null,
        participantIds: ["dm-1", "player-1", "player-2"],
        createdBy: "dm-1",
        createdAt: new Date("2026-07-16T00:00:00.000Z"),
        updatedAt: new Date("2026-07-16T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignMember.findMany.mockResolvedValueOnce([
        { userId: "dm-1" },
        { userId: "player-1" },
        { userId: "player-2" },
      ]);
      prismaService.campaignConversation.create.mockResolvedValueOnce(
        groupConversation,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/conversations/group")
        .set("Authorization", `Bearer ${token}`)
        .send({ title: "Party Planning", participantIds: ["player-1", "player-2"] })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("conv-group");
          expect(body.kind).toBe("group");
          expect(body.title).toBe("Party Planning");
          // The creator is always included as a participant.
          expect(body.participantIds).toEqual(["dm-1", "player-1", "player-2"]);
        });

      const createArgs = prismaService.campaignConversation.create.mock.calls[0][0];
      expect(createArgs.data.kind).toBe("group");
      expect(createArgs.data.createdBy).toBe("dm-1");
    });

    it("lets a player create a group with two other campaign members", async () => {
      const token = await loginAs(storedPlayer1);
      const groupConversation = {
        id: "conv-player-group",
        campaignId: "camp-1",
        kind: "group",
        title: "Secret Club",
        mainKey: null,
        directKey: null,
        participantIds: ["player-1", "dm-1", "player-2"],
        createdBy: "player-1",
        createdAt: new Date("2026-07-16T00:00:00.000Z"),
        updatedAt: new Date("2026-07-16T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignMember.findMany.mockResolvedValueOnce([
        { userId: "player-1" },
        { userId: "dm-1" },
        { userId: "player-2" },
      ]);
      prismaService.campaignConversation.create.mockResolvedValueOnce(
        groupConversation,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/conversations/group")
        .set("Authorization", `Bearer ${token}`)
        .send({
          title: "Secret Club",
          participantIds: ["dm-1", "player-2"],
        })
        .expect(201)
        .expect(({ body }) => {
          expect(body.createdBy).toBe("player-1");
          expect(body.participantIds).toEqual([
            "player-1",
            "dm-1",
            "player-2",
          ]);
        });
    });

    it("rejects a group with fewer than two other members", async () => {
      const token = await loginAs(storedPlayer1);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/conversations/group")
        .set("Authorization", `Bearer ${token}`)
        .send({ title: "Too Small", participantIds: ["player-2"] })
        .expect(400);
    });

    it("rejects group creation with a missing title", async () => {
      const token = await loginAs(storedDm);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/conversations/group")
        .set("Authorization", `Bearer ${token}`)
        .send({ participantIds: ["player-1"] })
        .expect(400);
    });
  });

  describe("PATCH /api/campaigns/:campaignId/conversations/:conversationId", () => {
    it("lets a DM archive a conversation", async () => {
      const token = await loginAs(storedDm);
      const groupConversation = {
        id: "conv-group",
        campaignId: "camp-1",
        kind: "group",
        title: "Party Planning",
        mainKey: null,
        directKey: null,
        participantIds: ["dm-1", "player-1", "player-2"],
        createdBy: "dm-1",
        createdAt: new Date("2026-07-16T00:00:00.000Z"),
        updatedAt: new Date("2026-07-16T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        groupConversation,
      );
      prismaService.campaignConversation.update.mockResolvedValueOnce({
        ...groupConversation,
        archivedAt: new Date("2026-07-17T00:00:00.000Z"),
      });

      await request(app.getHttpServer())
        .patch("/api/campaigns/camp-1/conversations/conv-group")
        .set("Authorization", `Bearer ${token}`)
        .send({ archived: true })
        .expect(200)
        .expect(({ body }) => {
          expect(body.archivedAt).not.toBeNull();
        });

      const updateArgs = prismaService.campaignConversation.update.mock.calls[0][0];
      expect(updateArgs.data.archivedAt).toBeInstanceOf(Date);
    });

    it("rejects archive from a player with 403", async () => {
      const token = await loginAs(storedPlayer1);
      const groupConversation = {
        id: "conv-group",
        campaignId: "camp-1",
        kind: "group",
        title: "Party Planning",
        mainKey: null,
        directKey: null,
        participantIds: ["dm-1", "player-1", "player-2"],
        createdBy: "dm-1",
        createdAt: new Date("2026-07-16T00:00:00.000Z"),
        updatedAt: new Date("2026-07-16T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        groupConversation,
      );

      await request(app.getHttpServer())
        .patch("/api/campaigns/camp-1/conversations/conv-group")
        .set("Authorization", `Bearer ${token}`)
        .send({ archived: true })
        .expect(403);
    });

    it("lets the group creator rename their own conversation", async () => {
      const token = await loginAs(storedPlayer1);
      const groupConversation = {
        id: "conv-group",
        campaignId: "camp-1",
        kind: "group",
        title: "Old Title",
        mainKey: null,
        directKey: null,
        participantIds: ["player-1", "player-2"],
        createdBy: "player-1",
        createdAt: new Date("2026-07-16T00:00:00.000Z"),
        updatedAt: new Date("2026-07-16T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        groupConversation,
      );
      prismaService.campaignConversation.update.mockResolvedValueOnce({
        ...groupConversation,
        title: "New Title",
      });

      await request(app.getHttpServer())
        .patch("/api/campaigns/camp-1/conversations/conv-group")
        .set("Authorization", `Bearer ${token}`)
        .send({ title: "New Title" })
        .expect(200)
        .expect(({ body }) => {
          expect(body.title).toBe("New Title");
        });
    });
  });

  describe("participant-scoped message visibility", () => {
    it("lets a participant send a message to a direct conversation", async () => {
      const token = await loginAs(storedPlayer1);
      const directConversation = {
        id: "conv-direct",
        campaignId: "camp-1",
        kind: "direct",
        title: "",
        mainKey: null,
        directKey: "player-1:player-2",
        participantIds: ["player-1", "player-2"],
        createdBy: "player-1",
        createdAt: new Date("2026-07-15T00:00:00.000Z"),
        updatedAt: new Date("2026-07-15T00:00:00.000Z"),
        archivedAt: null,
      };
      // resolveMessageConversationId → loadAccessibleConversation
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        directConversation,
      );
      const createdMessage = {
        id: "msg-1",
        campaignId: "camp-1",
        conversationId: "conv-direct",
        senderId: "player-1",
        campaignCharacterId: null,
        displayName: "arannis",
        avatarUrl: null,
        speakerMode: "ooc",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: null,
        publicHealthFraction: null,
        ooc: true,
        kind: "ooc",
        content: "psst",
        actionSnapshot: null,
        eventData: null,
        createdAt: new Date("2026-07-15T01:00:00.000Z"),
      };
      prismaService.campaignChatMessage.create.mockResolvedValueOnce(
        createdMessage,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({ content: "psst", kind: "ooc", conversationId: "conv-direct" })
        .expect(201)
        .expect(({ body }) => {
          expect(body.id).toBe("msg-1");
          expect(body.content).toBe("psst");
        });

      const createArgs = prismaService.campaignChatMessage.create.mock.calls[0][0];
      expect(createArgs.data.conversationId).toBe("conv-direct");
      expect(campaignsGateway.broadcastToUsers).toHaveBeenCalledWith(
        ["player-1", "player-2"],
        "campaign:message:new",
        expect.objectContaining({ id: "msg-1" }),
      );
      expect(campaignsGateway.broadcastToCampaign).not.toHaveBeenCalled();
    });

    it("lets a participant list messages in a direct conversation", async () => {
      const token = await loginAs(storedPlayer1);
      const directConversation = {
        id: "conv-direct",
        campaignId: "camp-1",
        kind: "direct",
        title: "",
        mainKey: null,
        directKey: "player-1:player-2",
        participantIds: ["player-1", "player-2"],
        createdBy: "player-1",
        createdAt: new Date("2026-07-15T00:00:00.000Z"),
        updatedAt: new Date("2026-07-15T00:00:00.000Z"),
        archivedAt: null,
      };
      // resolveConversationFilter → loadAccessibleConversation
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        directConversation,
      );
      prismaService.campaignChatMessage.findMany.mockResolvedValueOnce([
        {
          id: "msg-1",
          campaignId: "camp-1",
          conversationId: "conv-direct",
          senderId: "player-1",
          campaignCharacterId: null,
          displayName: "arannis",
          avatarUrl: null,
          speakerMode: "ooc",
          delegatedByUserId: null,
          speakerAvatarAssetId: null,
          publicHealthState: null,
          publicHealthFraction: null,
          ooc: true,
          kind: "ooc",
          content: "psst",
          actionSnapshot: null,
          eventData: null,
          createdAt: "2026-07-15T01:00:00.000Z",
        },
      ]);

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/messages?conversationId=conv-direct")
        .set("Authorization", `Bearer ${token}`)
        .expect(200)
        .expect(({ body }) => {
          expect(body).toHaveLength(1);
          expect(body[0].id).toBe("msg-1");
          expect(body[0].content).toBe("psst");
        });
    });

    it("blocks a non-participant from listing direct conversation messages", async () => {
      const token = await loginAs(storedPlayer2);
      // player-2 is NOT a participant in the player-1↔dm-1 channel.
      const exclusiveDirect = {
        id: "conv-exclusive",
        campaignId: "camp-1",
        kind: "direct",
        title: "",
        mainKey: null,
        directKey: "dm-1:player-1",
        participantIds: ["dm-1", "player-1"],
        createdBy: "dm-1",
        createdAt: new Date("2026-07-15T00:00:00.000Z"),
        updatedAt: new Date("2026-07-15T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        exclusiveDirect,
      );

      await request(app.getHttpServer())
        .get("/api/campaigns/camp-1/messages?conversationId=conv-exclusive")
        .set("Authorization", `Bearer ${token}`)
        .expect(403);
    });

    it("blocks a non-participant from sending to a direct conversation", async () => {
      const token = await loginAs(storedPlayer2);
      const exclusiveDirect = {
        id: "conv-exclusive",
        campaignId: "camp-1",
        kind: "direct",
        title: "",
        mainKey: null,
        directKey: "dm-1:player-1",
        participantIds: ["dm-1", "player-1"],
        createdBy: "dm-1",
        createdAt: new Date("2026-07-15T00:00:00.000Z"),
        updatedAt: new Date("2026-07-15T00:00:00.000Z"),
        archivedAt: null,
      };
      prismaService.campaignConversation.findFirst.mockResolvedValueOnce(
        exclusiveDirect,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/messages")
        .set("Authorization", `Bearer ${token}`)
        .send({ content: "intrusion", kind: "ooc", conversationId: "conv-exclusive" })
        .expect(403);
    });
  });
});
