import { Test } from "@nestjs/testing";
import type { INestApplication } from "@nestjs/common";
import request = require("supertest");
import { AppModule } from "../src/app.module";
import { PrismaService } from "../src/prisma/prisma.service";
import { PasswordHashService } from "../src/modules/auth/password-hash.service";

describe("content endpoints", () => {
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
    contentPackage: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
    contentItem: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
    contentItemLink: { findMany: jest.fn(), createMany: jest.fn() },
    userContentFavorite: { upsert: jest.fn(), deleteMany: jest.fn(), findMany: jest.fn() },
    campaignContentPackage: {
      upsert: jest.fn(),
      findMany: jest.fn(),
    },
    contentOverride: {
      create: jest.fn(),
      findMany: jest.fn(),
    },
    journalEntry: {
      create: jest.fn(),
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
  const campaign = {
    id: "camp-1",
    ownerId: "user-1",
    members: [{ userId: "user-1", role: "owner" }],
  };
  const packageRow = {
    id: "pkg-1",
    scope: "user",
    ownerUserId: "user-1",
    campaignId: null,
    name: "Basic Spells",
    version: "1.0.0",
    schemaVersion: 1,
    locale: "zh-CN",
    status: "active",
    createdBy: "user-1",
    createdAt: "2026-07-09T00:00:00.000Z",
    updatedAt: "2026-07-09T00:00:00.000Z",
  };
  const itemRow = {
    id: "item-1",
    packageId: "pkg-1",
    type: "spell",
    slug: "fire-bolt",
    name: "Fire Bolt",
    description: "A mote of fire.",
    structured: { level: 0 },
    tags: ["cantrip"],
    sourceLabel: "SRD",
    schemaVersion: 1,
    createdAt: "2026-07-09T00:00:00.000Z",
    updatedAt: "2026-07-09T00:00:00.000Z",
  };
  const validImport = {
    name: "Basic Spells",
    version: "1.0.0",
    schemaVersion: 1,
    locale: "zh-CN",
    items: [
      {
        type: "spell",
        slug: "fire-bolt",
        name: "Fire Bolt",
        description: "A mote of fire.",
        structured: { level: 0 },
        tags: ["cantrip"],
        sourceLabel: "SRD",
      },
    ],
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
    prismaService.campaign.findUnique.mockResolvedValue(null);
    prismaService.campaignMember.findUnique.mockResolvedValue(null);
    prismaService.contentPackage.create.mockResolvedValue(packageRow);
    prismaService.contentPackage.findMany.mockResolvedValue([]);
    prismaService.contentPackage.findUnique.mockResolvedValue(null);
    prismaService.contentItem.findMany.mockResolvedValue([]);
    prismaService.contentItem.findUnique.mockResolvedValue(null);
    prismaService.contentItemLink.findMany.mockResolvedValue([]);
    prismaService.contentItemLink.createMany.mockResolvedValue({ count: 0 });
    prismaService.userContentFavorite.findMany.mockResolvedValue([]);
    prismaService.userContentFavorite.upsert.mockResolvedValue({});
    prismaService.userContentFavorite.deleteMany.mockResolvedValue({ count: 1 });
    prismaService.campaignContentPackage.upsert.mockResolvedValue({});
    prismaService.campaignContentPackage.findMany.mockResolvedValue([]);
    prismaService.contentOverride.create.mockResolvedValue({});
    prismaService.contentOverride.findMany.mockResolvedValue([]);
    prismaService.journalEntry.create.mockResolvedValue({});
  });

  async function login(user = storedUser): Promise<string> {
    prismaService.user.findFirst.mockResolvedValueOnce(user);
    const response = await request(app.getHttpServer())
      .post("/api/auth/login")
      .send({ identifier: "dm", password: "p@ssw0rd" })
      .expect(200);
    return response.body.accessToken;
  }

  it("validates a package without writing during dry-run import", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .post("/api/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({ dryRun: true, package: validImport })
      .expect(201)
      .expect(({ body }) => {
        expect(body.valid).toBe(true);
        expect(body.errors).toEqual([]);
        expect(body.package).toBeNull();
      });

    expect(prismaService.contentPackage.create).not.toHaveBeenCalled();
  });

  it("returns validation errors before importing an invalid package", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .post("/api/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({
        dryRun: true,
        package: { name: "", version: "", items: [] },
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.valid).toBe(false);
        expect(body.errors).toContain("Package name is required");
      });
  });

  it("imports a valid package and creates its items", async () => {
    const token = await login();
    prismaService.contentPackage.create.mockResolvedValueOnce({
      ...packageRow,
      items: [itemRow],
    });

    await request(app.getHttpServer())
      .post("/api/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({ package: validImport })
      .expect(201)
      .expect(({ body }) => {
        expect(body.valid).toBe(true);
        expect(body.package.id).toBe("pkg-1");
        expect(body.package.items).toHaveLength(1);
      });

    const createArgs = prismaService.contentPackage.create.mock.calls[0][0];
    expect(createArgs.data.ownerUserId).toBe("user-1");
    expect(createArgs.data.items.create).toHaveLength(1);
    expect(createArgs.data.items.create[0].slug).toBe("fire-bolt");
  });

  it("exports a user-owned content package", async () => {
    const token = await login();
    prismaService.contentPackage.findUnique.mockResolvedValueOnce({
      ...packageRow,
      items: [itemRow],
    });

    await request(app.getHttpServer())
      .get("/api/content/packages/pkg-1/export")
      .set("Authorization", `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toMatchObject({
          name: "Basic Spells",
          version: "1.0.0",
          schemaVersion: 1,
          locale: "zh-CN",
        });
        expect(body.items).toHaveLength(1);
        expect(body.items[0]).toMatchObject({
          type: "spell",
          slug: "fire-bolt",
          name: "Fire Bolt",
        });
      });
  });

  it("allows a campaign manager to enable a package for a campaign", async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.contentPackage.findUnique.mockResolvedValueOnce(packageRow);

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/packages")
      .set("Authorization", `Bearer ${token}`)
      .send({ packageId: "pkg-1", enabled: true })
      .expect(201)
      .expect(({ body }) => {
        expect(body.campaignId).toBe("camp-1");
        expect(body.packageId).toBe("pkg-1");
        expect(body.enabled).toBe(true);
      });

    expect(prismaService.campaignContentPackage.upsert).toHaveBeenCalled();
    expect(prismaService.journalEntry.create.mock.calls[0][0].data.type).toBe(
      "content_package_enabled",
    );
  });

  it("allows a campaign dm to import a package into that campaign", async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.contentPackage.create.mockResolvedValueOnce({
      ...packageRow,
      scope: "campaign",
      ownerUserId: null,
      campaignId: "camp-1",
      items: [itemRow],
    });

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({ package: validImport })
      .expect(201)
      .expect(({ body }) => {
        expect(body.valid).toBe(true);
        expect(body.package.scope).toBe("campaign");
        expect(body.package.campaignId).toBe("camp-1");
      });

    const createArgs = prismaService.contentPackage.create.mock.calls[0][0];
    expect(createArgs.data.campaignId).toBe("camp-1");
    expect(createArgs.data.scope).toBe("campaign");
  });

  it("rejects a campaign import with an unresolved wiki link", async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({
        package: {
          ...validImport,
          items: [{ ...validImport.items[0], references: [{ type: "feature", slug: "missing", relation: "grants" }] }],
        },
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.valid).toBe(false);
        expect(body.errors).toContain("items[0].references[0] cannot be resolved");
      });
  });

  it("rejects a player importing a package into a campaign", async () => {
    const token = await login({
      ...storedUser,
      id: "player-2",
      username: "player",
    });
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/packages/import")
      .set("Authorization", `Bearer ${token}`)
      .send({ package: validImport })
      .expect(403);
  });

  it("rejects campaign content for non-members", async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce({
      ...campaign,
      ownerId: "user-2",
      members: [{ userId: "user-2", role: "owner" }],
    });

    await request(app.getHttpServer())
      .get("/api/campaigns/camp-1/content/available")
      .set("Authorization", `Bearer ${token}`)
      .expect(403);
  });

  it("returns enabled campaign items and excludes disabled overrides", async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.campaignContentPackage.findMany.mockResolvedValueOnce([
      { packageId: "pkg-1", enabled: true },
    ]);
    prismaService.contentOverride.findMany.mockResolvedValueOnce([
      { baseContentItemId: "item-2", overrideType: "disable" },
    ]);
    prismaService.contentItem.findMany.mockResolvedValueOnce([
      itemRow,
      { ...itemRow, id: "item-2", slug: "hidden-spell", name: "Hidden Spell" },
    ]);

    await request(app.getHttpServer())
      .get("/api/campaigns/camp-1/content/available?type=spell")
      .set("Authorization", `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0].id).toBe("item-1");
      });
  });

  it("filters available campaign items to the current user's favorites", async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.campaignContentPackage.findMany.mockResolvedValueOnce([
      { packageId: "pkg-1", enabled: true },
    ]);
    prismaService.contentPackage.findMany.mockResolvedValueOnce([]);
    prismaService.contentOverride.findMany.mockResolvedValueOnce([]);
    prismaService.contentItem.findMany.mockResolvedValueOnce([
      itemRow,
      { ...itemRow, id: "item-2", slug: "shield", name: "Shield" },
    ]);
    prismaService.userContentFavorite.findMany.mockResolvedValueOnce([
      { contentItemId: "item-2" },
    ]);

    await request(app.getHttpServer())
      .get("/api/campaigns/camp-1/content/available?favoriteOnly=true")
      .set("Authorization", `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0].id).toBe("item-2");
      });
  });

  it("allows a campaign manager to disable one content item", async () => {
    const token = await login();
    prismaService.campaign.findUnique.mockResolvedValueOnce(campaign);
    prismaService.contentItem.findUnique.mockResolvedValueOnce(itemRow);

    await request(app.getHttpServer())
      .post("/api/campaigns/camp-1/content/overrides")
      .set("Authorization", `Bearer ${token}`)
      .send({
        baseContentItemId: "item-1",
        overrideType: "disable",
        reason: "Not for this campaign",
      })
      .expect(201)
      .expect(({ body }) => {
        expect(body.campaignId).toBe("camp-1");
        expect(body.baseContentItemId).toBe("item-1");
        expect(body.overrideType).toBe("disable");
      });

    const createArgs = prismaService.contentOverride.create.mock.calls[0][0];
    expect(createArgs.data.createdBy).toBe("user-1");
    expect(prismaService.journalEntry.create.mock.calls[0][0].data.type).toBe(
      "content_item_disabled",
    );
  });

  it("includes system packages visible to all users in listPackages", async () => {
    const token = await login();
    const systemPackage = {
      ...packageRow,
      id: "pkg-srd",
      scope: "system",
      ownerUserId: null,
      createdBy: "system",
      name: "SRD 5.1 基础资料",
    };
    prismaService.contentPackage.findMany.mockResolvedValueOnce([
      systemPackage,
    ]);

    await request(app.getHttpServer())
      .get("/api/content/packages")
      .set("Authorization", `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0].scope).toBe("system");
        expect(body[0].name).toBe("SRD 5.1 基础资料");
      });

    const findManyArgs =
      prismaService.contentPackage.findMany.mock.calls[0][0];
    expect(findManyArgs.where.OR).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ scope: "system" }),
      ]),
    );
  });

  it("includes system package items in listItems", async () => {
    const token = await login();
    const systemPackage = {
      id: "pkg-srd",
      scope: "system",
      ownerUserId: null,
      status: "active",
    };
    prismaService.contentPackage.findMany.mockResolvedValueOnce([
      systemPackage,
    ]);
    prismaService.contentItem.findMany.mockResolvedValueOnce([
      { ...itemRow, id: "item-srd", packageId: "pkg-srd", name: "Magic Missile" },
    ]);

    await request(app.getHttpServer())
      .get("/api/content/items?type=spell")
      .set("Authorization", `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toHaveLength(1);
        expect(body[0].name).toBe("Magic Missile");
      });

    const findManyArgs =
      prismaService.contentPackage.findMany.mock.calls[0][0];
    expect(findManyArgs.where.OR).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ scope: "system" }),
      ]),
    );
  });

  it("returns no implicit system or SRD packages with a fresh database", async () => {
    const token = await login();

    await request(app.getHttpServer())
      .get("/api/content/packages")
      .set("Authorization", `Bearer ${token}`)
      .expect(200)
      .expect(({ body }) => {
        expect(body).toEqual([]);
        const offenders = (Array.isArray(body) ? body : []).filter(
          (p: { scope?: string; name?: string }) =>
            p.scope === "system" || /SRD/i.test(p.name ?? ""),
        );
        expect(offenders).toEqual([]);
      });
  });
});
