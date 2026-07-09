import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards
} from '@nestjs/common';
import { AccessTokenPayload } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CheckRequestsService } from './check-requests.service';
import type { CheckRequestView, CheckResponseView } from './check-requests.types';

interface CreateCheckRequestBody {
  label?: unknown;
  checkType?: unknown;
  ability?: unknown;
  skill?: unknown;
  dc?: unknown;
  dcVisibility?: unknown;
  targetMode?: unknown;
  targetUserIds?: unknown;
  targetCharacterIds?: unknown;
}

interface RespondToCheckRequestBody {
  actorName?: unknown;
  modifier?: unknown;
  characterId?: unknown;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class CheckRequestsController {
  constructor(private readonly checkRequestsService: CheckRequestsService) {}

  @Post('sessions/:id/check-requests')
  createCheckRequest(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') sessionId: string,
    @Body() body: CreateCheckRequestBody
  ): Promise<CheckRequestView> {
    if (!isNonEmptyString(body.label)) {
      throw new BadRequestException('Check label is required');
    }

    return this.checkRequestsService.createCheckRequest(user, sessionId, {
      sessionId,
      label: body.label,
      checkType: isNonEmptyString(body.checkType) ? body.checkType : undefined,
      ability: isNonEmptyString(body.ability) ? body.ability : undefined,
      skill: isNonEmptyString(body.skill) ? body.skill : undefined,
      dc: typeof body.dc === 'number' ? body.dc : undefined,
      dcVisibility: isNonEmptyString(body.dcVisibility)
        ? body.dcVisibility
        : undefined,
      targetMode: isNonEmptyString(body.targetMode)
        ? body.targetMode
        : undefined,
      targetUserIds: toStringArray(body.targetUserIds),
      targetCharacterIds: toStringArray(body.targetCharacterIds)
    });
  }

  @Get('sessions/:id/check-requests')
  listCheckRequests(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') sessionId: string
  ): Promise<CheckRequestView[]> {
    return this.checkRequestsService.listCheckRequests(user, sessionId);
  }

  @Post('check-requests/:id/responses')
  respondToCheckRequest(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') requestId: string,
    @Body() body: RespondToCheckRequestBody
  ): Promise<CheckResponseView> {
    if (!isNonEmptyString(body.actorName)) {
      throw new BadRequestException('Actor name is required');
    }
    return this.checkRequestsService.respondToCheckRequest(user, requestId, {
      actorName: body.actorName,
      modifier: typeof body.modifier === 'number' ? body.modifier : undefined,
      characterId: isNonEmptyString(body.characterId)
        ? body.characterId
        : undefined
    });
  }

  @Post('check-requests/:id/close')
  @HttpCode(200)
  closeCheckRequest(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') requestId: string
  ): Promise<CheckRequestView> {
    return this.checkRequestsService.closeCheckRequest(user, requestId);
  }
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function toStringArray(value: unknown): string[] | undefined {
  if (!Array.isArray(value)) return undefined;
  return value.filter((item): item is string => typeof item === 'string');
}
