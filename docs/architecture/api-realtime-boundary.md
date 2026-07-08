# API 与实时事件边界

## 1. 原则

REST 管资源，WebSocket 管实时事件。关键实时事件必须落库，不能只存在内存中。

客户端所有写操作都必须经过服务端权限校验。客户端可以隐藏无权限 UI，但不能作为权限依据。

## 2. REST API 范围

### 2.1 Server

```text
GET /health
GET /.well-known/dnd-tool-server
GET /api/server-settings
PATCH /api/server-settings
```

`/.well-known/dnd-tool-server` 用于客户端添加服务器时发现服务端能力。

### 2.2 Auth

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/auth/me
```

### 2.3 Campaigns

```text
GET    /api/campaigns
POST   /api/campaigns
GET    /api/campaigns/:id
PATCH  /api/campaigns/:id
DELETE /api/campaigns/:id
```

### 2.4 Members and Invites

```text
GET  /api/campaigns/:id/members
POST /api/campaigns/:id/invites
GET  /api/campaigns/:id/invites
POST /api/campaigns/join
PATCH /api/campaigns/:id/members/:memberId
DELETE /api/campaigns/:id/members/:memberId
```

### 2.5 Sessions

```text
GET  /api/campaigns/:id/sessions
POST /api/campaigns/:id/sessions
POST /api/sessions/:id/start
POST /api/sessions/:id/end
GET  /api/sessions/:id
```

### 2.6 Characters

```text
GET    /api/characters
POST   /api/characters
GET    /api/characters/:id
PATCH  /api/characters/:id
DELETE /api/characters/:id
POST   /api/campaigns/:id/character-bindings
GET    /api/campaigns/:id/characters
PATCH  /api/campaigns/:id/character-bindings/:bindingId
```

### 2.7 Compendium

```text
GET  /api/content/packages
POST /api/content/packages/import
GET  /api/content/items
GET  /api/content/items/:id
POST /api/campaigns/:id/content/overrides
GET  /api/campaigns/:id/content/available
POST /api/campaigns/:id/content/packages
```

### 2.8 Journal

```text
GET  /api/campaigns/:id/journal
POST /api/campaigns/:id/journal
```

### 2.9 Encounters

```text
GET   /api/campaigns/:id/encounters
POST  /api/campaigns/:id/encounters
GET   /api/encounters/:id
PATCH /api/encounters/:id
POST  /api/encounters/:id/participants
PATCH /api/encounters/:id/participants/:participantId
POST  /api/encounters/:id/start
POST  /api/encounters/:id/advance-turn
POST  /api/encounters/:id/end
```

## 3. WebSocket 连接

连接地址由服务器元信息返回：

```text
wss://example.com/realtime
```

客户端连接时使用 JWT 鉴权。连接后客户端加入 campaign/session 房间。

```text
client -> server: realtime.join_campaign
client -> server: realtime.join_session
```

## 4. 实时事件命名

事件命名采用领域前缀：

```text
chat.message.created
dice.roll.created
roll_request.created
roll_request.answered
character.hp.updated
character.resource.updated
character.condition.added
character.condition.removed
encounter.started
encounter.turn_advanced
encounter.ended
journal.entry.created
member.presence.updated
```

## 5. 广播范围

每个实时事件必须定义广播范围：

- campaign：战役内所有有权限成员。
- session：当前跑团会话内成员。
- dm：当前战役 DM 和 owner。
- user：指定用户。
- private：指定用户集合。

## 6. 可见性

事件 payload 必须包含或可推导 visibility：

```text
public
dm_only
private
```

服务端根据 visibility 和 CampaignMember 过滤事件。不能把 dm_only 数据发给玩家后再由客户端隐藏。

## 7. 事件落库规则

必须写 JournalEntry 的事件：

- dice.roll.created
- roll_request.created
- roll_request.answered
- character.hp.updated
- character.resource.updated
- character.condition.added
- character.condition.removed
- encounter.started
- encounter.turn_advanced
- encounter.ended
- content.package.imported
- campaign.member.joined

聊天消息保存到 ChatMessage，并可生成 JournalEntry 或在日志视图聚合显示。

## 8. 掷骰事件示例

```json
{
  "event": "dice.roll.created",
  "payload": {
    "campaignId": "camp_123",
    "sessionId": "sess_123",
    "rollerUserId": "user_123",
    "characterId": "char_123",
    "expression": "1d20+5",
    "result": 18,
    "breakdown": {
      "terms": [
        { "type": "die", "count": 1, "sides": 20, "rolls": [13] },
        { "type": "modifier", "value": 5 }
      ]
    },
    "visibility": "public",
    "reason": "察觉检定"
  }
}
```

## 9. 检定请求流程

1. DM 通过 REST 或 WebSocket 创建 RollRequest。
2. 服务端校验 DM 权限并写入 RollRequest。
3. 服务端广播 roll_request.created。
4. 玩家客户端展示一键响应入口。
5. 玩家响应时创建 DiceRoll。
6. 服务端关联 rollRequestId，写 DiceRoll 和 JournalEntry。
7. 服务端广播 roll_request.answered。

## 10. 离线与重连

客户端重连后不依赖错过的 WebSocket 事件恢复状态。重连流程：

1. 重新认证。
2. 重新加入 campaign/session。
3. 拉取当前 Session 快照。
4. 拉取最近 JournalEntry 或使用 lastSeenEventTime 补齐。

