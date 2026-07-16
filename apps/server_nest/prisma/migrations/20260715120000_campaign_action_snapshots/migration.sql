ALTER TABLE "CampaignChatMessage"
ADD COLUMN IF NOT EXISTS "actionSnapshot" JSONB;
