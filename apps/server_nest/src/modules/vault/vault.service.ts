import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import type { Prisma } from "@prisma/client";
import { PrismaService } from "../../prisma/prisma.service";
import type {
  VaultChangePage,
  VaultChangeRow,
  VaultConflict,
  VaultDeviceView,
  VaultPushOperation,
  VaultPushResult,
} from "./vault.types";

const DEFAULT_DEVICE_NAME = "Unknown";
const DEFAULT_DEVICE_PLATFORM = "unknown";
const CHANGE_PAGE_SIZE = 500;

@Injectable()
export class VaultService {
  constructor(private readonly prismaService: PrismaService) {}

  async push(
    userId: string,
    deviceId: string,
    operations: VaultPushOperation[],
  ): Promise<VaultPushResult> {
    await this.assertDeviceCanSync(userId, deviceId);
    const applied: string[] = [];
    const skipped: string[] = [];
    const conflicts: VaultConflict[] = [];
    const seenOperationIds = new Set<string>();

    await this.prismaService.$transaction(async (tx) => {
      for (const op of operations) {
        if (seenOperationIds.has(op.operationId)) {
          skipped.push(op.operationId);
          continue;
        }
        seenOperationIds.add(op.operationId);

        try {
          await tx.vaultOperation.create({
            data: { operationId: op.operationId, userId },
          });
        } catch (error) {
          if (isPrismaUniqueViolation(error)) {
            skipped.push(op.operationId);
            continue;
          }
          throw error;
        }

        const existing = await tx.vaultEntity.findUnique({
          where: {
            userId_entityType_entityId: {
              userId,
              entityType: op.entityType,
              entityId: op.entityId,
            },
          },
        });

        if (existing && existing.revision !== op.baseRevision) {
          conflicts.push({
            entityId: op.entityId,
            currentRevision: existing.revision,
          });
          continue;
        }

        const nextRevision = op.baseRevision + 1;
        const compoundWhere = {
          userId_entityType_entityId: {
            userId,
            entityType: op.entityType,
            entityId: op.entityId,
          },
        };
        const entityWhere = {
          userId,
          entityType: op.entityType,
          entityId: op.entityId,
        };
        const payloadJson = op.payload as Prisma.InputJsonValue;

        const deletedAt = op.operation === "delete" ? new Date() : null;
        if (existing) {
          // The prior read is only for the fast conflict path. The revision is
          // repeated in the write predicate so another device cannot slip a
          // write between this read and the mutation.
          const result = await tx.vaultEntity.updateMany({
            where: {
              ...entityWhere,
              revision: op.baseRevision,
            },
            data: {
              payload: payloadJson,
              revision: nextRevision,
              deletedAt,
            },
          });
          if (result.count !== 1) {
            const current = await tx.vaultEntity.findUnique({
              where: compoundWhere,
            });
            conflicts.push({
              entityId: op.entityId,
              currentRevision: current?.revision ?? 0,
            });
            continue;
          }
        } else {
          try {
            await tx.vaultEntity.create({
              data: {
                userId,
                entityType: op.entityType,
                entityId: op.entityId,
                payload: payloadJson,
                revision: nextRevision,
                deletedAt,
              },
            });
          } catch (error) {
            if (isPrismaUniqueViolation(error)) {
              const current = await tx.vaultEntity.findUnique({
                where: compoundWhere,
              });
              conflicts.push({
                entityId: op.entityId,
                currentRevision: current?.revision ?? 0,
              });
              continue;
            }
            throw error;
          }
        }

        await tx.vaultChange.createMany({
          data: [
            {
              userId,
              entityType: op.entityType,
              entityId: op.entityId,
              operation: op.operation,
              payload: payloadJson,
              revision: nextRevision,
            },
          ],
        });

        applied.push(op.operationId);
      }
    });

    await this.prismaService.vaultDevice.upsert({
      where: { userId_deviceId: { userId, deviceId } },
      create: {
        userId,
        deviceId,
        name: DEFAULT_DEVICE_NAME,
        platform: DEFAULT_DEVICE_PLATFORM,
      },
      update: { lastSeenAt: new Date() },
    });

    return { applied, skipped, conflicts };
  }

  async getChanges(
    userId: string,
    deviceId: string,
    cursor: string,
  ): Promise<VaultChangePage> {
    await this.assertDeviceCanSync(userId, deviceId);
    const cursorBigInt = BigInt(cursor);
    const rows = await this.prismaService.vaultChange.findMany({
      where: { userId, cursor: { gt: cursorBigInt } },
      orderBy: { cursor: "asc" },
      take: CHANGE_PAGE_SIZE + 1,
    });

    const hasMore = rows.length > CHANGE_PAGE_SIZE;
    const page = hasMore ? rows.slice(0, CHANGE_PAGE_SIZE) : rows;
    const changes: VaultChangeRow[] = page.map((row) => ({
      cursor: row.cursor.toString(),
      userId: row.userId,
      entityType: row.entityType,
      entityId: row.entityId,
      operation: row.operation,
      payload: (row.payload ?? {}) as Record<string, unknown>,
      revision: row.revision,
      createdAt: row.createdAt.toISOString(),
    }));

    const lastCursor =
      changes.length > 0 ? changes[changes.length - 1].cursor : cursor;

    await this.prismaService.vaultDevice.upsert({
      where: { userId_deviceId: { userId, deviceId } },
      create: {
        userId,
        deviceId,
        name: DEFAULT_DEVICE_NAME,
        platform: DEFAULT_DEVICE_PLATFORM,
        lastCursor: BigInt(lastCursor),
      },
      update: {
        lastCursor: BigInt(lastCursor),
        lastSeenAt: new Date(),
      },
    });

    return { cursor: lastCursor, changes, hasMore };
  }

  async listDevices(userId: string): Promise<VaultDeviceView[]> {
    const devices = await this.prismaService.vaultDevice.findMany({
      where: { userId, revokedAt: null },
    });

    return devices.map((d) => ({
      deviceId: d.deviceId,
      name: d.name,
      platform: d.platform,
      lastCursor: d.lastCursor.toString(),
      lastSeenAt: d.lastSeenAt.toISOString(),
      revokedAt: d.revokedAt ? d.revokedAt.toISOString() : null,
    }));
  }

  async revokeDevice(
    userId: string,
    deviceId: string,
    targetDeviceId: string,
  ): Promise<void> {
    if (targetDeviceId === deviceId) {
      throw new BadRequestException("Cannot revoke the current device");
    }

    const device = await this.prismaService.vaultDevice.findUnique({
      where: {
        userId_deviceId: { userId, deviceId: targetDeviceId },
      },
    });

    if (!device) {
      throw new NotFoundException("Device not found");
    }

    await this.prismaService.vaultDevice.update({
      where: { userId_deviceId: { userId, deviceId: targetDeviceId } },
      data: { revokedAt: new Date() },
    });
  }

  private async assertDeviceCanSync(
    userId: string,
    deviceId: string,
  ): Promise<void> {
    const device = await this.prismaService.vaultDevice.findUnique({
      where: { userId_deviceId: { userId, deviceId } },
    });
    if (device?.revokedAt != null) {
      throw new ForbiddenException("This device has been revoked");
    }
  }
}

function isPrismaUniqueViolation(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code: unknown }).code === "P2002"
  );
}
