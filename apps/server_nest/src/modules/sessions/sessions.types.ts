export interface SessionMemberView {
  id: string;
  sessionId: string;
  userId: string;
  role: string;
  joinedAt: string;
  leftAt: string | null;
}

export interface SessionView {
  id: string;
  campaignId: string;
  name: string;
  status: string;
  startedAt: string | null;
  endedAt: string | null;
  createdAt: string;
  updatedAt: string;
  members?: SessionMemberView[];
  recentMessages?: ChatMessageView[];
}

export interface CreateSessionInput {
  name: string;
}

export interface ChatMessageView {
  id: string;
  sessionId: string;
  senderId: string;
  kind: string;
  visibility: string;
  content: string;
  createdAt: string;
}

export interface CreateChatMessageInput {
  sessionId: string;
  kind?: string;
  visibility?: string;
  content: string;
}

export interface DiceRollComponent {
  notation: string;
  results: number[];
}

export interface DiceRollView {
  id: string;
  sessionId: string;
  actorId: string;
  actorName: string;
  notation: string;
  total: number;
  components: DiceRollComponent[];
  visibility: string;
  createdAt: string;
}

export interface CreateDiceRollInput {
  sessionId: string;
  actorName: string;
  notation: string;
  visibility?: string;
}

export interface JournalEntryView {
  id: string;
  sessionId: string;
  type: string;
  summary: string;
  refId: string | null;
  createdAt: string;
}
