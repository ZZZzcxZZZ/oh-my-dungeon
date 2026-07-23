import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";
import { CampaignsGateway } from "../src/modules/realtime/campaigns.gateway";

// Task 3.1 — CampaignEvent 事件层 e2e 验证.
// 关注点: HP 变化与给予物品必须在同一事务中完成状态修改 + 事件追加,
// 失败时全部回滚; 非授权用户被拒绝; 不存在的 actor 返回 404;
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
    journalEntry: { create: jest.fn(), findMany: jest.fn() },
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
    prismaService.journalEntry.create.mockResolvedValue({});
    prismaService.journalEntry.findMany.mockResolvedValue([]);

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

  const arannisActor = {
    id: "actor-1",
    campaignId: "camp-1",
    ownerUserId: "player-1",
    sourceCharacterId: "char-1",
    actorType: "player",
    status: "active",
    lifecycle: "persistent",
    sheetJson: { name: "Arannis", currentHp: 20, maxHp: 30 },
    revision: 1,
    updatedBy: "player-1",
    createdAt: new Date("2026-07-14T00:00:00.000Z"),
    updatedAt: new Date("2026-07-14T00:00:00.000Z"),
  };

  describe("POST /api/campaigns/:campaignId/actors/:actorId/hp", () => {
    it("atomically updates actor HP and appends an actor.hp_changed event", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);
      const updatedRow = {
        ...arannisActor,
        sheetJson: { name: "Arannis", currentHp: 12, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
        updatedAt: new Date("2026-07-14T01:00:00.000Z"),
      };
      prismaService.campaignActor.update.mockResolvedValueOnce(updatedRow);
      const eventMessageRow = {
        id: "msg-1",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignActorId: "actor-1",
        displayName: "dm",
        avatarUrl: null,
        speakerMode: "actor",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: "injured",
        publicHealthFraction: 0.4,
        ooc: false,
        kind: "system",
        content: "Arannis -8 HP (20 → 12)",
        eventData: {
          eventType: "actor.hp_changed",
          actorId: "actor-1",
          actorName: "Arannis",
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
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: -8 })
        .expect(201);

      // 响应包含新的 actor 状态和事件消息.
      expect(res.body.actor.id).toBe("actor-1");
      expect(res.body.actor.sheet.currentHp).toBe(12);
      expect(res.body.actor.revision).toBe(2);
      expect(res.body.event.kind).toBe("system");
      expect(res.body.event.eventData.eventType).toBe("actor.hp_changed");
      expect(res.body.event.eventData.delta).toBe(-8);
      expect(res.body.event.eventData.from).toBe(20);
      expect(res.body.event.eventData.to).toBe(12);
      expect(res.body.event.eventData.actorId).toBe("actor-1");

      // 原子性: actor update, audit, change, chat message 全部在同一事务内.
      expect(prismaService.campaignActor.update).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignActorAudit.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChange.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledTimes(1);

      // 事务提交后广播 chat message.
      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledWith(
        "camp-1",
        "campaign:message:new",
        expect.objectContaining({ kind: "system" }),
      );
      expect(campaignsGateway.broadcastChange).toHaveBeenCalledWith(
        expect.objectContaining({ campaignId: "camp-1", entityType: "actor" }),
      );
    });

    it("clamps HP at zero on damage beyond current", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...arannisActor,
        sheetJson: { name: "Arannis", currentHp: 0, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-2",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignActorId: "actor-1",
        displayName: "dm",
        kind: "system",
        content: "Arannis -99 HP (20 → 0)",
        eventData: {
          eventType: "actor.hp_changed",
          delta: -99,
          from: 20,
          to: 0,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: -99 })
        .expect(201);

      expect(res.body.actor.sheet.currentHp).toBe(0);
      expect(res.body.event.eventData.to).toBe(0);
      expect(res.body.event.eventData.delta).toBe(-99);
      expect(res.body.event.eventData.from).toBe(20);
    });

    it("allows healing (positive delta) up to maxHp", async () => {
      const token = await loginAs(storedDm);
      const injured = {
        ...arannisActor,
        sheetJson: { name: "Arannis", currentHp: 10, maxHp: 30 },
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(injured);
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...injured,
        sheetJson: { name: "Arannis", currentHp: 25, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-3",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignActorId: "actor-1",
        displayName: "dm",
        kind: "system",
        content: "Arannis +15 HP (10 → 25)",
        eventData: {
          eventType: "actor.hp_changed",
          delta: 15,
          from: 10,
          to: 25,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: 15 })
        .expect(201);

      expect(res.body.actor.sheet.currentHp).toBe(25);
      expect(res.body.event.eventData.delta).toBe(15);
    });

    it("clamps healing at maxHp", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...arannisActor,
        sheetJson: { name: "Arannis", currentHp: 30, maxHp: 30 },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-4",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignActorId: "actor-1",
        displayName: "dm",
        kind: "system",
        content: "Arannis +50 HP (20 → 30)",
        eventData: {
          eventType: "actor.hp_changed",
          delta: 10,
          from: 20,
          to: 30,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: 50 })
        .expect(201);

      expect(res.body.actor.sheet.currentHp).toBe(30);
      expect(res.body.event.eventData.to).toBe(30);
      // 报告的实际增量为 clamped 后的值 (20→30, +10).
      expect(res.body.event.eventData.delta).toBe(10);
    });

    it("rejects a non-member stranger with 403", async () => {
      const token = await loginAs(storedStranger);
      // Actor 必须存在, 否则 loadActor 在到达权限检查前就抛 404.
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: -5 })
        .expect(403);

      // 失败时不应修改 actor 或写入消息.
      expect(prismaService.campaignActor.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("returns 404 when the actor does not exist", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(null);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/missing/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: -5 })
        .expect(404);

      expect(prismaService.campaignActor.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("returns 400 when delta is not a finite number", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: "oops" })
        .expect(400);

      expect(prismaService.campaignActor.update).not.toHaveBeenCalled();
    });

    it("returns 400 when delta is zero", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: 0 })
        .expect(400);
    });

    it("returns 409 when baseRevision mismatches the actor revision", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/hp")
        .set("Authorization", `Bearer ${token}`)
        .send({ delta: -5, baseRevision: 99 })
        .expect(409);

      expect(prismaService.campaignActor.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });
  });

  describe("POST /api/campaigns/:campaignId/actors/:actorId/items", () => {
    it("atomically grants an item and appends an actor.item_granted event", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);
      const updatedRow = {
        ...arannisActor,
        sheetJson: {
          name: "Arannis",
          currentHp: 20,
          maxHp: 30,
          inventory: [
            { itemId: "item-longsword", name: "长剑", quantity: 1 },
          ],
        },
        revision: 2,
        updatedBy: "dm-1",
      };
      prismaService.campaignActor.update.mockResolvedValueOnce(updatedRow);
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-item-1",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignActorId: "actor-1",
        displayName: "dm",
        kind: "system",
        content: "给 Arannis 长剑 ×1",
        eventData: {
          eventType: "actor.item_granted",
          actorId: "actor-1",
          actorName: "Arannis",
          itemId: "item-longsword",
          itemName: "长剑",
          quantity: 1,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({ itemId: "item-longsword", name: "长剑", quantity: 1 })
        .expect(201);

      expect(res.body.actor.revision).toBe(2);
      expect(res.body.actor.sheet.inventory).toEqual([
        { itemId: "item-longsword", name: "长剑", quantity: 1 },
      ]);
      expect(res.body.event.kind).toBe("system");
      expect(res.body.event.eventData.eventType).toBe("actor.item_granted");
      expect(res.body.event.eventData.itemId).toBe("item-longsword");
      expect(res.body.event.eventData.quantity).toBe(1);

      expect(prismaService.campaignActor.update).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignActorAudit.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChange.create).toHaveBeenCalledTimes(1);
      expect(prismaService.campaignChatMessage.create).toHaveBeenCalledTimes(1);

      expect(campaignsGateway.broadcastToCampaign).toHaveBeenCalledWith(
        "camp-1",
        "campaign:message:new",
        expect.objectContaining({ kind: "system" }),
      );
    });

    it("stacks quantity when granting an existing item", async () => {
      const token = await loginAs(storedDm);
      const actorWithItem = {
        ...arannisActor,
        sheetJson: {
          name: "Arannis",
          currentHp: 20,
          maxHp: 30,
          inventory: [
            { itemId: "item-arrow", name: "箭矢", quantity: 10 },
          ],
        },
      };
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(actorWithItem);
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...actorWithItem,
        sheetJson: {
          name: "Arannis",
          currentHp: 20,
          maxHp: 30,
          inventory: [
            { itemId: "item-arrow", name: "箭矢", quantity: 15 },
          ],
        },
        revision: 2,
        updatedBy: "dm-1",
      });
      prismaService.campaignChatMessage.create.mockResolvedValueOnce({
        id: "msg-item-2",
        campaignId: "camp-1",
        senderId: "dm-1",
        campaignActorId: "actor-1",
        displayName: "dm",
        kind: "system",
        content: "给 Arannis 箭矢 ×5",
        eventData: {
          eventType: "actor.item_granted",
          itemId: "item-arrow",
          quantity: 5,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({ itemId: "item-arrow", name: "箭矢", quantity: 5 })
        .expect(201);

      expect(res.body.actor.sheet.inventory[0].quantity).toBe(15);
    });

    it("defaults quantity to 1 when omitted", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);
      prismaService.campaignActor.update.mockResolvedValueOnce({
        ...arannisActor,
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
        campaignActorId: "actor-1",
        displayName: "dm",
        kind: "system",
        content: "给 Arannis 火把 ×1",
        eventData: {
          eventType: "actor.item_granted",
          itemId: "item-torch",
          quantity: 1,
        },
        createdAt: new Date(),
      });

      const res = await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({ itemId: "item-torch", name: "火把" })
        .expect(201);

      expect(res.body.actor.sheet.inventory[0].quantity).toBe(1);
    });

    it("rejects a non-member stranger with 403", async () => {
      const token = await loginAs(storedStranger);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);
      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({ itemId: "item-x", name: "X" })
        .expect(403);

      expect(prismaService.campaignActor.update).not.toHaveBeenCalled();
      expect(prismaService.campaignChatMessage.create).not.toHaveBeenCalled();
    });

    it("returns 400 when itemId is missing", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({ name: "无 ID 物品" })
        .expect(400);
    });

    it("returns 400 when quantity is not a positive integer", async () => {
      const token = await loginAs(storedDm);
      prismaService.campaignActor.findUnique.mockResolvedValueOnce(arannisActor);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({ itemId: "item-x", name: "X", quantity: 0 })
        .expect(400);

      await request(app.getHttpServer())
        .post("/api/campaigns/camp-1/actors/actor-1/items")
        .set("Authorization", `Bearer ${token}`)
        .send({ itemId: "item-y", name: "Y", quantity: -2 })
        .expect(400);
    });
  });
});
