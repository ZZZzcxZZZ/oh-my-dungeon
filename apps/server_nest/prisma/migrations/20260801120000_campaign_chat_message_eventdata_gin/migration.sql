-- 幂等重放按 eventData->>'requestId' 查询 (campaign-events.service findReplay),
-- 补 GIN 索引避免全表扫描.
CREATE INDEX "CampaignChatMessage_eventData_idx" ON "CampaignChatMessage" USING GIN ("eventData");
