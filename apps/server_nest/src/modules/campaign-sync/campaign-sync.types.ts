export type CampaignEntityType = "actor" | "content";

export type CampaignChangeOperation = "upsert" | "delete";

export interface CampaignChangeRecord {
  id: string;
  campaignId: string;
  cursor: string;
  entityType: CampaignEntityType;
  entityId: string;
  operation: CampaignChangeOperation;
  revision: number;
  createdAt: string;
}

export interface CampaignChangePage {
  items: CampaignChangeRecord[];
  nextCursor: string;
  hasMore: boolean;
}

export interface CampaignActorSummary {
  id: string;
  campaignId: string;
  ownerUserId: string | null;
  sourceCharacterId: string | null;
  actorType: string;
  status: string;
  sheet: Record<string, unknown>;
  revision: number;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface CampaignActorAuditRecord {
  id: string;
  campaignActorId: string;
  campaignId: string;
  actorUserId: string;
  baseRevision: number;
  resultRevision: number;
  changedPaths: string[];
  beforeSheet: Record<string, unknown>;
  afterSheet: Record<string, unknown>;
  createdAt: string;
}

export interface CampaignContentEntrySummary {
  id: string;
  campaignId: string;
  type: string;
  slug: string;
  name: string;
  entry: Record<string, unknown>;
  revision: number;
  createdBy: string;
  updatedBy: string;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface CampaignChangedEvent {
  campaignId: string;
  cursor: string;
  entityType: CampaignEntityType;
}
