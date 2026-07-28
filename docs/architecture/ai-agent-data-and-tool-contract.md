# AI Agent 数据与工具接口规范

**版本：** 0.1  
**状态：** Phase 1 已实现，缺口见第 12 节  
**范围：** D&D 2024；不包含 AI Agent 运行时，不包含战斗自动化

## 1. 目的

本规范定义未来 AI Agent、Flutter UI 和其他可信客户端共同使用的数据与操作边界。目标是让 Agent：

- 读取明确的结构化状态，而不是解析界面或聊天文本；
- 通过与 UI 相同的业务操作修改状态；
- 遵守用户、角色与战役权限；
- 使用 revision 防止覆盖并发修改；
- 使用 requestId 安全重试；
- 通过不可变事件理解最近发生的变化；
- 按需读取规则引用，不把整本规则书塞入上下文。

本规范不授权 Agent 直接访问 Prisma、Drift、文件系统数据库或任意 JSON 字段。

## 2. 规范用语与状态标记

关键词 `必须`、`不得`、`应当`、`可以` 表示约束强度。

接口状态：

- `已实现`：服务端已有稳定端点并有测试。
- `部分实现`：核心能力存在，但客户端接线或返回结构仍有缺口。
- `保留`：规范已确定，当前不得假装可调用。
- `暂缓`：本阶段明确不开发。

## 3. 全局约定

### 3.1 标识符

- 所有实体使用不透明字符串 ID，调用方不得解析 ID 格式。
- 内容条目使用稳定 entryId，例如 `spell:shield`。
- 物品模板 ID 与物品实例 ID 必须分开。
- `requestId` 由调用方生成，在所有业务操作中全局唯一。

### 3.2 版本与并发

所有可变运行状态必须返回整数 `revision`。修改命令应携带：

```json
{
  "requestId": "client:char-1:hp:1721952000000",
  "campaignId": "campaign-1",
  "expectedRevision": 7
}
```

- 相同 `requestId` 重试必须返回第一次成功结果，不得重复扣血或消耗物品。
- `expectedRevision` 不匹配时必须返回冲突，不得静默覆盖。
- 查询得到的 `revision` 必须可直接用于下一次修改。

### 3.3 作用域

角色身份与角色运行状态分离：

- `profile`：姓名、构筑、属性、熟练、人物资料等持久信息。
- `local`：角色脱离战役时的默认运行状态。
- `campaign:<id>`：某一战役中的 HP、资源、状态与物品实例。

同一角色在多个战役中的运行状态不得互相污染。

### 3.4 扩展字段

扩展只能放在 `extensions` 中，并使用带点命名空间：

```json
{
  "homebrew.reputation": {
    "harpers": 2
  }
}
```

扩展只允许 JSON 数据，不允许脚本、表达式求值或动态代码。

## 4. 标准角色数据

### 4.1 CharacterProfile

`CharacterProfile` 是角色长期身份。最小标准结构：

```ts
interface CharacterProfile {
  id: string;
  ownerUserId: string;
  name: string;
  avatarUrl: string | null;
  system: "dnd5e-2024";
  level: number;
  speciesRef: string | null;
  backgroundRef: string | null;
  classes: Array<{
    classRef: string;
    subclassRef: string | null;
    level: number;
  }>;
  abilities: {
    str: number;
    dex: number;
    con: number;
    int: number;
    wis: number;
    cha: number;
  };
  saves: Record<string, boolean>;
  skills: Record<string, boolean>;
  proficiencies: string[];
  featureRefs: string[];
  spellRefs: string[];
  currency: Record<string, number>;
  biography: Record<string, string>;
  notes: string;
  extensions: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}
```

当前 `Character` 表仍保留 `classSummary`、`raceSummary`、`data` 等兼容字段。Agent 不得依赖自由文本摘要推断规则资格，应优先使用稳定引用和结构化构筑。

### 4.2 CharacterState v2

