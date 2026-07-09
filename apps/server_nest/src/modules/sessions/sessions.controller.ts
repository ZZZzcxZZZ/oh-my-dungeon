import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AccessTokenPayload } from '../auth/auth.types';
import { SessionsService } from './sessions.service';
import type {
  ChatMessageView,
  DiceRollView,
  JournalEntryView,
  SessionView
} from './sessions.types';

interface CreateSessionBody {
  name?: unknown;
}

interface CreateMessageBody {
  content?: unknown;
  kind?: unknown;
  visibility?: unknown;
}

interface CreateRollBody {
  notation?: unknown;
  actorName?: unknown;
  visibility?: unknown;
}

@Controller()
@UseGuards(JwtAuthGuard)
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post('campaigns/:campaignId/sessions')
  createSession(
    @CurrentUser() user: AccessTokenPayload,
    @Param('campaignId') campaignId: string,
    @Body() body: CreateSessionBody
  ): Promise<SessionView> {
    if (!isNonEmptyString(body.name)) {
      throw new BadRequestException('Session name is required');
    }
    return this.sessionsService.createSession(user, campaignId, {
      name: body.name
    });
  }

  @Get('campaigns/:campaignId/sessions')
  listSessions(
    @CurrentUser() user: AccessTokenPayload,
    @Param('campaignId') campaignId: string
  ): Promise<SessionView[]> {
    return this.sessionsService.listSessions(user, campaignId);
  }

  @Get('sessions/:id')
  getSession(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string
  ): Promise<SessionView> {
    return this.sessionsService.getSession(user, id);
  }

  @Post('sessions/:id/start')
  startSession(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string
  ): Promise<SessionView> {
    return this.sessionsService.startSession(user, id);
  }

  @Post('sessions/:id/end')
  endSession(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string
  ): Promise<SessionView> {
    return this.sessionsService.endSession(user, id);
  }

  @Get('sessions/:id/messages')
  listMessages(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string
  ): Promise<ChatMessageView[]> {
    return this.sessionsService.listMessages(user, id);
  }

  @Post('sessions/:id/messages')
  sendMessage(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() body: CreateMessageBody
  ): Promise<ChatMessageView> {
    if (!isNonEmptyString(body.content)) {
      throw new BadRequestException('Message content is required');
    }
    return this.sessionsService.sendMessage(user, id, {
      sessionId: id,
      content: body.content,
      kind: typeof body.kind === 'string' ? body.kind : undefined,
      visibility: typeof body.visibility === 'string' ? body.visibility : undefined
    });
  }

  @Get('sessions/:id/rolls')
  listRolls(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string
  ): Promise<DiceRollView[]> {
    return this.sessionsService.listRolls(user, id);
  }

  @Post('sessions/:id/rolls')
  createRoll(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() body: CreateRollBody
  ): Promise<DiceRollView> {
    if (!isNonEmptyString(body.notation)) {
      throw new BadRequestException('Dice notation is required');
    }
    if (!isNonEmptyString(body.actorName)) {
      throw new BadRequestException('Actor name is required');
    }
    return this.sessionsService.createRoll(user, id, {
      sessionId: id,
      notation: body.notation,
      actorName: body.actorName,
      visibility: typeof body.visibility === 'string' ? body.visibility : undefined
    });
  }

  @Get('sessions/:id/journal')
  listJournal(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Query('type') type?: string,
    @Query('q') q?: string
  ): Promise<JournalEntryView[]> {
    return this.sessionsService.listJournal(user, id, { type, q });
  }
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}
