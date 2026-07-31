import { CampaignChangeService } from "./campaign-change.service";

describe("CampaignChangeService", () => {
  let service: CampaignChangeService;
  let prismaService: {
    $transaction: jest.Mock;
    campaignSyncState: {
      upsert: jest.Mock;
      findUnique: jest.Mock;
    };
    campaignChange: {
      create: jest.Mock;
      findMany: jest.Mock;
      count: jest.Mock;
    };
  };

  beforeEach(() => {
    jest.clearAllMocks();

    prismaService = {
      $transaction: jest.fn(),
      campaignSyncState: {
        upsert: jest.fn(),
        findUnique: jest.fn(),
      },
      campaignChange: {
        create: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
      },
    };

    service = new CampaignChangeService(prismaService as any);
  });

  describe("record", () => {
    it("allocates one campaign cursor per accepted mutation", async () => {
      let firstCursor = 1n;
      let secondCursor = 2n;

      prismaService.$transaction.mockImplementation(async (cb: any) => {
        const tx = {
          campaignSyncState: {
            upsert: jest.fn().mockImplementation(async () => {
              const cursor = firstCursor;
              firstCursor = secondCursor;
              secondCursor = secondCursor + 1n;
              return { campaignId: "campaign-1", cursor };
            }),
          },
          campaignChange: {
            create: jest.fn().mockImplementation(async (args: any) => ({
              id: "change-id",
              campaignId: args.data.campaignId,
              cursor: args.data.cursor,
              entityType: args.data.entityType,
              entityId: args.data.entityId,
              operation: args.data.operation,
              revision: args.data.revision,
              createdAt: new Date(),
            })),
          },
        };
        return cb(tx);
      });

      const first = await service.record(
        "campaign-1",
        "character",
        "character-1",
        "upsert",
        1,
      );
      const second = await service.record(
        "campaign-1",
        "content",
        "entry-1",
        "upsert",
        1,
      );

      expect(BigInt(second.cursor)).toBe(BigInt(first.cursor) + 1n);
      expect(first.entityType).toBe("character");
      expect(second.entityType).toBe("content");
      expect(first.cursor).toBe("1");
      expect(second.cursor).toBe("2");
    });

    it("initializes cursor at 1 for a new campaign", async () => {
      prismaService.$transaction.mockImplementation(async (cb: any) => {
        const tx = {
          campaignSyncState: {
            upsert: jest.fn().mockResolvedValue({
              campaignId: "campaign-new",
              cursor: 1n,
            }),
          },
          campaignChange: {
            create: jest.fn().mockResolvedValue({
              id: "change-1",
              campaignId: "campaign-new",
              cursor: 1n,
              entityType: "character",
              entityId: "character-1",
              operation: "upsert",
              revision: 1,
              createdAt: new Date(),
            }),
          },
        };
        return cb(tx);
      });

      const result = await service.record(
        "campaign-new",
        "character",
        "character-1",
        "upsert",
        1,
      );

      expect(result.cursor).toBe("1");
    });

    it("serializes BigInt cursor as a decimal string", async () => {
      prismaService.$transaction.mockImplementation(async (cb: any) => {
        const tx = {
          campaignSyncState: {
            upsert: jest.fn().mockResolvedValue({
              campaignId: "c1",
              cursor: 1234567890123456789n,
            }),
          },
          campaignChange: {
            create: jest.fn().mockResolvedValue({
              id: "change-big",
              campaignId: "c1",
              cursor: 1234567890123456789n,
              entityType: "character",
              entityId: "character-1",
              operation: "upsert",
              revision: 1,
              createdAt: new Date(),
            }),
          },
        };
        return cb(tx);
      });

      const result = await service.record(
        "c1",
        "character",
        "character-1",
        "upsert",
        1,
      );

      expect(result.cursor).toBe("1234567890123456789");
      expect(typeof result.cursor).toBe("string");
    });

    it("records the revision passed by the caller", async () => {
      prismaService.$transaction.mockImplementation(async (cb: any) => {
        const tx = {
          campaignSyncState: {
            upsert: jest.fn().mockResolvedValue({ campaignId: "c1", cursor: 5n }),
          },
          campaignChange: {
            create: jest.fn().mockResolvedValue({
              id: "change-5",
              campaignId: "c1",
              cursor: 5n,
              entityType: "character",
              entityId: "character-1",
              operation: "upsert",
              revision: 3,
              createdAt: new Date(),
            }),
          },
        };
        return cb(tx);
      });

      const result = await service.record(
        "c1",
        "character",
        "character-1",
        "upsert",
        3,
      );

      expect(result.revision).toBe(3);
    });
  });

  describe("listChanges", () => {
    it("returns paginated changes with string cursors", async () => {
      prismaService.campaignChange.findMany.mockResolvedValue([
        {
          id: "change-1",
          campaignId: "c1",
          cursor: 1n,
          entityType: "character",
          entityId: "character-1",
          operation: "upsert",
          revision: 1,
          createdAt: new Date("2026-07-14T00:00:00Z"),
        },
        {
          id: "change-2",
          campaignId: "c1",
          cursor: 2n,
          entityType: "content",
          entityId: "entry-1",
          operation: "upsert",
          revision: 1,
          createdAt: new Date("2026-07-14T00:01:00Z"),
        },
      ]);

      const page = await service.listChanges("c1", "0", 100);

      expect(prismaService.campaignChange.findMany).toHaveBeenCalledWith({
        where: { campaignId: "c1", cursor: { gt: BigInt(0) } },
        orderBy: { cursor: "asc" },
        take: 101,
      });
      expect(page.items).toHaveLength(2);
      expect(page.items[0].cursor).toBe("1");
      expect(page.items[1].cursor).toBe("2");
      expect(page.nextCursor).toBe("2");
      expect(page.hasMore).toBe(false);
    });

    it("signals hasMore when the page is full", async () => {
      const rows = Array.from({ length: 101 }, (_, index) => ({
        id: `change-${index + 1}`,
        campaignId: "c1",
        cursor: BigInt(index + 1),
        entityType: "character",
        entityId: `character-${index + 1}`,
        operation: "upsert",
        revision: 1,
        createdAt: new Date(),
      }));
      prismaService.campaignChange.findMany.mockResolvedValue(rows);

      const page = await service.listChanges("c1", "0", 100);

      expect(page.items).toHaveLength(100);
      expect(page.hasMore).toBe(true);
      expect(page.nextCursor).toBe("100");
    });

    it("returns the supplied cursor when there are no changes", async () => {
      prismaService.campaignChange.findMany.mockResolvedValue([]);

      const page = await service.listChanges("c1", "42", 100);

      expect(page.items).toHaveLength(0);
      expect(page.nextCursor).toBe("42");
      expect(page.hasMore).toBe(false);
    });
  });
});