```ts
interface CharacterState {
  schemaVersion: 2;
  hitPoints: {
    current: number;
    maximum: number;
    temporary: number;
  };
  deathSaves: {
    successes: number;
    failures: number;
  };
  resources: CharacterResource[];
  conditions: CharacterCondition[];
  items: CharacterItemInstance[];
  extensions: Record<string, unknown>;
}
```

数值约束：

- HP、临时 HP、资源、物品数量不得为负数。
- `currentHp` 不得大于 `maximumHp`。
- 死亡豁免成功和失败均限制为 `0..3`。
- 资源当前值限制为 `0..maximum`。

### 4.3 CharacterResource

```ts
interface CharacterResource {
  id: string;
  name: string;
  current: number;
  maximum: number;
  restoreOn: "shortRest" | "longRest" | "none";
  sourceRef: string | null;
  custom: boolean;
}
```

`sourceRef` 指向职业、特性、专长或其他规则条目。自定义资源仍必须有稳定 ID。

### 4.4 CharacterCondition

```ts
interface CharacterCondition {
  id: string;
  type: string;
  source: {
    type: string;
    id: string | null;
  } | null;
  duration: {
    unit: "round" | "minute" | "hour" | "day" | "untilRest" | string;
    value: number;
  } | null;
  remaining: number | null;
  removable: boolean;
  metadata: Record<string, unknown>;
}
```

状态名称、来源和持续时间不得压成一句不可解析文本。

### 4.5 物品模板与物品实例

内容库中的物品是模板：

```ts
interface ItemTemplateRef {
  entryId: string;
  name: string;
  type: string;
  contentRevision: string | null;
}
```

角色背包中的物品是实例：

```ts
interface CharacterItemInstance {
  id: string;
  templateRef: string | null;
  name: string;
  quantity: number;
  equipped: boolean;
  attuned: boolean;
  instanceData: Record<string, unknown>;
}
```

模板描述“长剑是什么”，实例描述“谁拥有哪一把长剑”。任务道具、自定义附魔和消耗数量必须写在实例中。

## 5. 角色查询工具

### 5.1 `character.get`

**状态：已实现**

```text
GET /api/characters/:characterId?campaignId=:campaignId
```

用途：读取完整 resolved view。返回 profile 字段、作用域状态、`stateRevision` 和 `stateScope`。

权限：

- 角色所有者可以读取本地状态；
- 战役成员可在给出 `campaignId` 后读取该战役允许访问的角色；
- 无权限时不得泄露角色是否存在以外的私人数据。

### 5.2 `character.get_summary`

**状态：已实现**

```text
GET /api/characters/:characterId/summary?campaignId=:campaignId
```

返回字段限制为：

```ts
interface CharacterSummary {
  id: string;
  name: string;
  level: number;
  classSummary: string;
  raceSummary: string;
  hitPoints: HitPoints;
  conditions: Array<{ id: string; type: string }>;
  equipment: Array<{ id: string; name: string; quantity: number }>;
  stateRevision: number;
  stateScope: string;
}
```

列表、Agent 上下文和目标选择应优先使用摘要，不应默认读取完整角色卡。

### 5.3 `character.list_events`

**状态：已实现**

```text
GET /api/characters/:characterId/events
  ?cursor=:cursor
  &type=:eventType
  &since=:isoTime
  &limit=:limit
```

事件必须按游标分页。Agent 不得一次请求整个角色历史。

## 6. 角色修改工具

### 6.1 通用命令与返回值

所有角色状态操作共享：

```ts
interface CharacterOperationBase {
  requestId: string;
  campaignId?: string | null;
  expectedRevision?: number;
}

interface CharacterOperationResult {
  state: CharacterState;
  revision: number;
  event: GameEvent;
}
```

调用方不得提交 `actorId`、`before` 或 `after`；这些字段由服务端根据认证身份和真实状态生成。

### 6.2 HP

**工具：** `character.adjust_hp`  
**状态：服务端与 Flutter 已实现**

```text
POST /api/characters/:characterId/actions/adjust-hp
```

```json
{
  "requestId": "request-1",
  "campaignId": "campaign-1",
  "expectedRevision": 7,
  "delta": -8
}
```

也可使用 `current` 设置当前 HP，或使用 `temporary` 设置临时 HP。三者不能全部缺省。

