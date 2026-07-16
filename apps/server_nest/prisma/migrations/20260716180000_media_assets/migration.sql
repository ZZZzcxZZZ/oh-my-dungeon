CREATE TABLE "MediaAsset" (
    "id" TEXT NOT NULL,
    "ownerUserId" TEXT NOT NULL,
    "campaignId" TEXT,
    "purpose" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL,
    "storageKey" TEXT NOT NULL,
    "sha256" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MediaAsset_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "MediaAsset_storageKey_key" ON "MediaAsset"("storageKey");
CREATE INDEX "MediaAsset_ownerUserId_createdAt_idx" ON "MediaAsset"("ownerUserId", "createdAt");
CREATE INDEX "MediaAsset_campaignId_createdAt_idx" ON "MediaAsset"("campaignId", "createdAt");
