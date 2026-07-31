export interface AppendGameEventInput {
  type: string;
  campaignId?: string | null;
  characterId?: string | null;
  initiatorType: string;
  initiatorId: string;
  requestId: string;
  targets: unknown[];
  cause?: Record<string, unknown> | null;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  payload: Record<string, unknown>;
}

export interface GameEventQuery {
  cursor?: string;
  type?: string;
  since?: Date;
  limit?: number;
}