### 6.3 状态效果

| 工具 | HTTP | 状态 |
| --- | --- | --- |
| `character.add_condition` | `POST /api/characters/:id/actions/add-condition` | 已实现 |
| `character.remove_condition` | `POST /api/characters/:id/actions/remove-condition` | 已实现 |

添加状态时传完整 `CharacterCondition`。移除时传 `conditionId`。不可移除状态必须由服务端拒绝普通移除操作。

### 6.4 资源

| 工具 | HTTP | 状态 |
| --- | --- | --- |
| `character.consume_resource` | `POST /api/characters/:id/actions/consume-resource` | 已实现 |
| `character.restore_resource` | `POST /api/characters/:id/actions/restore-resource` | 已实现 |

输入包含 `resourceId` 和正整数 `amount`。调用方不得直接提交资源的新当前值。

### 6.5 物品

| 工具 | HTTP | 服务端 | Flutter 统一客户端 |
| --- | --- | --- | --- |
| `character.grant_item` | `POST /api/characters/:id/items` | 已实现 | 已实现 |
| `character.consume_item` | `POST /api/characters/:id/items/:itemId/actions/consume` | 已实现 | 未接线 |
| `character.equip_item` | `POST /api/characters/:id/items/:itemId/actions/equip` | 已实现 | 未接线 |
| `character.transfer_item` | `POST /api/characters/:id/items/:itemId/actions/transfer` | 已实现 | 未接线 |

转移物品必须携带 `campaignId`、`targetCharacterId` 和正整数数量，并在同一事务内更新双方状态与事件。

### 6.6 完整编辑

**工具：** `character.update_profile`、`character.update_build`  
**状态：部分实现**

当前 UI 和 `PATCH /api/characters/:id` 支持完整编辑，但尚未拆分为带 `requestId`、revision 和 `GameEvent` 的审计操作。未来 Agent 在该缺口补齐前不得使用通用 PATCH 修改构筑。

## 7. 战役、会话与档案工具

### 7.1 战役上下文

**工具：** `campaign.get_workspace_context`  
**状态：部分实现**

```text
GET /api/campaigns/:campaignId/context
```

当前返回战役、当前成员身份、成员、Actor 摘要和 capability。它不是最终 Agent Context；尚未统一返回当前地点、目标、近期事件和知识引用。

### 7.2 战役事件

**工具：** `campaign.list_events`  
**状态：已实现**

```text
GET /api/campaigns/:campaignId/events
  ?cursor=:cursor
  &type=:eventType
  &since=:isoTime
  &limit=:limit
```

### 7.3 消息与会话

现有主聊、私聊和小群接口可以作为未来 Agent 的通信工具，但 Agent 必须显式声明目标会话，不得把私聊内容发送到战役主房间。

最低工具集合：

```text
campaign.list_messages
campaign.send_message
conversation.list
conversation.create_direct
conversation.create_group
conversation.archive
conversation.mark_read
```

消息必须使用结构化 `kind` 和 `eventData`。系统事实应引用 `GameEvent.id`，不得仅写一条无法追踪来源的自然语言系统消息。

### 7.4 档案与知识引用

```text
archive.list
archive.get
archive.create
archive.update
archive.delete
content.search
content.get
```

Agent 应保存稳定内容引用和摘要，不复制整篇规则正文进事件、聊天或记忆。

## 8. GameEvent

```ts
interface GameEvent {
  schemaVersion: number;
  type: string;
  campaignId: string | null;
  characterId: string | null;
  actorType: "user" | "system" | "agent";
  actorId: string;
  requestId: string;
  targets: Array<Record<string, unknown>>;
  cause: Record<string, unknown> | null;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  payload: Record<string, unknown>;
  occurredAt: string;
}
```

规则：

- 事件不可修改或删除；
- `before` 和 `after` 只记录本次变化涉及的字段；
- `payload` 存结构化事实，不存本地化展示句子；
- Agent 触发的操作必须记录真实认证用户和 Agent 调用来源，不能伪装成其他玩家；
- 聊天展示可以本地化，但必须能追溯到事件 ID。

