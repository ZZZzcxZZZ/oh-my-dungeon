DROP INDEX IF EXISTS "CampaignActor_campaignId_sourceCharacterId_key";

CREATE UNIQUE INDEX "CampaignActor_campaignId_ownerUserId_sourceCharacterId_key"
ON "CampaignActor"("campaignId", "ownerUserId", "sourceCharacterId");
