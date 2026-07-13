import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../prisma/prisma.service";
import type {
  CampaignChangeOperation,
  CampaignChangePage,
  CampaignChangeRecord,
  CampaignEntityType,
} from "./campaign-sync.types";

const DEFAULT_PAGE_SIZE = 100;
const MAX_PAGE_SIZE = 500;

/**
 * Prisma stores `entityType` and `operation` as plain strings. This minimal
 * shape lets us accept both the real Prisma transaction client and test
 * doubles without fighting Prisma's generated string-typed columns.
 */
interface CampaignChangeTx {
  campaignSyncState: {
    upsert: (args: {
      where: { campaignId: string };
      create: { campaignId: string; cursor: bigint };
      update: { cursor: { increment: bigint } };
    }) => Promise<{ campaignId: string; cursor: bigint }>;
  };
  campaignChange: {
    create: (args: {
      data: {
        campaignId: string;
        cursor: bigint;
        entityType: CampaignEntityType;
        entityId: string;
        operation: CampaignChangeOperation;
        revision: number;
      };
    }) => Promise<CampaignChangeRow>;
  };
}

interface CampaignChangeRow {
  id: string;
  campaignId: string;
  cursor: bigint;
  entityType: string;
  entityId: string;
  operation: string;
  revision: number;
  createdAt: Date;
}

@Injectable()
export class CampaignChangeService {
  constructor(private readonly prismaService: PrismaService) {}

  /**
   * Atomically allocates the next campaign cursor and writes a CampaignChange
   * row inside the supplied transaction. The caller is responsible for
   * committing the transaction; if it rolls back, both writes are reverted.
   */
  async recordInTransaction(
    tx: CampaignChangeTx,
    campaignId: string,
    entityType: CampaignEntityType,
    entityId: string,
    operation: CampaignChangeOperation,
    revision: number,
  ): Promise<CampaignChangeRecord> {
    const state = await tx.campaignSyncState.upsert({
      where: { campaignId },
      create: { campaignId, cursor: 1n },
      update: { cursor: { increment: 1n } },
    });

    const change = await tx.campaignChange.create({
      data: {
        campaignId,
        cursor: state.cursor,
        entityType,
        entityId,
        operation,
        revision,
      },
    });

    return toChangeRecord(change);
  }

  /**
   * Convenience wrapper that runs `recordInTransaction` inside a fresh
   * Prisma transaction. Use this when the caller has no other writes to
   * bundle with the cursor allocation.
   */
  async record(
    campaignId: string,
    entityType: CampaignEntityType,
    entityId: string,
    operation: CampaignChangeOperation,
    revision: number,
  ): Promise<CampaignChangeRecord> {
    return this.prismaService.$transaction((tx) =>
      this.recordInTransaction(
        tx as unknown as CampaignChangeTx,
        campaignId,
        entityType,
        entityId,
        operation,
        revision,
      ),
    );
  }

  async listChanges(
    campaignId: string,
    cursor: string,
    limit?: number,
  ): Promise<CampaignChangePage> {
    const pageSize = clampPageSize(limit);
    const cursorBigInt = BigInt(cursor);

    const rows = (await this.prismaService.campaignChange.findMany({
      where: { campaignId, cursor: { gt: cursorBigInt } },
      orderBy: { cursor: "asc" },
      take: pageSize + 1,
    })) as CampaignChangeRow[];

    const hasMore = rows.length > pageSize;
    const page = hasMore ? rows.slice(0, pageSize) : rows;
    const items = page.map(toChangeRecord);
    const nextCursor =
      items.length > 0 ? items[items.length - 1].cursor : cursor;

    return { items, nextCursor, hasMore };
  }
}

function toChangeRecord(row: CampaignChangeRow): CampaignChangeRecord {
  return {
    id: row.id,
    campaignId: row.campaignId,
    cursor: row.cursor.toString(),
    entityType: row.entityType as CampaignEntityType,
    entityId: row.entityId,
    operation: row.operation as CampaignChangeOperation,
    revision: row.revision,
    createdAt: row.createdAt.toISOString(),
  };
}

function clampPageSize(limit?: number): number {
  if (typeof limit !== "number" || !Number.isFinite(limit) || limit <= 0) {
    return DEFAULT_PAGE_SIZE;
  }
  return Math.min(Math.floor(limit), MAX_PAGE_SIZE);
}
