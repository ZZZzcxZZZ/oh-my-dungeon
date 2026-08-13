# API 与实时事件边界

## 1. 当前原则

- 客户端除战役协作和可选 Personal Vault 外均可离线使用。
- REST 是服务端状态的事实源；WebSocket 只通知消息或游标变化。
- 所有写操作由服务端根据 Campaign membership 和 Character ownership 校验。
- `Session`、`Rooms` 和独立 `CheckRequests` HTTP 模块已退出 0.1 产品路径，不得重新挂载。
- 未来 AI Agent 与 Flutter UI 必须复用同一业务接口；不得给 Agent 提供绕过权限、revision 或事件审计的数据库直写工具。

Agent 使用的数据结构、工具名称、幂等、错误与审批规范见
[AI Agent 数据与工具接口规范](ai-agent-data-and-tool-contract.md)。

## 2. 当前 REST 边界

### Server 与认证

```text
GET   /health
GET   /.well-known/dnd-tool-server
GET   /api/server-settings
PATCH /api/server-settings
POST  /api/auth/register
POST  /api/auth/login
POST  /api/auth/refresh
POST  /api/auth/logout
GET   /api/auth/me
```

### 战役工作区

```text
GET  /api/campaigns
POST /api/campaigns
GET  /api/campaigns/:id
GET  /api/campaigns/:id/context
GET  /api/campaigns/:id/messages
POST /api/campaigns/:id/messages
GET  /api/campaigns/:id/check-requests
PUT  /api/campaigns/:id/members/:userId/binding
PUT  /api/campaigns/:id/speaker
POST /api/campaigns/:id/read
POST /api/campaigns/:id/invites
GET  /api/campaigns/:id/invites
POST /api/campaigns/join
```

私聊与小群（同一战役内）：

```text
GET    /api/campaigns/:campaignId/conversations
POST   /api/campaigns/:campaignId/conversations/direct
POST   /api/campaigns/:campaignId/conversations/group
PATCH  /api/campaigns/:campaignId/conversations/:conversationId
POST   /api/campaigns/:campaignId/conversations/:conversationId/read
```

检定、响应和系统事件是带结构化 `eventData` 的战役消息。`check-requests` 只提供战役消息历史聚合，不是独立 Session 资源。

### Character、战役资料与增量同步

```text
POST /api/campaigns/:campaignId/characters/publish
POST /api/campaigns/:campaignId/characters
GET  /api/campaigns/:campaignId/characters
GET  /api/campaigns/:campaignId/characters/:characterId
PUT  /api/campaigns/:campaignId/characters/:characterId
POST /api/campaigns/:campaignId/characters/:characterId/runtime-commands
POST /api/campaigns/:campaignId/characters/:characterId/assign
POST /api/campaigns/:campaignId/characters/:characterId/archive
POST /api/campaigns/:campaignId/characters/:characterId/restore
GET  /api/campaigns/:campaignId/characters/:characterId/audits

POST   /api/campaigns/:campaignId/content/entries/validate
POST   /api/campaigns/:campaignId/content/entries
GET    /api/campaigns/:campaignId/content/entries
PUT    /api/campaigns/:campaignId/content/entries/:entryId
DELETE /api/campaigns/:campaignId/content/entries/:entryId
GET    /api/campaigns/:campaignId/changes
```

战役角色状态修改（战役快照是 0.1 角色运行状态的单一事实源）：

```text
POST /api/campaigns/:campaignId/characters/:characterId/hp
POST /api/campaigns/:campaignId/characters/:characterId/items
POST /api/campaigns/:campaignId/characters/:characterId/conditions
```

三者与下述 `/api/characters/:characterId/actions/*` 语义一致：必须携带唯一
`requestId`（相同 requestId 重试返回首次结果，不重复执行；跨操作复用报
400），可携带 `baseRevision`（不匹配返回 409）。同事务写入角色、审计、
变更游标与事件消息，事务提交后才广播。

