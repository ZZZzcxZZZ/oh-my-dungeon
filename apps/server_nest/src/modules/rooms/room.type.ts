export type RoomStatus = 'open' | 'closed';

export interface Room {
  id: string;
  name: string;
  status: RoomStatus;
  system: 'dnd5e';
  createdAt: string;
}

export interface CreateRoomInput {
  name: string;
}

export type RoomActorMode = 'dm' | 'player';

export interface RoomRoll {
  id: string;
  roomId: string;
  notation: string;
  total: number;
  actorName: string;
  actorMode: RoomActorMode;
  createdAt: string;
}

export interface CreateRoomRollInput {
  roomId: string;
  notation: string;
  total: number;
  actorName: string;
  actorMode: RoomActorMode;
}
