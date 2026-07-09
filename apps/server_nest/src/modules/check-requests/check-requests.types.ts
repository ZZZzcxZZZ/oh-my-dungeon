export interface CreateCheckRequestInput {
  sessionId: string;
  label: string;
  checkType?: string;
  ability?: string;
  skill?: string;
  dc?: number;
  dcVisibility?: string;
  targetMode?: string;
  targetUserIds?: string[];
  targetCharacterIds?: string[];
}

export interface RespondToCheckRequestInput {
  actorName: string;
  modifier?: number;
  characterId?: string;
}

export interface CheckRequestView {
  id: string;
  sessionId: string;
  requestedBy: string;
  label: string;
  checkType: string;
  ability: string | null;
  skill: string | null;
  dc: number | null;
  dcVisibility: string;
  targetMode: string;
  targetUserIds: string[];
  targetCharacterIds: string[];
  status: string;
  createdAt: string;
  updatedAt: string;
  responses: CheckResponseView[];
}

export interface CheckResponseView {
  id: string;
  requestId: string;
  responderId: string;
  characterId: string | null;
  notation: string;
  total: number;
  components: Array<{ notation: string; results: number[] }>;
  result: string;
  createdAt: string;
}
