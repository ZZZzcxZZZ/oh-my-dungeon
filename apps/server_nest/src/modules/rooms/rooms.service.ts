import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { CreateRoomInput, Room } from './room.type';

@Injectable()
export class RoomsService {
  private readonly rooms: Room[] = [];

  listRooms(): Room[] {
    return [...this.rooms];
  }

  createRoom(input: CreateRoomInput): Room {
    const room: Room = {
      id: randomUUID(),
      name: input.name.trim(),
      status: 'open',
      system: 'dnd5e',
      createdAt: new Date().toISOString()
    };

    this.rooms.push(room);
    return room;
  }
}
