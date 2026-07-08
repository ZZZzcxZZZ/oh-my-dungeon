# 领域模型设计

## 1. 核心实体总览

```text
User
ServerSettings
ServerAdmin
Campaign
CampaignMember
CampaignInvite
Session
Character
CharacterCampaignBinding
CharacterSnapshot
ContentPackage
ContentItem
ContentOverride
ChatMessage
DiceRoll
RollRequest
JournalEntry
Encounter
EncounterParticipant
Effect
Npc
```

## 2. 用户与服务器

### User

```text
id
username
email
passwordHash
displayName
avatarUrl
defaultClientMode: player / dm
createdAt
updatedAt
```

### ServerSettings

```text
id
serverName
registrationEnabled
defaultLocale
allowPublicCampaignDiscovery
maxUploadSize
enabledSystems
createdAt
updatedAt
```

### ServerAdmin

```text
id
userId
role: owner / admin
createdAt
```

首版初始化策略：首次注册用户自动成为 ServerAdmin owner。自托管场景下这是最简单可靠的默认行为。

## 3. 战役与成员

### Campaign

```text
id
name
description
system: dnd5e
ownerId
status: active / archived
createdAt
updatedAt
```

### CampaignMember

```text
id
campaignId
userId
role: owner / dm / player / spectator
displayName
joinedAt
updatedAt
```

一个用户可以加入多个战役，并在不同战役中拥有不同角色。真实权限以 CampaignMember 为准。

### CampaignInvite

```text
id
campaignId
code
roleOnJoin: player / spectator
expiresAt
maxUses
usedCount
requireApproval
createdBy
createdAt
```

MVP 可以先实现自动加入。requireApproval 预留给之后的 DM 审批流程。

## 4. 跑团会话

### Session

```text
id
campaignId
title
status: scheduled / live / ended
startedAt
endedAt
createdBy
activeEncounterId
createdAt
updatedAt
```

Campaign 是长期容器，Session 是一次实际开团。一个 Campaign 可以有多个 Session，同一时间通常只有一个 live Session。

## 5. 角色

### Character

```text
id
ownerUserId
name
avatarUrl
system: dnd5e
level
classSummary
raceSummary
currentHp
maxHp
armorClass
data
createdAt
updatedAt
```

`data` 使用 JSONB 保存角色卡详情：

```text
basic
abilities
saves
skills
combat
resources
spells
inventory
features
notes
overrides
```

常用列表字段冗余在表列中，用于快速查询和展示。

### CharacterCampaignBinding

```text
id
campaignId
characterId
userId
visibility: public / party / dm_only
status: active / retired / dead / archived
dmNotes
joinedAt
updatedAt
```

角色归用户所有，通过 binding 加入战役。不要把角色强行建模成只属于单个战役。

### CharacterSnapshot

```text
id
characterId
campaignId
sessionId
reason
data
createdBy
createdAt
```

快照用于误操作恢复、日志回放、战斗记录和关键节点保存。

## 6. 内容库

### ContentPackage

```text
id
scope: system / user / campaign
ownerUserId
campaignId
name
version
schemaVersion
locale
status: active / disabled / archived
createdBy
createdAt
updatedAt
```

### ContentItem

```text
id
packageId
type: spell / item / feat / class / race / background / monster / condition
slug
name
structured
description
tags
sourceLabel
schemaVersion
createdAt
updatedAt
```

`structured` 使用 JSONB，按 type 由 JSON Schema 校验。description 使用富文本或 Markdown 子集。

### ContentOverride

```text
id
campaignId
baseContentItemId
overrideType: disable / patch / derive
derivedContentItemId
patchData
reason
createdBy
createdAt
updatedAt
```

战役内容解析顺序：

1. 读取系统基础库。
2. 合并用户个人库中被战役启用的内容。
3. 合并战役扩展库。
4. 应用 ContentOverride。
5. 输出当前战役可用内容视图。

## 7. 聊天、骰子与检定请求

### ChatMessage

```text
id
campaignId
sessionId
senderUserId
visibility: public / dm_only / private
body
metadata
createdAt
```

### DiceRoll

```text
id
campaignId
sessionId
rollerUserId
characterId
expression
result
breakdown
visibility: public / dm_only / private
reason
createdAt
```

### RollRequest

```text
id
campaignId
sessionId
requestedBy
targetType: all / users / characters
targetIds
abilityOrSkill
dc
dcVisibility: public / dm_only
visibility: public / dm_only
status: open / completed / cancelled
createdAt
updatedAt
```

RollRequest 的响应可以作为 DiceRoll 记录，并在 metadata 中关联 rollRequestId。

## 8. 事件日志

### JournalEntry

```text
id
campaignId
sessionId
type
visibility: public / dm_only / private
actorUserId
targetRef
payload
createdAt
```

JournalEntry 是统一事件流。聊天、掷骰、HP 变化、状态变化、成员加入、回合推进、内容包导入等关键事件都应写入 JournalEntry。

## 9. 遭遇、参与者与效果

### Encounter

```text
id
campaignId
sessionId
name
status: draft / active / completed
round
currentTurnParticipantId
createdBy
createdAt
updatedAt
```

### EncounterParticipant

```text
id
encounterId
participantType: character / npc / monster
characterId
npcId
displayName
initiative
hpCurrent
hpMax
armorClass
isHiddenFromPlayers
sortOrder
snapshot
createdAt
updatedAt
```

参与者保存快照，避免资料库怪物更新影响已经创建的遭遇。

### Effect

```text
id
campaignId
targetType: character / encounter_participant
targetId
sourceType: spell / feature / manual / condition
sourceContentItemId
name
durationType: instant / round / until_short_rest / until_long_rest / manual
expiresAt
remainingRounds
structuredModifiers
description
createdBy
createdAt
updatedAt
```

MVP 中 structuredModifiers 只做基础承载，不强制完整自动计算。后续规则引擎可以逐步读取它。

## 10. NPC

### Npc

```text
id
campaignId
contentItemId
name
publicDescription
dmNotes
stats
tags
createdBy
createdAt
updatedAt
```

NPC 可以从怪物资料库派生，也可以完全由 DM 手写。

