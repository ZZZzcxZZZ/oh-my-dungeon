ALTER TABLE "CampaignActor"
ADD COLUMN "visibleToPlayers" BOOLEAN NOT NULL DEFAULT false;

UPDATE "CampaignActor"
SET "visibleToPlayers" = true
WHERE "actorType" = 'player';
