import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

// Task 3.1 — CampaignEvent 事件层 e2e 验证.
// 关注点: HP 变化与给予物品必须在同一事务中完成状态修改 + 事件追加,
// 失败时全部回滚; 非授权用户被拒绝; 不存在的 character 返回 404;
// revision 冲突返回 409; 事务提交后广播 campaign:message:new.
describe("campaign events endpoints (Task 3.1)", () => {
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
    campaignChatMessage: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn() },
    gameEvent: { create: jest.fn(), findUnique: jest.fn() },
    journalEntry: { create: jest.fn(), findMany: jest.fn() },
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
    prismaService.campaignChatMessage.findFirst.mockResolvedValue(null);
    prismaService.gameEvent.findUnique.mockResolvedValue(null);
    prismaService.gameEvent.create.mockResolvedValue({});
    prismaService.journalEntry.create.mockResolvedValue({});
    prismaService.journalEntry.findMany.mockResolvedValue([]);

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
    prismaService.campaignChange.create.mockImplementation(
      async (args: any) => ({
        id: "change-id",
        campaignId: args.data.campaignId,
        cursor: args.data.cursor,
        entityType: args.data.entityType,
        entityId: args.data.entityId,
        operation: args.data.operation,
        revision: args.data.revision,
        createdAt: new Date(),
      }),
    );
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

  const arannisCharacter = {
    id: "character-1",
    campaignId: "camp-1",
    ownerUserId: "player-1",
    sourceCharacterId: "char-1",
    characterType: "player",
    status: "active",
    lifecycle: "persistent",
    sheetJson: { name: "Arannis", currentHp: 20, maxHp: 30 },
    revision: 1,
    updatedBy: "player-1",
    createdAt: new Date("2026-07-14T00:00:00.000Z"),
    updatedAt: new Date("2026-07-14T00:00:00.000Z"),
  };

  describe("POST /api/campaigns/:campaignId/characters/:characterId/hp", () => {
    it("atomically updates character HP and appends an character.hp_changed event", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      const updatedRow = {
        ...arannisCharacter,
        sheetJson: { name: "Arannis", currentHp: 12, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
        updatedAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignCharacter.update.mockResolvedValueOnce(updatedRow);
      const eventMessageRow = {
        id: "msg-1",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: null,
        displayName: "旁白",
        avatarUrl: null,
        speakerMode: "narrator",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: "injured",
        publicHealthFraction: 0.4,
        ooc: false,
        kind: "system",
        content: "Arannis -8 HP (20 → 12)",
        eventData: {
          eventType: "character.hp_changed",
          characterId: "character-1",
          characterName: "Arannis",
          delta: -8,
          from: 20,
          to: 12,
          reason: null,
        },
        createdAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignChatMessage.create.mockResolvedValueOnce(
        eventMessageRow,
      );

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-001",
        delta: -8
      })
        .expect(201);

      // 响应包含新的 character 状态和事件消息.
      expect(res.body.character.id).toBe("character-1");
      expect(res.body.character.sheet.currentHp).toBe(12);
      expect(res.body.character.revision).toBe(2);
      expect(res.body.event.kind).toBe("system");
      expect(res.body.event.speakerMode).toBe("narrator");
      expect(res.body.event.eventData.eventType).toBe("character.hp_changed");
      expect(res.body.event.eventData.delta).toBe(-8);
      expect(res.body.event.eventData.from).toBe(20);
      expect(res.body.event.eventData.to).toBe(12);
      expect(res.body.event.eventData.characterId).toBe("character-1");

      // 原子性: character update, audit, change, chat message 全部在同一事务内.
      expect(prismaService.campaignCharacter.update).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignCharacterAudit.create).toHaveBeenCalledTimes(
        1,
      );
      expect(prismaService.campaignChange.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          campaignCharacterId: null,
          displayName: "旁白",
          speakerMode: "narrator",
          kind: "system",
        }),
      });

      // 事务提交后广播 chat message.
      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledWith(
        "camp-1",
        "campaign:message:new",
        expect.objectContaining({ kind: "system" }),
      );
      expect(campaignsGateway.broadcastChange).toHaveBeenCalledWith(
        expect.objectContaining({
          campaignId: "camp-1",
          entityType: "character",
        }),
      );
    });

    it("clamps HP at zero on damage beyond current", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...arannisCharacter,
        sheetJson: { name: "Arannis", currentHp: 0, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-2",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: null,
        displayName: "旁白",
        avatarUrl: null,
        speakerMode: "narrator",
        ooc: false,
        kind: "system",
        content: "Arannis -99 HP (20 → 0)",
        eventData: {
          eventType: "character.hp_changed",
          delta: -99,
          from: 20,
          to: 0,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-002",
        delta: -99
      })
        .expect(201);

      expect(res.body.character.sheet.currentHp).toBe(0);
      expect(res.body.event.eventData.to).toBe(0);
      expect(res.body.event.eventData.delta).toBe(-99);
      expect(res.body.event.eventData.from).toBe(20);
    });

    it("allows healing (positive delta) up to maxHp", async () => {
      const token = await loginAs(storedDm);
      const injured = {
        ...arannisCharacter,
        sheetJson: { name: "Arannis", currentHp: 10, maxHp: 30 },
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(injured);
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...injured,
        sheetJson: { name: "Arannis", currentHp: 25, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-3",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: "character-1",
        displayName: "dm",
        kind: "system",
        content: "Arannis +15 HP (10 → 25)",
        eventData: {
          eventType: "character.hp_changed",
          delta: 15,
          from: 10,
          to: 25,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-003",
        delta: 15
      })
        .expect(201);

      expect(res.body.character.sheet.currentHp).toBe(25);
      expect(res.body.event.eventData.delta).toBe(15);
    });

    it("clamps healing at maxHp", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...arannisCharacter,
        sheetJson: { name: "Arannis", currentHp: 30, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-4",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: "character-1",
        displayName: "dm",
        kind: "system",
        content: "Arannis +50 HP (20 → 30)",
        eventData: {
          eventType: "character.hp_changed",
          delta: 10,
          from: 20,
          to: 30,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-004",
        delta: 50
      })
        .expect(201);

      expect(res.body.character.sheet.currentHp).toBe(30);
      expect(res.body.event.eventData.to).toBe(30);
      // 报告的实际增量为 clamped 后的值 (20→30, +10).
      expect(res.body.event.eventData.delta).toBe(10);
    });

    it("rejects a non-member stranger with 403", async () => {
      const token = await loginAs(storedStranger);
      // Character 必须存在, 否则 loadCharacter 在到达权限检查前就抛 404.
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-005",
        delta: -5
      })
        .expect(403);

      // 失败时不应修改 character 或写入消息.
      expect(prismaService.campaignCharacter.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("returns 404 when the character does not exist", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/missing/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-006",
        delta: -5
      })
        .expect(404);

      expect(prismaService.campaignCharacter.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("returns 400 when delta is not a finite number", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-007",
        delta: "oops"
      })
        .expect(400);

      expect(prismaService.campaignCharacter.update).not.toHaveBeenCalled();
    });

    it("returns 400 when delta is zero", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-008",
        delta: 0
      })
        .expect(400);
    });

    it("returns 409 when baseRevision mismatches the character revision", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-009",
        delta: -5, baseRevision: 99
      })
        .expect(409);

      expect(prismaService.campaignCharacter.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });
  });

  describe("POST /api/campaigns/:campaignId/characters/:characterId/items", () => {
    it("atomically grants an item and appends an character.item_granted event", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      const updatedRow = {
        ...arannisCharacter,
        sheetJson: {
          name: "Arannis",
          currentHp: 20,
          maxHp: 30,
          inventory: [{ itemId: "item-longsword", name: "长剑", quantity: 1 }],
        },
        revision: 2,
        updatedBy: "dm-1",
      };
      prismaService.campaignCharacter.update.mockResolvedValueOnce(updatedRow);
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-item-1",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: null,
        displayName: "旁白",
        avatarUrl: null,
        speakerMode: "narrator",
        ooc: false,
        kind: "system",
        content: "给 Arannis 长剑 ×1",
        eventData: {
          eventType: "character.item_granted",
          characterId: "character-1",
          characterName: "Arannis",
          itemId: "item-longsword",
          itemName: "长剑",
          quantity: 1,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-010",
        itemId: "item-longsword", name: "长剑", quantity: 1
      })
        .expect(201);

      expect(res.body.character.revision).toBe(2);
      expect(res.body.character.sheet.inventory).toEqual([
        { itemId: "item-longsword", name: "长剑", quantity: 1 },
      ]);
      expect(res.body.event.kind).toBe("system");
      expect(res.body.event.speakerMode).toBe("narrator");
      expect(res.body.event.eventData.eventType).toBe("character.item_granted");
      expect(res.body.event.eventData.itemId).toBe("item-longsword");
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          campaignCharacterId: null,
          displayName: "旁白",
          speakerMode: "narrator",
          kind: "system",
        }),
      });
      expect(res.body.event.eventData.quantity).toBe(1);

      expect(prismaService.campaignCharacter.update).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignCharacter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            sheetJson: expect.objectContaining({
              inventory: [
                expect.objectContaining({
                  id: "item-longsword",
                  templateRef: "item-longsword",
                  name: "长剑",
                  quantity: 1,
                  equipped: false,
                  attuned: false,
                  instanceData: {},
                }),
              ],
            }),
          }),
        }),
      );
      expect(prismaService.campaignCharacterAudit.create).toHaveBeenCalledTimes(
        1,
      );
      expect(prismaService.campaignChange.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          campaignCharacterId: null,
          displayName: "旁白",
          speakerMode: "narrator",
          kind: "system",
        }),
      });

      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledWith(
        "camp-1",
        "campaign:message:new",
        expect.objectContaining({ kind: "system" }),
      );
    });

    it("stacks quantity when granting an existing item", async () => {
      const token = await loginAs(storedDm);
      const characterWithItem = {
        ...arannisCharacter,
        sheetJson: {
          name: "Arannis",
          currentHp: 20,
          maxHp: 30,
          inventory: [{ itemId: "item-arrow", name: "箭矢", quantity: 10 }],
        },
      };
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        characterWithItem,
      );
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...characterWithItem,
        sheetJson: {
          name: "Arannis",
          currentHp: 20,
          maxHp: 30,
          inventory: [{ itemId: "item-arrow", name: "箭矢", quantity: 15 }],
        },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-item-2",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: "character-1",
        displayName: "dm",
        kind: "system",
        content: "给 Arannis 箭矢 ×5",
        eventData: {
          eventType: "character.item_granted",
          itemId: "item-arrow",
          quantity: 5,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-011",
        itemId: "item-arrow", name: "箭矢", quantity: 5
      })
        .expect(201);

      expect(res.body.character.sheet.inventory[0].quantity).toBe(15);
    });

    it("defaults quantity to 1 when omitted", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      prismaService.campaignCharacter.update.mockResolvedValueOnce({
        ...arannisCharacter,
        sheetJson: {
          name: "Arannis",
          currentHp: 20,
          maxHp: 30,
          inventory: [{ itemId: "item-torch", name: "火把", quantity: 1 }],
        },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-item-3",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: "character-1",
        displayName: "dm",
        kind: "system",
        content: "给 Arannis 火把 ×1",
        eventData: {
          eventType: "character.item_granted",
          itemId: "item-torch",
          quantity: 1,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-012",
        itemId: "item-torch", name: "火把"
      })
        .expect(201);

      expect(res.body.character.sheet.inventory[0].quantity).toBe(1);
    });

    it("rejects a non-member stranger with 403", async () => {
      const token = await loginAs(storedStranger);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-013",
        itemId: "item-x", name: "X"
      })
        .expect(403);

      expect(prismaService.campaignCharacter.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("returns 400 when itemId is missing", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-014",
        name: "无 ID 物品"
      })
        .expect(400);
    });

    it("returns 400 when quantity is not a positive integer", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-015",
        itemId: "item-x", name: "X", quantity: 0
      })
        .expect(400);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-016",
        itemId: "item-y", name: "Y", quantity: -2
      })
        .expect(400);
    });
  });

  describe("POST /api/campaigns/:campaignId/characters/:characterId/conditions", () => {
    it("atomically adds a structured condition and appends an event", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      prismaService.campaignCharacter.update.mockImplementationOnce(
        async (args: any) => ({
          ...arannisCharacter,
          sheetJson: args.data.sheetJson,
          revision: args.data.revision,
          updatedBy: args.data.updatedBy,
          updatedAt: new Date("2026-07-14T02:00:00.000Z"),
        }),
      );
      prismaService.campaignChatMessage.create.mockImplementationOnce(
        async (args: any) => ({
          id: "msg-condition-1",
          ...args.data,
          createdAt: new Date("2026-07-14T02:00:00.000Z"),
        }),
      );

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/conditions")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-017",
        type: "poisoned", name: "中毒", durationRounds: 3
      })
        .expect(201);

      expect(res.body.character.sheet.conditions).toEqual([
        expect.objectContaining({
          type: "poisoned",
          name: "中毒",
          removable: true,
          duration: { unit: "round", total: 3, remaining: 3 },
        }),
      ]);
      expect(res.body.character.sheet.conditions[0].id).toEqual(
        expect.any(String),
      );
      expect(res.body.event.eventData).toEqual(
        expect.objectContaining({
          eventType: "character.condition_added",
          characterId: "character-1",
          conditionType: "poisoned",
          conditionName: "中毒",
          durationRounds: 3,
        }),
      );
      expect(prismaService.campaignCharacterAudit.create).toHaveBeenCalledTimes(
        1,
      );
      expect(prismaService.campaignChange.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledTimes(1);
      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledWith(
        "camp-1",
        "campaign:message:new",
        expect.objectContaining({ kind: "system" }),
      );
    });

    it("rejects an empty condition type", async () => {
      const token = await loginAs(storedDm);
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/conditions")
        .set("Authorization", `Bearer ${token}`)
        .send({
        requestId: "req-018",
        type: "", name: "无效状态"
      })
        .expect(400);
    });
  });

  describe("幂等: 相同 requestId 重试不重复执行", () => {
    it("replays the first HP result without re-applying the delta", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      // 首次执行: 事务内 update 成功.
      prismaService.campaignCharacter.update.mockImplementationOnce(
        async (args: any) => ({
          ...arannisCharacter,
          sheetJson: args.data.sheetJson,
          revision: args.data.revision,
          updatedBy: args.data.updatedBy,
        }),
      );
      // 首次执行: 事件消息落库.
      prismaService.campaignChatMessage.create.mockImplementationOnce(
        async (args: any) => ({
          id: "msg-hp-1",
          campaignId: "camp-1",
          ...args.data,
          createdAt: new Date("2026-07-14T01:00:00.000Z"),
        }),
      );

      const first = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ requestId: "req-idem-hp", delta: -8 })
        .expect(201);
      expect(first.body.character.sheet.currentHp).toBe(12);
      expect(prismaService.campaignCharacter.update).toHaveBeenCalledTimes(1);
      expect(prismaService.gameEvent.create).toHaveBeenCalledTimes(1);

      // 重试: gameEvent.findUnique 命中首次记录, 重放结果且不再写状态.
      prismaService.gameEvent.findUnique.mockResolvedValueOnce({
        id: "evt-1",
        requestId: "req-idem-hp",
        characterId: "character-1",
        campaignId: "camp-1",
        type: "character.hp.adjusted",
      });
      prismaService.campaignChatMessage.findFirst.mockResolvedValueOnce({
        id: "msg-hp-1",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: null,
        displayName: "旁白",
        speakerMode: "narrator",
        ooc: false,
        kind: "system",
        content: "Arannis -8 HP (20 → 12)",
        eventData: {
          eventType: "character.hp_changed",
          characterId: "character-1",
          characterName: "Arannis",
          delta: -8,
          from: 20,
          to: 12,
          reason: null,
          requestId: "req-idem-hp",
        },
        createdAt: new Date("2026-07-14T01:00:00.000Z"),
      });
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      const replay = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ requestId: "req-idem-hp", delta: -8 })
        .expect(201);

      expect(replay.body.event.eventData.delta).toBe(-8);
      // 重试没有再次更新角色、没有重复落消息、没有重复写 GameEvent.
      expect(prismaService.campaignCharacter.update).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledTimes(1);
      expect(prismaService.gameEvent.create).toHaveBeenCalledTimes(1);
      // 重放不重复广播 change 或消息 (cursor 为 null): 首次执行已广播.
      expect(campaignsGateway.broadcastChange).toHaveBeenCalledTimes(1);
      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledTimes(1);
    });

    it("rejects reusing a requestId for a different operation type", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      // 同一 requestId 已用于物品操作 (GameEvent 类型不同), 不得重放为 HP 结果.
      prismaService.gameEvent.findUnique.mockResolvedValueOnce({
        id: "evt-item",
        requestId: "req-type-mismatch",
        characterId: "character-1",
        campaignId: "camp-1",
        type: "character.item.granted",
      });
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ requestId: "req-type-mismatch", delta: -8 })
        .expect(400);
      // 类型不匹配时不执行任何状态写入.
      expect(prismaService.campaignCharacter.update).not.toHaveBeenCalled();
    });

    it("replays the first result when a concurrent duplicate hits the requestId unique constraint", async () => {
      const token = await loginAs(storedDm);
      // 请求 1: 首次执行成功.
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      prismaService.campaignCharacter.update.mockImplementationOnce(
        async (args: any) => ({
          ...arannisCharacter,
          sheetJson: args.data.sheetJson,
          revision: args.data.revision,
          updatedBy: args.data.updatedBy,
        }),
      );
      prismaService.campaignChatMessage.create.mockImplementationOnce(
        async (args: any) => ({
          id: "msg-race",
          campaignId: "camp-1",
          ...args.data,
          createdAt: new Date("2026-07-14T01:00:00.000Z"),
        }),
      );

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ requestId: "req-race", delta: -8 })
        .expect(201);

      // 请求 2 (并发重试): 事务内查重放未命中 → 写入 GameEvent 撞唯一约束
      // (P2002) → 事务回滚 → 事务外重查并重放首次结果, 客户端拿到 201 而非 500.
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      prismaService.gameEvent.findUnique.mockResolvedValueOnce(null);
      prismaService.campaignCharacter.update.mockResolvedValueOnce(
        arannisCharacter,
      );
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({});
      prismaService.gameEvent.create.mockRejectedValueOnce(
        new Prisma.PrismaClientKnownRequestError(
          "Unique constraint failed on the fields: (`requestId`)",
          { code: "P2002", clientVersion: "6.19.3" },
        ),
      );
      prismaService.gameEvent.findUnique.mockResolvedValueOnce({
        id: "evt-race",
        requestId: "req-race",
        characterId: "character-1",
        campaignId: "camp-1",
        type: "character.hp.adjusted",
      });
      prismaService.campaignChatMessage.findFirst.mockResolvedValueOnce({
        id: "msg-race",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignCharacterId: null,
        displayName: "旁白",
        speakerMode: "narrator",
        ooc: false,
        kind: "system",
        content: "Arannis -8 HP (20 → 12)",
        eventData: {
          eventType: "character.hp_changed",
          characterId: "character-1",
          characterName: "Arannis",
          delta: -8,
          from: 20,
          to: 12,
          reason: null,
          requestId: "req-race",
        },
        createdAt: new Date("2026-07-14T01:00:00.000Z"),
      });
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );

      const replay = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ requestId: "req-race", delta: -8 })
        .expect(201);

      expect(replay.body.event.eventData.delta).toBe(-8);
      // 唯一约束写入只有一次成功 + 一次失败尝试; 广播只在首次执行发生.
      expect(prismaService.gameEvent.create).toHaveBeenCalledTimes(2);
      expect(campaignsGateway.broadcastChange).toHaveBeenCalledTimes(1);
      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledTimes(1);
    });

    it("rejects an over-long requestId with 400", async () => {
      const token = await loginAs(storedDm);
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ requestId: "x".repeat(200), delta: -8 })
        .expect(400);
      expect(prismaService.campaignCharacter.update).not.toHaveBeenCalled();
    });

    it("rejects a missing requestId with 400", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignCharacter.findUnique.mockResolvedValueOnce(
        arannisCharacter,
      );
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/characters/character-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: -8 })
        .expect(400);
    });
  });
});
