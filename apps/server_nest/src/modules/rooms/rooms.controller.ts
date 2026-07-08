import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  NotFoundException,
  Param,
  Post
} from '@nestjs/common';
import type { Room, RoomActorMode, RoomRoll } from './room.type';
import { RoomsService } from './rooms.service';

interface CreateRoomBody {
  name?: unknown;
}

interface CreateRoomRollBody {
  notation?: unknown;
  total?: unknown;
  actorName?: unknown;
}

@Controller('rooms')
export class RoomsController {
  constructor(private readonly roomsService: RoomsService) {}

  @Get()
  listRooms(): Room[] {
    return this.roomsService.listRooms();
  }

  @Post()
  createRoom(
    @Headers('x-client-mode') clientMode: string | undefined,
    @Body() body: CreateRoomBody
  ): Room {
    if (clientMode !== 'dm') {
      throw new ForbiddenException('Only DM mode can create rooms');
    }

    if (typeof body.name !== 'string' || body.name.trim().length === 0) {
      throw new BadRequestException('Room name is required');
    }

    return this.roomsService.createRoom({ name: body.name });
  }

  @Get(':roomId/rolls')
  listRoomRolls(@Param('roomId') roomId: string): RoomRoll[] {
    if (!this.roomsService.hasRoom(roomId)) {
      throw new NotFoundException('Room not found');
    }

    return this.roomsService.listRolls(roomId);
  }

  @Post(':roomId/rolls')
  createRoomRoll(
    @Param('roomId') roomId: string,
    @Headers('x-client-mode') clientMode: string | undefined,
    @Body() body: CreateRoomRollBody
  ): RoomRoll {
    if (!this.roomsService.hasRoom(roomId)) {
      throw new NotFoundException('Room not found');
    }

    if (
      typeof body.notation !== 'string' ||
      body.notation.trim().length === 0 ||
      typeof body.total !== 'number' ||
      !Number.isFinite(body.total)
    ) {
      throw new BadRequestException('Dice roll notation and total are required');
    }

    return this.roomsService.createRoll({
      roomId,
      notation: body.notation,
      total: body.total,
      actorName: typeof body.actorName === 'string' ? body.actorName : '',
      actorMode: toActorMode(clientMode)
    });
  }
}

function toActorMode(clientMode: string | undefined): RoomActorMode {
  return clientMode === 'dm' ? 'dm' : 'player';
}