本地资料包正文不上传。这里只同步 DM 明确发布到战役的独立 JSON 条目。

### 战役档案

```text
GET    /api/campaigns/:campaignId/archives
POST   /api/campaigns/:campaignId/archives
PUT    /api/campaigns/:campaignId/archives/:entryId
DELETE /api/campaigns/:campaignId/archives/:entryId
```

> 遭遇与 NPC 接口（`/api/campaigns/:id/npcs`、`/api/encounters/*` 等）随战斗
> 系统暂缓开发：`EncountersModule` 保留源码但**未挂载**（见 `app.module.ts`），
> 当前访问一律 404，客户端无任何消费者。对应 Prisma 模型
> （`Npc`/`Encounter`/`EncounterParticipant`）与迁移表一并保留作为后续工作流
> 起点。`MediaModule` 同样未挂载（头像走本地 data URL），`/api/media` 不可用。

### 可选 Personal Vault

```text
POST /api/vault/push
GET  /api/vault/changes
GET  /api/vault/devices
DELETE /api/vault/devices/:deviceId
```

Vault 同步个人角色、收藏、笔记、偏好和资料包 manifest。资料正文与 assets 禁止进入 payload。

### 结构化角色查询、操作与事件

```text
GET  /api/characters/:characterId
GET  /api/characters/:characterId/summary
GET  /api/characters/:characterId/events
GET  /api/campaigns/:campaignId/events

POST /api/characters/:characterId/actions/adjust-hp
POST /api/characters/:characterId/actions/add-condition
POST /api/characters/:characterId/actions/remove-condition
POST /api/characters/:characterId/actions/consume-resource
POST /api/characters/:characterId/actions/restore-resource
POST /api/characters/:characterId/items
POST /api/characters/:characterId/items/:itemId/actions/consume
POST /api/characters/:characterId/items/:itemId/actions/equip
POST /api/characters/:characterId/items/:itemId/actions/transfer
```

所有修改操作必须携带唯一 `requestId`，可以携带 `expectedRevision` 和
`campaignId`。服务端返回结构化 state、最新 revision 与不可变 GameEvent。
相同 `requestId` 重试返回首次结果（按操作类型限定；跨类型复用报 400），
并发重复请求通过 `GameEvent.requestId` 唯一约束回放首次结果。

> 旧兼容接口 `POST /api/characters`、`GET /api/characters`、
> `PATCH /api/characters/:id` 仍可调用，但 0.1 客户端角色 CRUD 已全部走
> 本地 Drift，这些端点仅保留用于旧数据与外部工具兼容，不属于新开发入口。

## 3. WebSocket

Socket.IO namespace：`/campaigns`。握手使用 access token。

```text
client -> server: campaign:join  { campaignId }
client -> server: campaign:leave { campaignId }
server -> client: campaign:message:new
server -> client: campaign:changed { campaignId, entityType, cursor }
```

`campaign:message:new` 提供已持久化消息的即时显示。`campaign:changed` 只提示客户端按 cursor 调 HTTP changes；不得把完整 Character 或资料正文塞入事件。

## 4. 一致性与重连

1. 客户端认证并加入 campaign room。
2. 拉取战役 context、消息和本地缓存游标之后的 changes。
3. WebSocket 断线期间继续保留本地只读缓存。
4. 重连后重新加入 campaign，并从最后 cursor 补齐，不依赖错过的事件。
5. 关键消息与 JournalEntry 在同一数据库事务内写入，事务提交后才广播。

## 5. 权限摘要

- 战役创建者是 owner，公开邀请码始终加入为 player。
- 客户端 Player/DM 模式只控制界面，不授予战役权限。
- owner 或服务端保留的 dm membership 可管理战役和任意 Character。
- 玩家只能绑定、发言和编辑自己拥有且未归档的 player Character；可以随时更换自己的绑定。DM 可修复任意成员的绑定。
- 玩家响应检定时，当前发言 Character 必须与请求的 targetCharacterId 一致。
