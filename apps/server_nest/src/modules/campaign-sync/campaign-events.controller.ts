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
// 路径与 CampaignCharactersController 对齐: /campaigns/:campaignId/characters/:characterId/...
// 这两个端点返回 {character, event} 复合响应, 客户端可同时刷新 character 缓存与
// 追加聊天消息, 无需二次拉取.
@Controller("campaigns/:campaignId/characters/:characterId")
@UseGuards(JwtAuthGuard)
export class CampaignEventsController {
  constructor(private readonly eventsService: CampaignEventsService) {}

  /**
   * 调整 character HP. body: { delta: number, reason?: string, baseRevision?: number }.
   * delta < 0 为伤害 (clamp 到 0), > 0 为治疗 (clamp 到 maxHp).
   * 同事务内追加 character.hp_changed 系统事件消息并广播.
   */
  @Post("hp")
  changeCharacterHp(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: ChangeCharacterHpBody,
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
    return this.eventsService.changeCharacterHp(user, campaignId, characterId, {
      delta: body.delta,
      reason: typeof body.reason === "string" ? body.reason : undefined,
      baseRevision:
        typeof body.baseRevision === "number" ? body.baseRevision : undefined,
    });
  }

  /**
   * 给予 character 物品. body: { itemId, name, quantity?, baseRevision? }.
   * 同事务内追加 character.item_granted 系统事件消息并广播.
   */
  @Post("items")
  grantItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: GrantItemBody,
  ): Promise<CampaignEventResult> {
    if (typeof body.itemId !== "string" || body.itemId.trim().length === 0) {
      throw new BadRequestException("itemId is required");
    }
    if (typeof body.name !== "string" || body.name.trim().length === 0) {
      throw new BadRequestException("name is required");
    }
    return this.eventsService.grantItem(user, campaignId, characterId, {
      itemId: body.itemId,
      name: body.name,
      quantity:
        typeof body.quantity === "number" ? body.quantity : undefined,
      baseRevision:
        typeof body.baseRevision === "number" ? body.baseRevision : undefined,
    });
  }

  /**
   * 给予 character 结构化状态. body: { type, name, durationRounds?, baseRevision? }.
   * 同事务内追加 character.condition_added 系统事件消息并广播.
   */
  @Post("conditions")
  addCondition(
    @CurrentUser() user: AccessTokenPayload,
    @Param("campaignId") campaignId: string,
    @Param("characterId") characterId: string,
    @Body() body: AddConditionBody,
  ): Promise<CampaignEventResult> {
    if (typeof body.type !== "string" || body.type.trim().length === 0) {
      throw new BadRequestException("type is required");
    }
    if (typeof body.name !== "string" || body.name.trim().length === 0) {
      throw new BadRequestException("name is required");
    }
    return this.eventsService.addCondition(user, campaignId, characterId, {
      type: body.type,
      name: body.name,
      durationRounds:
        typeof body.durationRounds === "number"
          ? body.durationRounds
          : undefined,
      baseRevision:
        typeof body.baseRevision === "number" ? body.baseRevision : undefined,
    });
  }
}

interface ChangeCharacterHpBody {
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

interface AddConditionBody {
  type?: unknown;
  name?: unknown;
  durationRounds?: unknown;
  baseRevision?: unknown;
}
