import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AccessTokenPayload } from '../auth/auth.types';
import { CharactersService } from './characters.service';
import { CharacterOperationsService } from './character-operations.service';
import { CharacterQueriesService } from './character-queries.service';
import type {
  CharacterCampaignBindingView,
  CharacterView
} from './characters.types';

interface CreateCharacterBody {
  name?: unknown;
  avatarUrl?: unknown;
  system?: unknown;
  level?: unknown;
  classSummary?: unknown;
  raceSummary?: unknown;
  currentHp?: unknown;
  maxHp?: unknown;
  armorClass?: unknown;
  speed?: unknown;
  initiativeBonus?: unknown;
  abilities?: unknown;
  saves?: unknown;
  skills?: unknown;
  inventory?: unknown;
  currency?: unknown;
  notes?: unknown;
  data?: unknown;
}

interface BindCharacterBody {
  campaignId?: unknown;
  visibility?: unknown;
}

interface UpdateCharacterBody extends CreateCharacterBody {
  campaignId?: unknown;
}

interface AdjustCharacterHpBody {
  delta?: unknown;
  currentHp?: unknown;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class CharactersController {
  constructor(
    private readonly charactersService: CharactersService,
    private readonly operations: CharacterOperationsService,
    private readonly queries: CharacterQueriesService,
  ) {}

  @Post('characters/:characterId/actions/adjust-hp')
  adjustHitPoints(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.operations.adjustHitPoints(user, characterId, {
      ...operationBase(body),
      delta: strictOptionalInteger(body.delta, 'delta'),
      current: strictOptionalInteger(body.current, 'current'),
      temporary: strictOptionalInteger(body.temporary, 'temporary'),
    });
  }

  @Post('characters/:characterId/actions/add-condition')
  addCondition(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Body() body: Record<string, unknown>,
  ) {
    if (!isRecord(body.condition)) {
      throw new BadRequestException('condition is required');
    }
    return this.operations.addCondition(user, characterId, {
      ...operationBase(body),
      condition: body.condition,
    });
  }

  @Post('characters/:characterId/actions/remove-condition')
  removeCondition(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.operations.removeCondition(user, characterId, {
      ...operationBase(body),
      conditionId: requiredString(body.conditionId, 'conditionId'),
    });
  }

  @Post('characters/:characterId/actions/consume-resource')
  consumeResource(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.operations.consumeResource(user, characterId, {
      ...operationBase(body),
      resourceId: requiredString(body.resourceId, 'resourceId'),
      amount: strictOptionalInteger(body.amount, 'amount'),
    });
  }

  @Post('characters/:characterId/actions/restore-resource')
  restoreResource(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.operations.restoreResource(user, characterId, {
      ...operationBase(body),
      resourceId: requiredString(body.resourceId, 'resourceId'),
      amount: strictOptionalInteger(body.amount, 'amount'),
    });
  }

  @Post('characters/:characterId/items')
  grantItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Body() body: Record<string, unknown>,
  ) {
    if (!isRecord(body.item)) {
      throw new BadRequestException('item is required');
    }
    return this.operations.grantItem(user, characterId, {
      ...operationBase(body),
      item: body.item,
    });
  }

