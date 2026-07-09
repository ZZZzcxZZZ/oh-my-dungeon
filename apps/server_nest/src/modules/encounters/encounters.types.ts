export interface NpcView {
  id: string;
  campaignId: string;
  contentItemId: string | null;
  name: string;
  publicDescription: string;
  dmNotes: string;
  stats: unknown;
  tags: unknown;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface EncounterParticipantView {
  id: string;
  encounterId: string;
  participantType: string;
  characterId: string | null;
  npcId: string | null;
  displayName: string;
  initiative: number;
  hpCurrent: number;
  hpMax: number;
  armorClass: number;
  conditions: unknown;
  isHiddenFromPlayers: boolean;
  sortOrder: number;
  snapshot: unknown;
  createdAt: string;
  updatedAt: string;
}

export interface EncounterView {
  id: string;
  campaignId: string;
  sessionId: string | null;
  name: string;
  status: string;
  round: number;
  currentTurnParticipantId: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  participants?: EncounterParticipantView[];
}
