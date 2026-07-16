-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "ServerSetting" (
    "id" TEXT NOT NULL,
    "serverName" TEXT NOT NULL DEFAULT 'D&D Table Tool',
    "registrationEnabled" BOOLEAN NOT NULL DEFAULT true,
    "defaultLocale" TEXT NOT NULL DEFAULT 'zh-CN',
    "allowPublicCampaignDiscovery" BOOLEAN NOT NULL DEFAULT false,
    "maxUploadSizeMb" INTEGER NOT NULL DEFAULT 20,
    "enabledSystems" JSONB NOT NULL DEFAULT '["dnd5e"]',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ServerSetting_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "username" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "displayName" TEXT,
    "avatarUrl" TEXT,
    "defaultClientMode" TEXT NOT NULL DEFAULT 'player',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VaultEntity" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "revision" INTEGER NOT NULL DEFAULT 1,
    "deletedAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VaultEntity_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VaultChange" (
    "cursor" BIGSERIAL NOT NULL,
    "userId" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "operation" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "revision" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VaultChange_pkey" PRIMARY KEY ("cursor")
);

-- CreateTable
CREATE TABLE "VaultOperation" (
    "operationId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VaultOperation_pkey" PRIMARY KEY ("userId","operationId")
);

-- CreateTable
CREATE TABLE "VaultDevice" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "lastCursor" BIGINT NOT NULL DEFAULT 0,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "VaultDevice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ServerAdmin" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'admin',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ServerAdmin_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Campaign" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "system" TEXT NOT NULL DEFAULT 'dnd5e',
    "ownerId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Campaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CampaignSyncState" (
    "campaignId" TEXT NOT NULL,
    "cursor" BIGINT NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CampaignSyncState_pkey" PRIMARY KEY ("campaignId")
);

-- CreateTable
CREATE TABLE "CampaignActor" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "ownerUserId" TEXT,
    "sourceCharacterId" TEXT,
    "actorType" TEXT NOT NULL DEFAULT 'player',
    "status" TEXT NOT NULL DEFAULT 'active',
    "sheetJson" JSONB NOT NULL,
    "revision" INTEGER NOT NULL DEFAULT 1,
    "updatedBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CampaignActor_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CampaignActorAudit" (
    "id" TEXT NOT NULL,
    "campaignActorId" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "actorUserId" TEXT NOT NULL,
    "baseRevision" INTEGER NOT NULL,
    "resultRevision" INTEGER NOT NULL,
    "changedPaths" JSONB NOT NULL,
    "beforeJson" JSONB NOT NULL,
    "afterJson" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CampaignActorAudit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CampaignContentEntry" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "entryJson" JSONB NOT NULL,
    "revision" INTEGER NOT NULL DEFAULT 1,
    "createdBy" TEXT NOT NULL,
    "updatedBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "CampaignContentEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CampaignChange" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "cursor" BIGINT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "operation" TEXT NOT NULL,
    "revision" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CampaignChange_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CampaignChatMessage" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "campaignActorId" TEXT,
    "displayName" TEXT NOT NULL DEFAULT '',
    "avatarUrl" TEXT,
    "kind" TEXT NOT NULL DEFAULT 'say',
    "content" TEXT NOT NULL,
    "actionSnapshot" JSONB,
    "eventData" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CampaignChatMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CampaignMember" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'player',
    "displayName" TEXT NOT NULL DEFAULT '',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CampaignMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CampaignInvite" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "roleOnJoin" TEXT NOT NULL DEFAULT 'player',
    "expiresAt" TIMESTAMP(3),
    "maxUses" INTEGER NOT NULL DEFAULT 1,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "requireApproval" BOOLEAN NOT NULL DEFAULT false,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CampaignInvite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'scheduled',
    "startedAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SessionMember" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'player',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leftAt" TIMESTAMP(3),

    CONSTRAINT "SessionMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChatMessage" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'text',
    "visibility" TEXT NOT NULL DEFAULT 'public',
    "content" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DiceRoll" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "actorName" TEXT NOT NULL,
    "notation" TEXT NOT NULL,
    "total" INTEGER NOT NULL,
    "components" JSONB NOT NULL,
    "visibility" TEXT NOT NULL DEFAULT 'public',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DiceRoll_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "JournalEntry" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT,
    "sessionId" TEXT,
    "type" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "refId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "JournalEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Character" (
    "id" TEXT NOT NULL,
    "ownerUserId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "avatarUrl" TEXT,
    "system" TEXT NOT NULL DEFAULT 'dnd5e',
    "level" INTEGER NOT NULL DEFAULT 1,
    "classSummary" TEXT NOT NULL DEFAULT '',
    "raceSummary" TEXT NOT NULL DEFAULT '',
    "currentHp" INTEGER NOT NULL DEFAULT 0,
    "maxHp" INTEGER NOT NULL DEFAULT 0,
    "armorClass" INTEGER NOT NULL DEFAULT 10,
    "speed" INTEGER NOT NULL DEFAULT 30,
    "initiativeBonus" INTEGER NOT NULL DEFAULT 0,
    "abilities" JSONB NOT NULL DEFAULT '{"str":10,"dex":10,"con":10,"int":10,"wis":10,"cha":10}',
    "saves" JSONB NOT NULL DEFAULT '{}',
    "skills" JSONB NOT NULL DEFAULT '{}',
    "inventory" JSONB NOT NULL DEFAULT '[]',
    "currency" JSONB NOT NULL DEFAULT '{}',
    "notes" TEXT NOT NULL DEFAULT '',
    "data" JSONB NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Character_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CheckRequest" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "requestedBy" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "checkType" TEXT NOT NULL DEFAULT 'skill',
    "ability" TEXT,
    "skill" TEXT,
    "dc" INTEGER,
    "dcVisibility" TEXT NOT NULL DEFAULT 'public',
    "targetMode" TEXT NOT NULL DEFAULT 'all',
    "targetUserIds" JSONB NOT NULL DEFAULT '[]',
    "targetCharacterIds" JSONB NOT NULL DEFAULT '[]',
    "status" TEXT NOT NULL DEFAULT 'open',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CheckRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CheckResponse" (
    "id" TEXT NOT NULL,
    "requestId" TEXT NOT NULL,
    "responderId" TEXT NOT NULL,
    "characterId" TEXT,
    "notation" TEXT NOT NULL,
    "total" INTEGER NOT NULL,
    "components" JSONB NOT NULL,
    "result" TEXT NOT NULL DEFAULT 'unknown',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CheckResponse_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Npc" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "contentItemId" TEXT,
    "name" TEXT NOT NULL,
    "publicDescription" TEXT NOT NULL DEFAULT '',
    "dmNotes" TEXT NOT NULL DEFAULT '',
    "stats" JSONB NOT NULL DEFAULT '{}',
    "tags" JSONB NOT NULL DEFAULT '[]',
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Npc_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Encounter" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "sessionId" TEXT,
    "name" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'draft',
    "round" INTEGER NOT NULL DEFAULT 0,
    "currentTurnParticipantId" TEXT,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Encounter_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EncounterParticipant" (
    "id" TEXT NOT NULL,
    "encounterId" TEXT NOT NULL,
    "participantType" TEXT NOT NULL,
    "characterId" TEXT,
    "npcId" TEXT,
    "displayName" TEXT NOT NULL,
    "initiative" INTEGER NOT NULL DEFAULT 0,
    "hpCurrent" INTEGER NOT NULL DEFAULT 0,
    "hpMax" INTEGER NOT NULL DEFAULT 0,
    "armorClass" INTEGER NOT NULL DEFAULT 10,
    "conditions" JSONB NOT NULL DEFAULT '[]',
    "isHiddenFromPlayers" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "snapshot" JSONB NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EncounterParticipant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CharacterCampaignBinding" (
    "id" TEXT NOT NULL,
    "campaignId" TEXT NOT NULL,
    "characterId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "visibility" TEXT NOT NULL DEFAULT 'party',
    "status" TEXT NOT NULL DEFAULT 'active',
    "dmNotes" TEXT NOT NULL DEFAULT '',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CharacterCampaignBinding_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_username_key" ON "User"("username");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "VaultEntity_userId_updatedAt_idx" ON "VaultEntity"("userId", "updatedAt");

-- CreateIndex
CREATE UNIQUE INDEX "VaultEntity_userId_entityType_entityId_key" ON "VaultEntity"("userId", "entityType", "entityId");

-- CreateIndex
CREATE INDEX "VaultChange_userId_cursor_idx" ON "VaultChange"("userId", "cursor");

-- CreateIndex
CREATE INDEX "VaultOperation_userId_idx" ON "VaultOperation"("userId");

-- CreateIndex
CREATE INDEX "VaultDevice_userId_lastSeenAt_idx" ON "VaultDevice"("userId", "lastSeenAt");

-- CreateIndex
CREATE UNIQUE INDEX "VaultDevice_userId_deviceId_key" ON "VaultDevice"("userId", "deviceId");

-- CreateIndex
CREATE UNIQUE INDEX "ServerAdmin_userId_key" ON "ServerAdmin"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");

-- CreateIndex
CREATE INDEX "CampaignActor_campaignId_status_idx" ON "CampaignActor"("campaignId", "status");

-- CreateIndex
CREATE INDEX "CampaignActor_ownerUserId_idx" ON "CampaignActor"("ownerUserId");

-- CreateIndex
CREATE UNIQUE INDEX "CampaignActor_campaignId_sourceCharacterId_key" ON "CampaignActor"("campaignId", "sourceCharacterId");

-- CreateIndex
CREATE INDEX "CampaignActorAudit_campaignId_createdAt_idx" ON "CampaignActorAudit"("campaignId", "createdAt");

-- CreateIndex
CREATE INDEX "CampaignContentEntry_campaignId_type_deletedAt_idx" ON "CampaignContentEntry"("campaignId", "type", "deletedAt");

-- CreateIndex
CREATE UNIQUE INDEX "CampaignContentEntry_campaignId_slug_key" ON "CampaignContentEntry"("campaignId", "slug");

-- CreateIndex
CREATE INDEX "CampaignChange_campaignId_cursor_idx" ON "CampaignChange"("campaignId", "cursor");

-- CreateIndex
CREATE UNIQUE INDEX "CampaignChange_campaignId_cursor_key" ON "CampaignChange"("campaignId", "cursor");

-- CreateIndex
CREATE INDEX "CampaignChatMessage_campaignId_createdAt_idx" ON "CampaignChatMessage"("campaignId", "createdAt");

-- CreateIndex
CREATE INDEX "CampaignChatMessage_senderId_idx" ON "CampaignChatMessage"("senderId");

-- CreateIndex
CREATE INDEX "CampaignChatMessage_campaignActorId_idx" ON "CampaignChatMessage"("campaignActorId");

-- CreateIndex
CREATE UNIQUE INDEX "CampaignMember_campaignId_userId_key" ON "CampaignMember"("campaignId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "CampaignInvite_code_key" ON "CampaignInvite"("code");

-- CreateIndex
CREATE UNIQUE INDEX "SessionMember_sessionId_userId_key" ON "SessionMember"("sessionId", "userId");

-- CreateIndex
CREATE INDEX "CheckRequest_sessionId_idx" ON "CheckRequest"("sessionId");

-- CreateIndex
CREATE INDEX "CheckRequest_requestedBy_idx" ON "CheckRequest"("requestedBy");

-- CreateIndex
CREATE INDEX "CheckResponse_requestId_idx" ON "CheckResponse"("requestId");

-- CreateIndex
CREATE INDEX "CheckResponse_responderId_idx" ON "CheckResponse"("responderId");

-- CreateIndex
CREATE INDEX "CheckResponse_characterId_idx" ON "CheckResponse"("characterId");

-- CreateIndex
CREATE UNIQUE INDEX "CheckResponse_requestId_responderId_key" ON "CheckResponse"("requestId", "responderId");

-- CreateIndex
CREATE INDEX "Npc_campaignId_idx" ON "Npc"("campaignId");

-- CreateIndex
CREATE INDEX "Encounter_campaignId_idx" ON "Encounter"("campaignId");

-- CreateIndex
CREATE INDEX "Encounter_sessionId_idx" ON "Encounter"("sessionId");

-- CreateIndex
CREATE INDEX "EncounterParticipant_encounterId_idx" ON "EncounterParticipant"("encounterId");

-- CreateIndex
CREATE INDEX "EncounterParticipant_characterId_idx" ON "EncounterParticipant"("characterId");

-- CreateIndex
CREATE INDEX "EncounterParticipant_npcId_idx" ON "EncounterParticipant"("npcId");

-- CreateIndex
CREATE UNIQUE INDEX "CharacterCampaignBinding_campaignId_characterId_key" ON "CharacterCampaignBinding"("campaignId", "characterId");

-- AddForeignKey
ALTER TABLE "VaultEntity" ADD CONSTRAINT "VaultEntity_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VaultDevice" ADD CONSTRAINT "VaultDevice_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ServerAdmin" ADD CONSTRAINT "ServerAdmin_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Campaign" ADD CONSTRAINT "Campaign_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignSyncState" ADD CONSTRAINT "CampaignSyncState_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignActor" ADD CONSTRAINT "CampaignActor_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignActorAudit" ADD CONSTRAINT "CampaignActorAudit_campaignActorId_fkey" FOREIGN KEY ("campaignActorId") REFERENCES "CampaignActor"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignContentEntry" ADD CONSTRAINT "CampaignContentEntry_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignChange" ADD CONSTRAINT "CampaignChange_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignChatMessage" ADD CONSTRAINT "CampaignChatMessage_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignChatMessage" ADD CONSTRAINT "CampaignChatMessage_campaignActorId_fkey" FOREIGN KEY ("campaignActorId") REFERENCES "CampaignActor"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignMember" ADD CONSTRAINT "CampaignMember_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignMember" ADD CONSTRAINT "CampaignMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CampaignInvite" ADD CONSTRAINT "CampaignInvite_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SessionMember" ADD CONSTRAINT "SessionMember_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DiceRoll" ADD CONSTRAINT "DiceRoll_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JournalEntry" ADD CONSTRAINT "JournalEntry_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JournalEntry" ADD CONSTRAINT "JournalEntry_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Character" ADD CONSTRAINT "Character_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CheckRequest" ADD CONSTRAINT "CheckRequest_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CheckRequest" ADD CONSTRAINT "CheckRequest_requestedBy_fkey" FOREIGN KEY ("requestedBy") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CheckResponse" ADD CONSTRAINT "CheckResponse_requestId_fkey" FOREIGN KEY ("requestId") REFERENCES "CheckRequest"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CheckResponse" ADD CONSTRAINT "CheckResponse_responderId_fkey" FOREIGN KEY ("responderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CheckResponse" ADD CONSTRAINT "CheckResponse_characterId_fkey" FOREIGN KEY ("characterId") REFERENCES "Character"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Npc" ADD CONSTRAINT "Npc_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Encounter" ADD CONSTRAINT "Encounter_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Encounter" ADD CONSTRAINT "Encounter_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EncounterParticipant" ADD CONSTRAINT "EncounterParticipant_encounterId_fkey" FOREIGN KEY ("encounterId") REFERENCES "Encounter"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EncounterParticipant" ADD CONSTRAINT "EncounterParticipant_characterId_fkey" FOREIGN KEY ("characterId") REFERENCES "Character"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EncounterParticipant" ADD CONSTRAINT "EncounterParticipant_npcId_fkey" FOREIGN KEY ("npcId") REFERENCES "Npc"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CharacterCampaignBinding" ADD CONSTRAINT "CharacterCampaignBinding_campaignId_fkey" FOREIGN KEY ("campaignId") REFERENCES "Campaign"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CharacterCampaignBinding" ADD CONSTRAINT "CharacterCampaignBinding_characterId_fkey" FOREIGN KEY ("characterId") REFERENCES "Character"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CharacterCampaignBinding" ADD CONSTRAINT "CharacterCampaignBinding_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
