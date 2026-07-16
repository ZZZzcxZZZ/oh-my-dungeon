ALTER TABLE "CampaignChatMessage"
ADD COLUMN IF NOT EXISTS "eventData" JSONB;
