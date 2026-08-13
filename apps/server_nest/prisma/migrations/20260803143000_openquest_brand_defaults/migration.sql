-- Rename only the former product default. Custom server names remain untouched.
UPDATE "ServerSetting"
SET "serverName" = 'OpenQuest'
WHERE "serverName" = 'D&D Table Tool';

ALTER TABLE "ServerSetting"
ALTER COLUMN "serverName" SET DEFAULT 'OpenQuest';
