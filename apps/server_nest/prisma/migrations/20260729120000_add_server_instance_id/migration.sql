ALTER TABLE "ServerSetting"
ADD COLUMN "instanceId" TEXT;

UPDATE "ServerSetting"
SET "instanceId" = gen_random_uuid()::text
WHERE "instanceId" IS NULL;

ALTER TABLE "ServerSetting"
ALTER COLUMN "instanceId" SET NOT NULL;

CREATE UNIQUE INDEX "ServerSetting_instanceId_key"
ON "ServerSetting"("instanceId");
