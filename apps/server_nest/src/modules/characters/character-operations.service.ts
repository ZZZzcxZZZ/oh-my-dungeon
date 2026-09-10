import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import type { AccessTokenPayload } from '../auth/auth.types';
import { GameEventsService } from '../game-events/game-events.service';
import { CharacterStateStore } from './character-state.store';
import {
  CharacterState,
  applyHitPointDelta,
  parseCharacterState,
  serializeCharacterState,
} from './domain/character-state';

interface OperationBase {
  requestId: string;
  campaignId?: string | null;
  expectedRevision?: number;
}

/** requestId 全局唯一 (AI Agent 契约 §3.1); 校验非空并限制长度. */
function assertRequestId(requestId: string): void {
  if (!requestId.trim()) {
    throw new BadRequestException('requestId is required');
  }
  if (requestId.length > 128) {
    throw new BadRequestException('requestId must be at most 128 characters');
  }
}

/** Prisma 唯一约束冲突 (如并发同 requestId 撞 GameEvent.requestId). */
function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2002'
  );
}

type GameEventRow = NonNullable<
  Awaited<ReturnType<PrismaService['gameEvent']['findUnique']>>
>;

const ITEM_TRANSFER_OPERATION_TYPE = 'character.item.transferred';

export interface CharacterOperationResult {
  state: CharacterState;
  revision: number;
  event: unknown;
}

