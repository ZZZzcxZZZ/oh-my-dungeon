import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { CreateRoomInput, CreateRoomRollInput, Room, RoomRoll } from './room.type';

@Injectable()
export class RoomsService {
  private readonly rooms: Room[] = [];
  private readonly rolls: RoomRoll[] = [];

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

  hasRoom(roomId: string): boolean {
    return this.rooms.some((room) => room.id === roomId);
  }

  listRolls(roomId: string): RoomRoll[] {
    return this.rolls.filter((roll) => roll.roomId === roomId);
  }

  createRoll(input: CreateRoomRollInput): RoomRoll {
    const roll: RoomRoll = {
      id: randomUUID(),
      roomId: input.roomId,
      notation: input.notation.trim(),
      total: input.total,
      actorName: input.actorName.trim(),
      actorMode: input.actorMode,
      createdAt: new Date().toISOString()
    };

    this.rolls.push(roll);
    return roll;
  }
}
