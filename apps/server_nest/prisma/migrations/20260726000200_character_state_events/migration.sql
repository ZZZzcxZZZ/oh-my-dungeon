CREATE TABLE "CharacterState" (
    "id" TEXT NOT NULL,
    "characterId" TEXT NOT NULL,
    "campaignId" TEXT,
    "scopeKey" TEXT NOT NULL,
    "stateJson" JSONB NOT NULL,
    "revision" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CharacterState_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "GameEvent" (
    "id" TEXT NOT NULL,
    "schemaVersion" INTEGER NOT NULL DEFAULT 1,
    "type" TEXT NOT NULL,
    "campaignId" TEXT,
    "characterId" TEXT,
    "actorType" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "requestId" TEXT NOT NULL,
    "targets" JSONB NOT NULL DEFAULT '[]',
    "cause" JSONB,
    "before" JSONB NOT NULL DEFAULT '{}',
    "after" JSONB NOT NULL DEFAULT '{}',
    "payload" JSONB NOT NULL DEFAULT '{}',
    "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "GameEvent_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "CharacterState_characterId_scopeKey_key"
ON "CharacterState"("characterId", "scopeKey");
CREATE INDEX "CharacterState_campaignId_idx" ON "CharacterState"("campaignId");
CREATE UNIQUE INDEX "GameEvent_requestId_key" ON "GameEvent"("requestId");
CREATE INDEX "GameEvent_campaignId_occurredAt_idx" ON "GameEvent"("campaignId", "occurredAt");
CREATE INDEX "GameEvent_characterId_occurredAt_idx" ON "GameEvent"("characterId", "occurredAt");
CREATE INDEX "GameEvent_type_occurredAt_idx" ON "GameEvent"("type", "occurredAt");

ALTER TABLE "CharacterState" ADD CONSTRAINT "CharacterState_characterId_fkey"
FOREIGN KEY ("characterId") REFERENCES "Character"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "CharacterState" ADD CONSTRAINT "CharacterState_campaignId_fkey"
FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "GameEvent" ADD CONSTRAINT "GameEvent_campaignId_fkey"
FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "GameEvent" ADD CONSTRAINT "GameEvent_characterId_fkey"
FOREIGN KEY ("characterId") REFERENCES "Character"("id") ON DELETE CASCADE ON UPDATE CASCADE;