  @Post('characters/:characterId/items/:itemId/actions/consume')
  consumeItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Param('itemId') itemId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.operations.consumeItem(user, characterId, {
      ...operationBase(body),
      itemId,
      quantity: strictOptionalInteger(body.quantity, 'quantity'),
    });
  }

  @Post('characters/:characterId/items/:itemId/actions/equip')
  equipItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Param('itemId') itemId: string,
    @Body() body: Record<string, unknown>,
  ) {
    if (typeof body.equipped !== 'boolean') {
      throw new BadRequestException('equipped must be a boolean');
    }
    return this.operations.equipItem(user, characterId, {
      ...operationBase(body),
      itemId,
      equipped: body.equipped,
    });
  }

  @Post('characters/:characterId/items/:itemId/actions/transfer')
  transferItem(
    @CurrentUser() user: AccessTokenPayload,
    @Param('characterId') characterId: string,
    @Param('itemId') itemId: string,
    @Body() body: Record<string, unknown>,
  ) {
    const base = operationBase(body);
    if (!base.campaignId) {
      throw new BadRequestException('campaignId is required');
    }
    return this.operations.transferItem(user, characterId, {
      ...base,
      campaignId: base.campaignId,
      itemId,
      targetCharacterId: requiredString(
        body.targetCharacterId,
        'targetCharacterId',
      ),
      quantity: strictOptionalInteger(body.quantity, 'quantity'),
    });
  }

  @Post('characters')
  createCharacter(
    @CurrentUser() user: AccessTokenPayload,
    @Body() body: CreateCharacterBody
  ): Promise<CharacterView> {
    if (!isNonEmptyString(body.name)) {
      throw new BadRequestException('Character name is required');
    }

    return this.charactersService.createCharacter(user, {
      name: body.name,
      avatarUrl: nullableString(body.avatarUrl),
      system: optionalString(body.system),
      level: optionalInteger(body.level),
      classSummary: optionalString(body.classSummary),
      raceSummary: optionalString(body.raceSummary),
      currentHp: optionalInteger(body.currentHp),
      maxHp: optionalInteger(body.maxHp),
      armorClass: optionalInteger(body.armorClass),
      speed: optionalInteger(body.speed),
      initiativeBonus: optionalInteger(body.initiativeBonus),
      abilities: optionalJson(body.abilities),
      saves: optionalJson(body.saves),
      skills: optionalJson(body.skills),
      inventory: optionalJson(body.inventory),
      currency: optionalJson(body.currency),
      notes: optionalString(body.notes),
      data: optionalJson(body.data)
    });
  }

  @Get('characters')
  listOwnedCharacters(
    @CurrentUser() user: AccessTokenPayload
  ): Promise<CharacterView[]> {
    return this.charactersService.listOwnedCharacters(user);
  }

  @Get('characters/:id')
  getCharacter(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Query('campaignId') campaignId?: string,
  ) {
    return this.queries.getResolved(user, id, campaignId ?? null);
  }

  @Get('characters/:id/summary')
  getCharacterSummary(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Query('campaignId') campaignId?: string,
  ) {
    return this.queries.getSummary(user, id, campaignId ?? null);
  }

  @Patch('characters/:id')
  updateCharacter(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() body: UpdateCharacterBody
  ): Promise<CharacterView> {
    return this.charactersService.updateCharacter(user, id, {
      campaignId: optionalString(body.campaignId),
      name: optionalString(body.name),
      avatarUrl: nullableString(body.avatarUrl),
      system: optionalString(body.system),
      level: optionalInteger(body.level),
      classSummary: optionalString(body.classSummary),
      raceSummary: optionalString(body.raceSummary),
      currentHp: optionalInteger(body.currentHp),
      maxHp: optionalInteger(body.maxHp),
      armorClass: optionalInteger(body.armorClass),
      speed: optionalInteger(body.speed),
      initiativeBonus: optionalInteger(body.initiativeBonus),
      abilities: optionalJson(body.abilities),
      saves: optionalJson(body.saves),
      skills: optionalJson(body.skills),
      inventory: optionalJson(body.inventory),
      currency: optionalJson(body.currency),
      notes: optionalString(body.notes),
      data: optionalJson(body.data)
    });
  }

  @Post('characters/:id/campaign-bindings')
  bindCharacterToCampaign(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() body: BindCharacterBody
  ): Promise<CharacterCampaignBindingView> {
    if (!isNonEmptyString(body.campaignId)) {
      throw new BadRequestException('Campaign id is required');
    }

    return this.charactersService.bindCharacterToCampaign(user, id, {
      campaignId: body.campaignId,
      visibility: optionalString(body.visibility)
    });
  }

  @Get('campaigns/:id/characters')
  listCampaignCharacters(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string
  ): Promise<CharacterCampaignBindingView[]> {
    return this.charactersService.listCampaignCharacters(user, id);
  }

  @Post('campaigns/:campaignId/characters/:characterId/hp')
  adjustCampaignCharacterHp(
    @CurrentUser() user: AccessTokenPayload,
    @Param('campaignId') campaignId: string,
    @Param('characterId') characterId: string,
    @Body() body: AdjustCharacterHpBody
  ): Promise<CharacterView> {
    const delta = optionalInteger(body.delta);
    const currentHp = optionalInteger(body.currentHp);
    if (delta === undefined && currentHp === undefined) {
      throw new BadRequestException('HP adjustment requires delta or currentHp');
    }

    return this.charactersService.adjustCampaignCharacterHp(
      user,
      campaignId,
      characterId,
      { delta, currentHp }
    );
  }
}

function operationBase(body: Record<string, unknown>) {
  return {
    requestId: requiredString(body.requestId, 'requestId'),
    campaignId:
      body.campaignId === undefined || body.campaignId === null
        ? null
        : requiredString(body.campaignId, 'campaignId'),
    expectedRevision: strictOptionalInteger(
      body.expectedRevision,
      'expectedRevision',
    ),
  };
}

function requiredString(value: unknown, name: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new BadRequestException(`${name} is required`);
  }
  return value.trim();
}

function strictOptionalInteger(
  value: unknown,
  name: string,
): number | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw new BadRequestException(`${name} must be an integer`);
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function optionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function nullableString(value: unknown): string | null | undefined {
  if (value === null) return null;
  return optionalString(value);
}

function optionalInteger(value: unknown): number | undefined {
  return Number.isInteger(value) ? (value as number) : undefined;
}

function optionalJson(value: unknown): unknown | undefined {
  return value === undefined ? undefined : value;
}
