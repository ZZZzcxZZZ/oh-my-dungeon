import {
  BadRequestException,
  Body,
  Controller,
  Param,
  Post,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import type { AccessTokenPayload } from "../auth/auth.types";
import { CampaignEventsService } from "./campaign-events.service";
import type { CampaignEventResult } from "./campaign-sync.types";

// Task 3.1 — CampaignEvent 事件层 HTTP 入口.
// 路径与 CampaignActorsController 对齐: /campaigns/:campaignId/actors/:actorId/...
// 这两个端点返回 {actor, event} 复合响应, 客户端可同时刷新 actor 缓存与
// 追加聊天消息, 无需二次拉取.
@Controller("campaigns/:campaignId/actors/:actorId")
@UseGuards(JwtAuthGuard)
export class CampaignEventsController {
  constructor(private readonly eventsService: CampaignEventsService) {}

  /**
   * 调整 actor HP. body: { delta: number, reason?: string, baseRevision?: number }.
   * delta < 0 为伤害 (clamp 到 0), > 0 为治疗 (clamp 到 maxHp).
   * 同事务内追加 actor.hp_changed 系统事件消息并广播.
   */
  @Post("hp")
  changeActorHp(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
    @Body() body: ChangeActorHpBody,
  ): Promise<CampaignEventResult> {
    if (
      typeof body.delta !== "number" ||
      !Number.isFinite(body.delta) ||
      body.delta === 0
    ) {
      throw new BadRequestException(
        "delta must be a non-zero finite number",
      );
    }
    return this.eventsService.changeActorHp(user, campaignId, actorId, {
      delta: body.delta,
      reason: typeof body.reason === "string" ? body.reason : undefined,
      baseRevision:
        typeof body.baseRevision === "number" ? body.baseRevision : undefined,
    });
  }

  /**
   * 给予 actor 物品. body: { itemId, name, quantity?, baseRevision? }.
   * 同事务内追加 actor.item_granted 系统事件消息并广播.
   */
  @Post("items")
  grantItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("actorId") actorId: string,
    @Body() body: GrantItemBody,
  ): Promise<CampaignEventResult> {
    if (typeof body.itemId !== "string" || body.itemId.trim().length === 0) {
      throw new BadRequestException("itemId is required");
    }
    if (typeof body.name !== "string" || body.name.trim().length === 0) {
      throw new BadRequestException("name is required");
    }
    return this.eventsService.grantItem(user, campaignId, actorId, {
      itemId: body.itemId,
      name: body.name,
      quantity:
        typeof body.quantity === "number" ? body.quantity : undefined,
      baseRevision:
        typeof body.baseRevision === "number" ? body.baseRevision : undefined,
    });
  }
}

interface ChangeActorHpBody {
  delta?: unknown;
  reason?: unknown;
  baseRevision?: unknown;
}

interface GrantItemBody {
  itemId?: unknown;
  name?: unknown;
  quantity?: unknown;
  baseRevision?: unknown;
}
