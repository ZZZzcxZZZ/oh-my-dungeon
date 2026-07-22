# 领域模型设计

## 1. 两个数据域

0.1 明确区分个人离线数据和战役协作数据：

- 个人域以客户端 Drift 为事实源：角色、资料包、收藏、笔记、偏好和备份。
- 战役域以服务端 PostgreSQL 为事实源：成员、Actor、聊天、战役资料、档案、日志和遭遇。

本地 `CharacterSheet` 不是服务端 `CampaignActor`。玩家发布角色后形成战役快照，并用 `sourceCharacterId` 和 backlink 建立可冲突的双向同步。

## 2. 用户与服务器

### User / RefreshToken / ServerAdmin

`User` 保存 username、email 和 passwordHash，不保存明文密码。RefreshToken 支持轮换和撤销；首个注册用户原子成为 ServerAdmin owner。

### Vault

`VaultEntity`、`VaultChange`、`VaultOperation` 和 `VaultDevice` 提供按用户隔离的可选跨设备同步。允许同步个人角色、收藏、笔记、偏好和资料包 manifest；资料正文和 assets 禁止进入 Vault。

## 3. 战役身份

### Campaign

```text
id, name, description, system, ownerId, status, createdAt, updatedAt
```

### CampaignMember

```text
campaignId, userId, role
boundActorId, activeSpeakerActorId, speakerMode
displayName, lastReadAt
```

公开邀请码永远加入为 player。客户端全局 DM/Player 模式不改变 membership 权限。

### CampaignInvite

```text
campaignId, code, roleOnJoin, expiresAt, maxUses, usedCount, createdBy
```

## 4. 角色与 Actor

### 本地 CharacterSheet

完整 JSON 保存于 Drift `Characters.sheetJson`，并有单调递增的本地 `revision`。资料引用另存稳定 entryKey、sourceRevision 和 snapshot，资料包缺失时角色仍可使用。

### CampaignActor

```text
campaignId
ownerUserId
sourceCharacterId
actorType: player / npc / monster / companion
lifecycle: persistent / temporary
status: active / archived
sheetJson
revision
updatedBy
```

- 玩家只能发布并编辑自己的 player Actor。
- owner/DM 可创建 NPC 等 Actor，并编辑任意 Actor。
- 消息身份、头像、生命值和角色详情均从 CampaignActor 快照读取。
- `CampaignActorAudit` 保存 baseRevision、resultRevision、变更路径和前后快照。

客户端 `CampaignActorBacklink` 记录最近发布的本地 revision 和最近应用的 Actor revision。双方都偏离基线时生成 `CharacterSyncConflict`，不能静默覆盖。

## 5. 资料

### 本地 ContentPackage / ContentEntry

资料包由客户端导入 JSON 或 `.dndpack`。`ContentEntry` 使用稳定 ID，并保存：

```text
type, slug, name, aliases, summary
body, structured, rules, relations, tags, source, revision
```

rules 和 relations 同时驱动 Wiki、角色创建、升级、角色卡与聊天动作。编辑和复制导入条目仍属于本地包，不进入 Vault。

### CampaignContentEntry

DM 明确发布到战役的独立 JSON 条目。它通过 `CampaignChange` cursor 增量同步到成员缓存，与本地包同名时并存并标注来源。

## 6. 聊天、日志与档案

### CampaignChatMessage

```text
campaignId, senderId, campaignActorId
displayName, avatarUrl, speakerMode, delegatedByUserId
kind: say / action / ooc / roll / system / checkRequest / archivePublished
content, eventData, actionSnapshot, publicHealthState, createdAt
```

显示身份由服务端根据 membership 和 Actor 派生，不信任客户端 displayName。检定请求和响应通过 `eventData.requestId/targetActorId` 关联。

### JournalEntry

关键消息投影为战役日志。消息和日志在同一事务写入，普通说/做/OOC 不重复入日志。

### CampaignArchiveEntry

战役共享 document、location、clue 和 file 条目，支持置顶和软删除；只有战役管理者可写，成员可读。

## 7. 遭遇

`Npc`、`Encounter` 和 `EncounterParticipant` 属于战役 DM 控场。Encounter 直接关联 campaign；可空的 legacy sessionId 暂时保留用于旧数据迁移，不得作为新流程前置条件。

## 8. 增量同步

`CampaignChange` 是 Actor 和战役资料的单调 cursor 日志，WebSocket 只广播 `{campaignId, entityType, cursor}`。客户端按 cursor 拉取完整实体并写入 Drift campaign cache。

## 9. 遗留模型

Prisma 仍含 Session、SessionMember、ChatMessage、DiceRoll、CheckRequest、CheckResponse 和部分旧 Character 绑定模型，以避免预发布数据库升级时直接丢数据。对应 Rooms/Sessions/CheckRequests API 已移除；新代码不得依赖这些表创建产品流程。后续应通过单独迁移归档或删除，而不是重新暴露接口。
