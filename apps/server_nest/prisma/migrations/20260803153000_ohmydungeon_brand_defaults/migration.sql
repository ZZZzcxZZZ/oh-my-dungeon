-- Rename only known former product defaults. Custom server names remain untouched.
UPDATE "ServerSetting"
SET "serverName" = 'OhMyDungeon'
WHERE "serverName" IN ('D&D Table Tool', 'OpenQuest');

ALTER TABLE "ServerSetting"
ALTER COLUMN "serverName" SET DEFAULT 'OhMyDungeon';
