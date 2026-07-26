import type { CharacterState } from './domain/character-state';

export interface CharacterView {
  id: string;
  ownerUserId: string;
  name: string;
  avatarUrl: string | null;
  system: string;
  level: number;
  classSummary: string;
  raceSummary: string;
  currentHp: number;
  maxHp: number;
  armorClass: number;
  speed: number;
  initiativeBonus: number;
  abilities: unknown;
  saves: unknown;
  skills: unknown;
  inventory: unknown;
  currency: unknown;
  notes: string;
  data: unknown;
  state: CharacterState;
  createdAt: string;
  updatedAt: string;
}

export interface CreateCharacterInput {
  name: string;
  avatarUrl?: string | null;
  system?: string;
  level?: number;
  classSummary?: string;
  raceSummary?: string;
  currentHp?: number;
  maxHp?: number;
  armorClass?: number;
  speed?: number;
  initiativeBonus?: number;
  abilities?: unknown;
  saves?: unknown;
  skills?: unknown;
  inventory?: unknown;
  currency?: unknown;
  notes?: string;
  data?: unknown;
}

export interface UpdateCharacterInput {
  campaignId?: string;
  name?: string;
  avatarUrl?: string | null;
  system?: string;
  level?: number;
  classSummary?: string;
  raceSummary?: string;
  currentHp?: number;
  maxHp?: number;
  armorClass?: number;
  speed?: number;
  initiativeBonus?: number;
  abilities?: unknown;
  saves?: unknown;
  skills?: unknown;
  inventory?: unknown;
  currency?: unknown;
  notes?: string;
  data?: unknown;
}

export interface BindCharacterInput {
  campaignId: string;
  visibility?: string;
}

export interface AdjustCharacterHpInput {
  delta?: number;
  currentHp?: number;
}

export interface CharacterCampaignBindingView {
  id: string;
  campaignId: string;
  characterId: string;
  userId: string;
  visibility: string;
  status: string;
  dmNotes: string;
  joinedAt: string;
  updatedAt: string;
  character?: CharacterView;
}
