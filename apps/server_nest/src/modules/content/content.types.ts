export type ContentItemType =
  | "spell"
  | "item"
  | "equipment"
  | "species"
  | "class"
  | "background"
  | "feat"
  | "feature"
  | "monster"
  | "condition";

export interface ContentPackageImportItem {
  type: ContentItemType | string;
  slug: string;
  name: string;
  description?: string;
  structured?: unknown;
  tags?: string[];
  sourceLabel?: string;
  schemaVersion?: number;
  references?: Array<{ type: string; slug: string; relation: string; label?: string }>;
}

export interface ContentPackageImport {
  name: string;
  version: string;
  schemaVersion?: number;
  locale?: string;
  items: ContentPackageImportItem[];
}

export interface ContentValidationResult {
  valid: boolean;
  errors: string[];
}

export interface ContentItemView {
  id: string;
  packageId: string;
  type: string;
  slug: string;
  name: string;
  description: string;
  structured: unknown;
  tags: unknown;
  sourceLabel: string;
  schemaVersion: number;
  createdAt: string;
  updatedAt: string;
}

export interface CampaignContentItemDetailView extends ContentItemView {
  isFavorite: boolean;
  outgoingLinks: Array<{
    relation: string;
    label: string;
    target: ContentItemView;
  }>;
}

export interface ContentPackageView {
  id: string;
  scope: string;
  ownerUserId: string | null;
  campaignId: string | null;
  name: string;
  version: string;
  schemaVersion: number;
  locale: string;
  status: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  items?: ContentItemView[];
}

export interface ImportContentPackageResult {
  valid: boolean;
  errors: string[];
  package: ContentPackageView | null;
}

export interface CampaignContentPackageView {
  campaignId: string;
  packageId: string;
  enabled: boolean;
}

export interface ContentOverrideView {
  id?: string;
  campaignId: string;
  baseContentItemId: string;
  overrideType: string;
  reason: string;
  createdBy: string;
  createdAt?: string;
  updatedAt?: string;
}
