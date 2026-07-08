import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Post
} from '@nestjs/common';
import type { Room } from './room.type';
import { RoomsService } from './rooms.service';

interface CreateRoomBody {
  name?: unknown;
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
}
