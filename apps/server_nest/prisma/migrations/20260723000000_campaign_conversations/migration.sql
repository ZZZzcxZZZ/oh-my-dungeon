-- CreateTable
CREATE TABLE "CampaignConversation" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'main',
    "title" TEXT NOT NULL DEFAULT '',
    "mainKey" TEXT,
    "directKey" TEXT,
    "participantIds" TEXT[],
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "archivedAt" TIMESTAMP(3),

    CONSTRAINT "CampaignConversation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "CampaignConversation_campaignId_kind_idx" ON "CampaignConversation"("campaignId", "kind");

-- CreateIndex
CREATE UNIQUE INDEX "CampaignConversation_campaignId_mainKey_key" ON "CampaignConversation"("campaignId", "mainKey");

-- CreateIndex
CREATE UNIQUE INDEX "CampaignConversation_campaignId_directKey_key" ON "CampaignConversation"("campaignId", "directKey");

-- AddForeignKey
ALTER TABLE "CampaignConversation" ADD CONSTRAINT "CampaignConversation_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddColumn
ALTER TABLE "CampaignChatMessage" ADD COLUMN "conversationId" TEXT;

-- CreateIndex
CREATE INDEX "CampaignChatMessage_conversationId_createdAt_idx" ON "CampaignChatMessage"("conversationId", "createdAt");

-- AddForeignKey
ALTER TABLE "CampaignChatMessage" ADD CONSTRAINT "CampaignChatMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "CampaignConversation"("id") ON DELETE SET NULL ON UPDATE CASCADE;