@Injectable()
export class CharacterOperationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stateStore: CharacterStateStore,
    private readonly events: GameEventsService,
  ) {}

  adjustHitPoints(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & {
      delta?: number;
      current?: number;
      temporary?: number;
    },
  ) {
    if (input.delta === undefined && input.current === undefined) {
      throw new BadRequestException('delta or current is required');
    }
    return this.mutate(
      user,
      characterId,
      input,
      'character.hp.adjusted',
      (state) => {
        const before = {
          current: state.hitPoints.current,
          temporary: state.hitPoints.temporary,
        };
        // 2024：伤害先扣临时生命值，溢出才扣当前生命值；
        // 治疗提高当前生命值但不超过上限，且不改变临时生命值。
        const base = {
          current: state.hitPoints.current,
          maximum: state.hitPoints.maximum,
          temporary:
            input.temporary === undefined
              ? state.hitPoints.temporary
              : Math.max(0, input.temporary),
        };
        const settled =
          input.current === undefined
            ? applyHitPointDelta(base, input.delta ?? 0)
            : {
                ...base,
                current: Math.min(base.maximum, Math.max(0, input.current)),
              };
        const current = settled.current;
        const temporary = settled.temporary;
        const next = parseCharacterState({
          ...serializeCharacterState(state),
          hitPoints: {
            current,
            maximum: state.hitPoints.maximum,
            temporary,
          },
        });
        return {
          state: next,
          before,
          after: { current, temporary },
          payload: { delta: input.delta ?? current - before.current },
          compatibility: {
            currentHp: current,
            maxHp: state.hitPoints.maximum,
          },
        };
      },
    );
  }

  addCondition(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { condition: Record<string, unknown> },
  ) {
    return this.mutate(
      user,
      characterId,
      input,
      'character.condition.added',
      (state) => {
        const next = parseCharacterState({
          ...serializeCharacterState(state),
          conditions: [...state.conditions, input.condition],
        });
        if (next.conditions.length === state.conditions.length) {
          throw new BadRequestException('Invalid condition');
        }
        const condition = next.conditions[next.conditions.length - 1];
        return {
          state: next,
          before: {},
          after: { condition },
          payload: { conditionId: condition.id },
        };
      },
    );
  }

  removeCondition(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { conditionId: string },
  ) {
    return this.mutate(
      user,
      characterId,
      input,
      'character.condition.removed',
      (state) => {
        const condition = state.conditions.find(
          (item) => item.id === input.conditionId,
        );
        if (!condition) throw new NotFoundException('Condition not found');
        const next = parseCharacterState({
          ...serializeCharacterState(state),
          conditions: state.conditions.filter(
            (item) => item.id !== input.conditionId,
          ),
        });
        return {
          state: next,
          before: { condition },
          after: {},
          payload: { conditionId: input.conditionId },
        };
      },
    );
  }

  consumeResource(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { resourceId: string; amount?: number },
  ) {
    return this.changeResource(
      user,
      characterId,
      input,
      -Math.max(1, input.amount ?? 1),
      'character.resource.consumed',
    );
  }

  restoreResource(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { resourceId: string; amount?: number },
  ) {
    return this.changeResource(
      user,
      characterId,
      input,
      Math.max(1, input.amount ?? Number.MAX_SAFE_INTEGER),
      'character.resource.restored',
    );
  }

  grantItem(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { item: Record<string, unknown> },
  ) {
    return this.mutate(
      user,
      characterId,
      input,
      'character.item.granted',
      (state) => {
        const next = parseCharacterState({
          ...serializeCharacterState(state),
          items: [...state.items, input.item],
        });
        if (next.items.length === state.items.length) {
          throw new BadRequestException('Invalid item');
        }
        const item = next.items[next.items.length - 1];
        return {
          state: next,
          before: {},
          after: { item },
          payload: { itemId: item.id, quantity: item.quantity },
          compatibility: {
            inventory: next.items as unknown as Prisma.InputJsonValue,
          },
        };
      },
    );
  }

  consumeItem(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { itemId: string; quantity?: number },
  ) {
    return this.changeItem(
      user,
      characterId,
      input,
      'character.item.consumed',
      (item) => ({ ...item, quantity: item.quantity - (input.quantity ?? 1) }),
    );
  }

  equipItem(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { itemId: string; equipped: boolean },
  ) {
    return this.changeItem(
      user,
      characterId,
      input,
      'character.item.equipped',
      (item) => ({ ...item, equipped: input.equipped }),
    );
  }

  async transferItem(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & {
      campaignId: string;
      targetCharacterId: string;
      itemId: string;
      quantity?: number;
    },
  ) {
    const quantity = Math.max(1, input.quantity ?? 1);
    assertRequestId(input.requestId);
    await this.assertCanEdit(user, characterId, input.campaignId);
    const target = await this.prisma.character.findUnique({
      where: { id: input.targetCharacterId },
    });
    if (!target) throw new NotFoundException('Target character not found');
    const campaign = await this.prisma.campaign.findUnique({
      where: { id: input.campaignId },
      include: { members: true },
    });
    if (
      !campaign ||
      !campaign.members.some((member) => member.userId === target.ownerUserId)
    ) {
      throw new ForbiddenException('Target character is not in the campaign');
    }
    try {
      return await this.prisma.$transaction(async (tx) => {
      const existing = await this.findReplayEvent(
        tx,
        input.requestId,
        ITEM_TRANSFER_OPERATION_TYPE,
      );
      const source = await this.stateStore.getOrCreate(
        tx,
        characterId,
        input.campaignId,
      );
      const destination = await this.stateStore.getOrCreate(
        tx,
        input.targetCharacterId,
        input.campaignId,
      );
      if (existing) {
        return {
          sourceState: source.state,
          targetState: destination.state,
          event: existing,
        };
      }
      const item = source.state.items.find(
        (entry) => entry.id === input.itemId,
      );
      if (!item || item.quantity < quantity) {
        throw new BadRequestException('Insufficient item quantity');
      }
      const sourceItems = source.state.items
        .map((entry) =>
          entry.id === item.id
            ? { ...entry, quantity: entry.quantity - quantity }
            : entry,
        )
        .filter((entry) => entry.quantity > 0);
      const matchingTarget = destination.state.items.find(
        (entry) =>
          entry.templateRef === item.templateRef && entry.name === item.name,
      );
      const targetItems = matchingTarget
        ? destination.state.items.map((entry) =>
            entry.id === matchingTarget.id
              ? { ...entry, quantity: entry.quantity + quantity }
              : entry,
          )
        : [
            ...destination.state.items,
            {
              ...item,
              id: `${item.id}:transfer:${input.requestId}`,
              quantity,
            },
          ];
      const sourceState = parseCharacterState({
        ...serializeCharacterState(source.state),
        items: sourceItems,
      });
      const targetState = parseCharacterState({
        ...serializeCharacterState(destination.state),
        items: targetItems,
      });
      await tx.characterState.update({
        where: { id: source.id },
        data: {
          stateJson: serializeCharacterState(
            sourceState,
          ) as Prisma.InputJsonValue,
          revision: { increment: 1 },
        },
      });
      await tx.characterState.update({
        where: { id: destination.id },
        data: {
          stateJson: serializeCharacterState(
            targetState,
          ) as Prisma.InputJsonValue,
          revision: { increment: 1 },
        },
      });
      await tx.character.update({
        where: { id: characterId },
        data: { inventory: sourceItems as unknown as Prisma.InputJsonValue },
      });
      await tx.character.update({
        where: { id: input.targetCharacterId },
        data: { inventory: targetItems as unknown as Prisma.InputJsonValue },
      });
      const event = await this.events.append(tx, {
        type: ITEM_TRANSFER_OPERATION_TYPE,
        campaignId: input.campaignId,
        characterId,
        initiatorType: 'user',
        initiatorId: user.userId,
        requestId: input.requestId,
        targets: [
          { type: 'character', id: characterId },
          { type: 'character', id: input.targetCharacterId },
        ],
        before: { sourceQuantity: item.quantity },
        after: { sourceQuantity: item.quantity - quantity },
        payload: {
          itemId: item.id,
          targetCharacterId: input.targetCharacterId,
          quantity,
        },
      });
      return { sourceState, targetState, event };
      });
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      // 并发同 requestId: 对方事务已提交, 重放其首次结果, 不重复转移.
      const existing = await this.findReplayEvent(
        this.prisma,
        input.requestId,
        ITEM_TRANSFER_OPERATION_TYPE,
      );
      if (existing) {
        const source = await this.stateStore.getOrCreate(
          this.prisma,
          characterId,
          input.campaignId,
        );
        const destination = await this.stateStore.getOrCreate(
          this.prisma,
          input.targetCharacterId,
          input.campaignId,
        );
        return {
          sourceState: source.state,
          targetState: destination.state,
          event: existing,
        };
      }
      throw error;
    }
  }

  private changeResource(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { resourceId: string },
    delta: number,
    type: string,
  ) {
    return this.mutate(user, characterId, input, type, (state) => {
      const resource = state.resources.find(
        (item) => item.id === input.resourceId,
      );
      if (!resource) throw new NotFoundException('Resource not found');
      const current = Math.min(
        resource.maximum,
        Math.max(0, resource.current + delta),
      );
      const resources = state.resources.map((item) =>
        item.id === resource.id ? { ...item, current } : item,
      );
      return {
        state: parseCharacterState({
          ...serializeCharacterState(state),
          resources,
        }),
        before: { current: resource.current },
        after: { current },
        payload: { resourceId: resource.id, amount: Math.abs(delta) },
      };
    });
  }

  private changeItem(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase & { itemId: string },
    type: string,
    change: (item: CharacterState['items'][number]) => Record<string, unknown>,
  ) {
    return this.mutate(user, characterId, input, type, (state) => {
      const item = state.items.find((entry) => entry.id === input.itemId);
      if (!item) throw new NotFoundException('Item not found');
      const changed = change(item);
      const items = state.items
        .map((entry) => (entry.id === item.id ? changed : entry))
        .filter((entry) => Number(entry.quantity) > 0);
      const next = parseCharacterState({
        ...serializeCharacterState(state),
        items,
      });
      return {
        state: next,
        before: { item },
        after: { item: next.items.find((entry) => entry.id === item.id) ?? null },
        payload: { itemId: item.id },
        compatibility: {
          inventory: next.items as unknown as Prisma.InputJsonValue,
        },
      };
    });
  }

  private async mutate(
    user: AccessTokenPayload,
    characterId: string,
    input: OperationBase,
    type: string,
    mutate: (state: CharacterState) => {
      state: CharacterState;
      before: Record<string, unknown>;
      after: Record<string, unknown>;
      payload: Record<string, unknown>;
      compatibility?: Record<string, unknown>;
    },
  ): Promise<CharacterOperationResult> {
    assertRequestId(input.requestId);
    await this.assertCanEdit(user, characterId, input.campaignId ?? null);
    try {
      return await this.prisma.$transaction(async (tx) => {
      const existing = await this.findReplayEvent(
        tx,
        input.requestId,
        type,
      );
      const scoped = await this.stateStore.getOrCreate(
        tx,
        characterId,
        input.campaignId ?? null,
      );
      if (existing) {
        return {
          state: scoped.state,
          revision: scoped.revision,
          event: existing,
        };
      }
      if (
        input.expectedRevision !== undefined &&
        input.expectedRevision !== scoped.revision
      ) {
        throw new ConflictException('Character state revision conflict');
      }
      const change = mutate(scoped.state);
      const updated = await tx.characterState.update({
        where: { id: scoped.id },
        data: {
          stateJson: serializeCharacterState(
            change.state,
          ) as Prisma.InputJsonValue,
          revision: { increment: 1 },
        },
      });
      if (change.compatibility) {
        await tx.character.update({
          where: { id: characterId },
          data: change.compatibility,
        });
      }
      const event = await this.events.append(tx, {
        type,
        campaignId: input.campaignId ?? null,
        characterId,
        initiatorType: 'user',
        initiatorId: user.userId,
        requestId: input.requestId,
        targets: [{ type: 'character', id: characterId }],
        before: change.before,
        after: change.after,
        payload: change.payload,
      });
      return {
        state: parseCharacterState(updated.stateJson),
        revision: updated.revision,
        event,
      };
      });
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      // 并发同 requestId: 对方事务已提交, 重放其首次结果, 不重复执行.
      const existing = await this.findReplayEvent(
        this.prisma,
        input.requestId,
        type,
      );
      if (existing) {
        const scoped = await this.stateStore.getOrCreate(
          this.prisma,
          characterId,
          input.campaignId ?? null,
        );
        return {
          state: scoped.state,
          revision: scoped.revision,
          event: existing,
        };
      }
      throw error;
    }
  }

  /**
   * 幂等锚: 相同 requestId 已在 GameEvent 中执行过时返回该事件.
   * 只匹配相同操作类型; requestId 被其他操作复用时报 400
   * (requestId 全局唯一, 见 AI Agent 契约 §3.1).
   */
  private async findReplayEvent(
    client: PrismaService | Prisma.TransactionClient,
    requestId: string,
    expectedType: string,
  ): Promise<GameEventRow | null> {
    const existing = await client.gameEvent.findUnique({
      where: { requestId },
    });
    if (!existing) return null;
    if (existing.type !== expectedType) {
      throw new BadRequestException(
        `requestId ${requestId} was already used by a different operation`,
      );
    }
    return existing;
  }

  private async assertCanEdit(
    user: AccessTokenPayload,
    characterId: string,
    campaignId: string | null,
  ): Promise<void> {
    const character = await this.prisma.character.findUnique({
      where: { id: characterId },
    });
    if (!character) throw new NotFoundException('Character not found');
    if (!campaignId) {
      if (character.ownerUserId !== user.userId) {
        throw new ForbiddenException('Character access denied');
      }
      return;
    }
    const campaign = await this.prisma.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true },
    });
    if (!campaign) throw new NotFoundException('Campaign not found');
    const membership = campaign.members.find(
      (member) => member.userId === user.userId,
    );
    const canManage =
      campaign.ownerId === user.userId ||
      membership?.role === 'owner' ||
      membership?.role === 'dm';
    const isOwner =
      character.ownerUserId === user.userId && membership !== undefined;
    if (!canManage && !isOwner) {
      throw new ForbiddenException('Character access denied');
    }
  }
}
