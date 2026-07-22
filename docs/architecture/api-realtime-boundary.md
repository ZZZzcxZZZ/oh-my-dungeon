# API 与实时事件边界

## 1. 当前原则

- 客户端除战役协作和可选 Personal Vault 外均可离线使用。
- REST 是服务端状态的事实源；WebSocket 只通知消息或游标变化。
- 所有写操作由服务端根据 Campaign membership 和 Actor ownership 校验。
- `Session`、`Rooms` 和独立 `CheckRequests` HTTP 模块已退出 0.1 产品路径，不得重新挂载。

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
GET  /api/campaigns/:id/journal
GET  /api/campaigns/:id/check-requests
PUT  /api/campaigns/:id/members/:userId/binding
PUT  /api/campaigns/:id/speaker
POST /api/campaigns/:id/read
POST /api/campaigns/:id/invites
GET  /api/campaigns/:id/invites
POST /api/campaigns/join
```

检定、响应和系统事件是带结构化 `eventData` 的战役消息。`check-requests` 只提供战役消息历史聚合，不是独立 Session 资源。

### Actor、战役资料与增量同步

```text
POST /api/campaigns/:campaignId/actors/publish
POST /api/campaigns/:campaignId/actors
GET  /api/campaigns/:campaignId/actors
GET  /api/campaigns/:campaignId/actors/:actorId
POST /api/campaigns/:campaignId/actors/:actorId/runtime-commands
POST /api/campaigns/:campaignId/actors/:actorId/assign
POST /api/campaigns/:campaignId/actors/:actorId/archive
GET  /api/campaigns/:campaignId/actors/:actorId/audits

POST   /api/campaigns/:campaignId/content/entries/validate
POST   /api/campaigns/:campaignId/content/entries
GET    /api/campaigns/:campaignId/content/entries
DELETE /api/campaigns/:campaignId/content/entries/:entryId
GET    /api/campaigns/:campaignId/changes
```

本地资料包正文不上传。这里只同步 DM 明确发布到战役的独立 JSON 条目。

### 战役档案与遭遇

```text
GET    /api/campaigns/:campaignId/archives
POST   /api/campaigns/:campaignId/archives
PUT    /api/campaigns/:campaignId/archives/:entryId
DELETE /api/campaigns/:campaignId/archives/:entryId

GET  /api/campaigns/:id/npcs
POST /api/campaigns/:id/npcs
GET  /api/campaigns/:id/encounters
POST /api/campaigns/:id/encounters
GET  /api/encounters/:id
POST /api/encounters/:id/participants
PATCH /api/encounters/:id/participants/:participantId
POST /api/encounters/:id/start
POST /api/encounters/:id/advance-turn
POST /api/encounters/:id/end
```

### 可选 Personal Vault

```text
POST /api/vault/push
GET  /api/vault/changes
GET  /api/vault/devices
```

Vault 同步个人角色、收藏、笔记、偏好和资料包 manifest。资料正文与 assets 禁止进入 payload。

## 3. WebSocket

Socket.IO namespace：`/campaigns`。握手使用 access token。

```text
client -> server: campaign:join  { campaignId }
client -> server: campaign:leave { campaignId }
server -> client: campaign:message:new
server -> client: campaign:changed { campaignId, entityType, cursor }
```

`campaign:message:new` 提供已持久化消息的即时显示。`campaign:changed` 只提示客户端按 cursor 调 HTTP changes；不得把完整 Actor 或资料正文塞入事件。

## 4. 一致性与重连

1. 客户端认证并加入 campaign room。
2. 拉取战役 context、消息和本地缓存游标之后的 changes。
3. WebSocket 断线期间继续保留本地只读缓存。
4. 重连后重新加入 campaign，并从最后 cursor 补齐，不依赖错过的事件。
5. 关键消息与 JournalEntry 在同一数据库事务内写入，事务提交后才广播。

## 5. 权限摘要

- 战役创建者是 owner，公开邀请码始终加入为 player。
- 客户端 Player/DM 模式只控制界面，不授予战役权限。
- owner 或服务端保留的 dm membership 可管理战役和任意 Actor。
- 玩家只能绑定、发言和编辑自己拥有的 active player Actor。
- 玩家响应检定时，当前发言 Actor 必须与请求的 targetActorId 一致。