当前事件覆盖 HP、状态、资源和物品操作。任务、地点、NPC 事实的事件类型尚未统一。

## 9. 错误与权限

建议工具层统一映射：

| HTTP | 工具错误 | 含义 |
| --- | --- | --- |
| 400 | `invalid_argument` | 参数、数值或 D&D 边界无效 |
| 401 | `unauthenticated` | 登录失效 |
| 403 | `permission_denied` | 不具备角色或战役权限 |
| 404 | `not_found` | 实体不存在或不可见 |
| 409 | `revision_conflict` | revision 冲突，必须重新读取 |
| 429 | `rate_limited` | 调用过于频繁 |
| 500 | `internal_error` | 服务端错误，不得自动猜测成功 |

Agent 遇到 `revision_conflict` 时必须重新查询并重新规划，不得去掉 `expectedRevision` 强行重试。

## 10. 有界 Agent Context

最终 `campaign.get_agent_context` 为保留接口，当前不得假装已实现。建议返回：

```ts
interface CampaignAgentContext {
  schemaVersion: 1;
  campaign: {
    id: string;
    name: string;
    currentLocationRef: string | null;
  };
  requester: {
    userId: string;
    role: string;
    capabilities: string[];
  };
  actors: CharacterSummary[];
  activeObjectives: Array<{
    id: string;
    title: string;
    status: string;
  }>;
  recentEvents: GameEvent[];
  knowledgeRefs: Array<{
    entryId: string;
    type: string;
    title: string;
  }>;
  cursors: {
    events: string | null;
    messages: string | null;
  };
}
```

上下文必须有数量和时间边界：

- Actor 默认只返回当前战役相关摘要；
- 事件默认最近 20 条，最大 100 条；
- 规则只返回引用；
- 私聊只在请求者是参与者时返回；
- 需要全文时由 Agent 再调用 `content.get` 或 `archive.get`。

## 11. 离线与 Markdown

- Drift 是 Flutter 离线事实源。
- 本地角色操作先保存本地并进入 Vault outbox。
- 战役操作在线时以服务端返回 state 和 revision 覆盖缓存。
- Markdown 是可读交换格式，不是运行时数据库。
- Markdown 导入必须先展示差异，再由用户选择新建、覆盖或合并。
- Agent 可以生成或修改 Markdown 草稿，但不得跳过解析、校验和用户确认直接覆盖角色。

格式标识：

```yaml
format: dnd-table-character/v1
```

## 12. 当前实现差距

以下项目是验收缺口，不是允许 Agent 绕过的理由：

1. Flutter `CharacterCondition` 尚未完整保留服务端的 `source`、`duration` 和 `removable`。
2. 服务端移除状态操作尚未执行 `removable` 约束。
3. Flutter 统一操作客户端尚未接入物品消耗、装备和转移。
4. 完整角色 profile/build 编辑尚未产生统一 `GameEvent`。
5. 通用角色列表尚未明确展示“最近活动战役状态”的来源标签。
6. `/campaigns/:id/context` 是工作区上下文，不是最终有界 Agent Context。
7. 任务、地点、NPC 与线索尚未形成统一结构化事实和事件类型。
8. Agent 身份、授权委托、工具审批与速率限制尚未实现。
9. 战斗数据和战斗工具按用户要求暂缓，不属于本轮验收范围。

## 13. Agent 工具注册要求

未来将 HTTP 能力包装为 Agent tools 时，每个工具定义必须包含：

- 稳定名称，例如 `character.adjust_hp`；
- 简短用途，不包含规则书全文；
- 完整 JSON Schema；
- 是否只读；
- 所需 capability；
- 是否需要用户确认；
- 幂等和 revision 说明；
- 可返回的错误集合；
- 对应 HTTP 端点和版本。

危险工具默认需要确认：

- 转移或删除物品；
- 覆盖完整角色卡；
- 修改他人角色；
- 发送公开战役消息；
- 删除或归档战役内容。

查询、摘要、搜索和预览默认不需要确认，但仍受权限控制。
