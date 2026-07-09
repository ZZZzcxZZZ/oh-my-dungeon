import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AccessTokenPayload } from '../auth/auth.types';
import { CharactersService } from './characters.service';
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
  constructor(private readonly charactersService: CharactersService) {}

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
    @Param('id') id: string
  ): Promise<CharacterView> {
    return this.charactersService.getCharacter(user, id);
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
