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
