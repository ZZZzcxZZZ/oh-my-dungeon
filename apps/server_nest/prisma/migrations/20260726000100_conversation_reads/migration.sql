CREATE TABLE "CampaignConversationRead" (
    "id" TEXT NOT NULL,
    "conversationId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "lastReadAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CampaignConversationRead_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "CampaignConversationRead_conversationId_userId_key"
ON "CampaignConversationRead"("conversationId", "userId");

CREATE INDEX "CampaignConversationRead_userId_lastReadAt_idx"
ON "CampaignConversationRead"("userId", "lastReadAt");

ALTER TABLE "CampaignConversationRead"
ADD CONSTRAINT "CampaignConversationRead_conversationId_fkey"
FOREIGN KEY ("conversationId") REFERENCES "CampaignConversation"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CampaignConversationRead"
ADD CONSTRAINT "CampaignConversationRead_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
