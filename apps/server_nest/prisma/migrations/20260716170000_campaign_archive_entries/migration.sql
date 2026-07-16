CREATE TABLE IF NOT EXISTS "CampaignArchiveEntry" (
  "id" TEXT NOT NULL,
  "campaignId" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "summary" TEXT NOT NULL DEFAULT '',
  "payload" JSONB NOT NULL DEFAULT '{}',
  "visibility" TEXT NOT NULL DEFAULT 'members',
  "pinned" BOOLEAN NOT NULL DEFAULT FALSE,
  "createdBy" TEXT NOT NULL,
  "updatedBy" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "deletedAt" TIMESTAMP(3),
  CONSTRAINT "CampaignArchiveEntry_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "CampaignArchiveEntry_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "CampaignArchiveEntry_campaignId_kind_deletedAt_idx"
ON "CampaignArchiveEntry"("campaignId", "kind", "deletedAt");
CREATE INDEX IF NOT EXISTS "CampaignArchiveEntry_campaignId_pinned_updatedAt_idx"
ON "CampaignArchiveEntry"("campaignId", "pinned", "updatedAt");
