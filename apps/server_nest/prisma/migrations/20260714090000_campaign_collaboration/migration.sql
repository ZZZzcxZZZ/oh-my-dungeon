-- Migration: campaign_collaboration
-- Removes the deprecated server-side content package system and migrates
-- campaign-scoped content into CampaignContentEntry rows. Personal data
-- (Vault entities, local packages, local characters) is unaffected — those
-- live on the client and sync through the Vault.

-- 1. Migrate campaign-scoped ContentPackage + ContentItem into CampaignContentEntry.
--    Only packages with scope = 'campaign' are converted; user/global packages
--    are dropped because the server no longer hosts personal compendium content.
INSERT INTO "CampaignContentEntry" (
  "id", "campaignId", "type", "slug", "name", "entryJson", "revision",
  "createdBy", "updatedBy", "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid(),
  pkg."campaignId",
  item."type",
  item."slug",
  item."name",
  jsonb_build_object(
    'description', item."description",
    'structured', item."structured",
    'tags', item."tags",
    'sourceLabel', item."sourceLabel"
  ),
  1,
  pkg."createdBy",
  pkg."createdBy",
  NOW(),
  NOW()
FROM "ContentPackage" pkg
JOIN "ContentItem" item ON item."packageId" = pkg."id"
WHERE pkg."scope" = 'campaign'
  AND pkg."campaignId" IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM "CampaignContentEntry" e
    WHERE e."campaignId" = pkg."campaignId"
      AND e."slug" = item."slug"
  );

-- 2. Ensure each campaign that received migrated entries has a CampaignSyncState
--    so the change cursor can be pulled from 0.
INSERT INTO "CampaignSyncState" ("campaignId", "cursor", "updatedAt")
SELECT DISTINCT e."campaignId", 0, NOW()
FROM "CampaignContentEntry" e
WHERE NOT EXISTS (
  SELECT 1 FROM "CampaignSyncState" s WHERE s."campaignId" = e."campaignId"
);

-- 3. Record an initial 'create' change for each migrated entry so clients
--    pulling from cursor 0 receive them.
INSERT INTO "CampaignChange" (
  "id", "campaignId", "cursor", "entityType", "entityId", "operation",
  "revision", "createdAt"
)
SELECT
  gen_random_uuid(),
  e."campaignId",
  COALESCE(
    (SELECT MAX(c2."cursor") FROM "CampaignChange" c2 WHERE c2."campaignId" = e."campaignId"),
    0
  ) + ROW_NUMBER() OVER (PARTITION BY e."campaignId" ORDER BY e."createdAt"),
  'content',
  e."id",
  'create',
  1,
  NOW()
FROM "CampaignContentEntry" e;

-- 4. Drop old content tables. Personal compendium data now lives exclusively
--    on the client; the server only hosts campaign-scoped standalone entries.
DROP TABLE IF EXISTS "ContentOverride";
DROP TABLE IF EXISTS "CampaignContentPackage";
DROP TABLE IF EXISTS "UserContentFavorite";
DROP TABLE IF EXISTS "ContentItemLink";
DROP TABLE IF EXISTS "ContentItem";
DROP TABLE IF EXISTS "ContentPackage";

-- 5. Keep CharacterCampaignBinding for now — it's still used by the legacy
--    characters endpoints. The new CampaignActor model is the preferred path,
--    and a future migration will retire the binding table once the characters
--    module is refactored.
