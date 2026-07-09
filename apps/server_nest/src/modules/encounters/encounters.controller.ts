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
import { EncountersService } from './encounters.service';
import type {
  EncounterParticipantView,
  EncounterView,
  NpcView
} from './encounters.types';

@Controller()
@UseGuards(JwtAuthGuard)
export class EncountersController {
  constructor(private readonly encountersService: EncountersService) {}

  @Post('campaigns/:id/npcs')
  createNpc(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') campaignId: string,
    @Body() body: Record<string, unknown>
  ): Promise<NpcView> {
    if (!isNonEmptyString(body.name)) {
      throw new BadRequestException('Npc name is required');
    }
    return this.encountersService.createNpc(user, campaignId, {
      name: body.name,
      contentItemId: nullableString(body.contentItemId),
      publicDescription: optionalString(body.publicDescription),
      dmNotes: optionalString(body.dmNotes),
      stats: body.stats,
      tags: body.tags
    });
  }

  @Get('campaigns/:id/npcs')
  listNpcs(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') campaignId: string
  ): Promise<NpcView[]> {
    return this.encountersService.listNpcs(user, campaignId);
  }

  @Post('campaigns/:id/encounters')
  createEncounter(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') campaignId: string,
    @Body() body: Record<string, unknown>
  ): Promise<EncounterView> {
    if (!isNonEmptyString(body.name)) {
      throw new BadRequestException('Encounter name is required');
    }
    return this.encountersService.createEncounter(user, campaignId, {
      name: body.name,
      sessionId: nullableString(body.sessionId)
    });
  }

  @Get('campaigns/:id/encounters')
  listEncounters(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') campaignId: string
  ): Promise<EncounterView[]> {
    return this.encountersService.listEncounters(user, campaignId);
  }

  @Get('encounters/:id')
  getEncounter(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') encounterId: string
  ): Promise<EncounterView> {
    return this.encountersService.getEncounter(user, encounterId);
  }

  @Post('encounters/:id/participants')
  addParticipant(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') encounterId: string,
    @Body() body: Record<string, unknown>
  ): Promise<EncounterParticipantView> {
    if (!isNonEmptyString(body.participantType)) {
      throw new BadRequestException('Participant type is required');
    }
    return this.encountersService.addParticipant(user, encounterId, {
      participantType: body.participantType,
      characterId: optionalString(body.characterId),
      npcId: optionalString(body.npcId),
      displayName: optionalString(body.displayName),
      initiative: optionalInteger(body.initiative),
      hpCurrent: optionalInteger(body.hpCurrent),
      hpMax: optionalInteger(body.hpMax),
      armorClass: optionalInteger(body.armorClass),
      isHiddenFromPlayers: optionalBoolean(body.isHiddenFromPlayers)
    });
  }

  @Patch('encounters/:id/participants/:participantId')
  updateParticipant(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') encounterId: string,
    @Param('participantId') participantId: string,
    @Body() body: Record<string, unknown>
  ): Promise<EncounterParticipantView> {
    return this.encountersService.updateParticipant(
      user,
      encounterId,
      participantId,
      {
        initiative: optionalInteger(body.initiative),
        hpCurrent: optionalInteger(body.hpCurrent),
        hpMax: optionalInteger(body.hpMax),
        armorClass: optionalInteger(body.armorClass),
        conditions: body.conditions,
        isHiddenFromPlayers: optionalBoolean(body.isHiddenFromPlayers)
      }
    );
  }

  @Post('encounters/:id/start')
  startEncounter(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') encounterId: string
  ): Promise<EncounterView> {
    return this.encountersService.startEncounter(user, encounterId);
  }

  @Post('encounters/:id/advance-turn')
  advanceTurn(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') encounterId: string
  ): Promise<EncounterView> {
    return this.encountersService.advanceTurn(user, encounterId);
  }

  @Post('encounters/:id/end')
  endEncounter(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') encounterId: string
  ): Promise<EncounterView> {
    return this.encountersService.endEncounter(user, encounterId);
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

function optionalBoolean(value: unknown): boolean | undefined {
  return typeof value === 'boolean' ? value : undefined;
}
