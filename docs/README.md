# OhMyDungeon 项目文档（唯一事实来源）

本文件是项目的**唯一当前事实来源**，合并并校订了此前的架构、数据、接口、部署、开发、
工程规范与设计文档。文中所有事实均以当前代码为准（HEAD `a278d06` 之后的 `0.1` 开发线）。

- 面向使用者的安装与使用教程见 [`../README.md`](../README.md)
- 设计 token 与组件契约见 [`../DESIGN.md`](../DESIGN.md)
- 历史文档（已被本文件取代）见 [`archive/`](archive/README.md)，仅用于追溯

## 目录

1. [项目定位与范围](#1-项目定位与范围)
2. [快速事实](#2-快速事实)
3. [仓库结构](#3-仓库结构)
4. [系统架构](#4-系统架构)
5. [数据模型](#5-数据模型)
6. [接口边界](#6-接口边界)
7. [领域行为](#7-领域行为)
8. [离线与同步](#8-离线与同步)
9. [内容体系](#9-内容体系)
10. [设计与前端规范](#10-设计与前端规范)
11. [部署与运维](#11-部署与运维)
12. [本地开发](#12-本地开发)
13. [私有资料流水线](#13-私有资料流水线)
14. [工程规范](#14-工程规范)
15. [Agent 协作规范](#15-agent-协作规范)
16. [当前状态与验收基线](#16-当前状态与验收基线)
17. [归档说明](#17-归档说明)

---

## 1. 项目定位与范围

开源自托管的 D&D 跑团辅助工具。**客户端离线优先**：角色、资料库、设置与 Markdown 镜像
无需服务器；服务器提供账号、可选 Personal Vault 同步与多人战役协作。

| 范围 | 内容 |
|---|---|
| **在范围内** | 本地角色管理、资料库（内容包/自制内容/检索/阅读）、角色 Markdown v2 镜像、私人工作区、战役协作（主聊/私聊/小群/档案/角色/成员/邀请）、检定请求、骰子、Vault 同步、自托管部署 |
| **不在范围内** | 战斗系统运行时、AI Agent 运行时、通用 TRPG 引擎、Room/Session 前置流程 |
| **预留但未实现** | AI Agent 查询/操作/事件契约（见 §7.5）、Encounter 相关接口（模块已删除） |

领域命名：统一使用 **Character**。`Actor` 仅存在于数据库兼容迁移与归档文档中。

---

## 2. 快速事实

| 项 | 值 |
|---|---|
| 版本 | `0.1.0`（pubspec `0.1.0+1`；仅此一条版本线） |
| 客户端 | Flutter `3.41.4` / Dart `3.11.1`，Material 3，`http`（**未使用 Dio**） |
| 服务端 | NestJS + Prisma `6.19.3` + PostgreSQL 16 |
| 客户端本地库 | Drift `2.34.1`，`schemaVersion = 13`，19 张表 |
| 服务端端口 | `3000`（REST + Socket.IO） |
| 数据库 | `dnd_table` / 用户 `dnd`；端口仅绑定 `127.0.0.1:5432` |
| 健康检查 | `GET /health`（一次 `SELECT 1`） |
| 服务发现 | `GET /.well-known/dnd-tool-server` |
| API 前缀 | `/api`（`/health` 与 `.well-known` 除外） |
| WebSocket | namespace `campaigns`（客户端拼 `${origin}/campaigns`） |
| 契约文档 | 本文件；**无 Swagger/OpenAPI**（全仓 0 命中） |
| 代码生成 | 仅 Drift（`build_runner` + `drift_dev`）；**未引入 freezed / json_serializable / go_router** |
| 阶段门 | `npm run check`（= `lint:server` + `analyze:client` + `test`） |

---

## 3. 仓库结构

```text
apps/
  client_flutter/        Flutter 客户端
    lib/src/app/         应用装配与主题（theme/、app_identity.dart）
    lib/src/core/        数据库、备份、骰子、同步、工作区、共享组件
    lib/src/features/    按功能分包（见下）
    test/                测试（含 golden/ 与契约测试 app_theme_test.dart）
  server_nest/           NestJS 服务端
    src/modules/         领域模块（auth/campaigns/campaign-sync/characters/...）
    prisma/              schema.prisma + 18 个迁移
    engines/             离线 Prisma 引擎（Git 忽略）
    test/                e2e 测试
infra/linux-server/      自托管脚本（start.sh / stop.sh / README）
scripts/                 环境、验证、打包、私有资料工具（PowerShell + Python）
docs/
  README.md              本文件（唯一事实来源）
  archive/               历史文档（仅追溯）
DESIGN.md                设计系统 token 与组件契约
docker-compose.yml       生产编排（postgres + server）
docker-compose.dev.yml   本地开发编排
dist/                    本地构建产物（Git 忽略）
private-imports/         本地私有资料（Git 忽略）
```

**客户端功能分包**（`lib/src/features/`）：

| 包 | 职责 |
|---|---|
| `characters` | 角色聚合、角色卡、编辑器、升级、Markdown 镜像、冲突 |
| `campaigns` | 战役、中心面板、聊天、档案、战役角色、战役内容 |
| `content` | 内容包导入导出、资料库检索/阅读、自制内容 |
| `auth` | 注册/登录/刷新/登出、断网会话恢复 |
| `server_profiles` | 服务器档案、发现、默认服务器注入 |
| `server_home` | 主壳、导航、设置页 |
| `vault` | Personal Vault 同步 |
| `app_preferences` | 外观/游戏偏好（SharedPreferences） |
| `client_mode` | 玩家 / 主持人模式 |
| `rules` | 规则投影（角色构建规则） |

> `core/` 提供跨功能基础设施：`database/`、`backup/`、`dice/`、`sync/`、`workspace/`、
> `widgets/`、`presentation/`。**`core/` 没有网络层**——HTTP 客户端位于各功能的
> `features/<name>/data/`。

---

## 4. 系统架构

### 4.1 组件

```text
Flutter 客户端 ──HTTP(/api)──▶ NestJS 服务端 ──Prisma──▶ PostgreSQL
        └──────Socket.IO(/campaigns)──────┘
本地：Drift(SQLite) + SharedPreferences        运行期依赖：无 Redis、无消息队列
```

- 客户端与服务端**只通过查询/操作服务访问数据**，UI 不直写数据库。
- 服务端是**无状态进程**（除数据库与上传卷），可水平重启。
- 上传文件写入容器内 `/data/uploads`（Docker 命名卷 `uploads`）。

### 4.2 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `SERVER_NAME` | `OhMyDungeon` | 发现端点广播的服务名 |
| `PUBLIC_BASE_URL` | `http://localhost:3000` | 客户端可达地址；决定 `apiBaseUrl` / `websocketUrl` |
| `CORS_ORIGIN` | 空 | 逗号分隔白名单；**留空=禁止跨域** |
| `DATABASE_URL` | 由 compose 注入 | `postgresql://dnd:<pwd>@postgres:5432/dnd_table` |
| `POSTGRES_PASSWORD` | 首次启动随机生成 | compose 强制必填 |
| `JWT_SECRET` | 首次启动随机生成 | compose 强制必填 |
| `REGISTRATION_ENABLED` | `true` | 是否开放注册 |
| `DEFAULT_LOCALE` | `zh-CN` | 默认语言 |
| `UPLOAD_DIR` | `/data/uploads` | 上传目录 |
| `MAX_UPLOAD_SIZE_MB` | `20` | 上传上限（同时影响 JSON body 限制） |

### 4.3 健康检查与发现

- `GET /health` → `{"status":"ok","service":"ohmydungeon-server","timestamp":...,"database":{"status":"ok"}}`
- `GET /.well-known/dnd-tool-server` → `instanceId`、`name`、`version`、`apiBaseUrl`（`$PUBLIC_BASE_URL/api`）、
  `websocketUrl`（`ws(s)://host/campaigns`）、`registrationEnabled`、`serverMode: self_hosted`、
  `supportedSystems: [dnd5e]`、`apiVersion: '1'`、`features: [campaignArchives, campaignCharacters, campaignChat]`
- 服务端**没有启动自检器**；必需变量由 compose 的 `${VAR:?}` 在编排层强制。

---

## 5. 数据模型

### 5.1 客户端本地库（Drift，`schemaVersion = 13`，19 张表）

| 分组 | 表 |
|---|---|
| 服务器与同步 | `ServerProfiles`、`SyncOutbox`、`SyncCursors`、`MigrationMarkers`、`VaultEntityRevisions` |
| 内容 | `LocalContentPackages`、`LocalContentEntries`、`LocalContentAssets`、`ContentLinks`、`ContentFavorites`、`ContentNotes`、`ContentReadHistory` |
| 角色 | `Characters`、`CharacterContentRefs` |
| 战役缓存 | `CampaignCharactersCache`、`CampaignCharacterBacklinks`、`CampaignContentCache`、`CampaignSyncCursors`、`CharacterSyncConflicts` |

> **注意**：不存在 `VaultOutbox` / `VaultCursors` / `VaultDevices` / `VaultSyncConflicts`
> 等表，也不存在 Drift 的偏好表——**偏好存于 SharedPreferences**。同步出站与游标统一由
> `SyncOutbox` / `SyncCursors` 承担，Vault 的实体版本由 `VaultEntityRevisions` 记录。

### 5.2 服务端数据库（Prisma）

活跃模型（被当前模块使用）：

| 领域 | 模型 |
|---|---|
| 服务器 | `ServerSetting`、`ServerAdmin` |
| 账号 | `User`、`RefreshToken` |
| Vault | `VaultEntity`、`VaultChange`、`VaultOperation`、`VaultDevice` |
| 战役 | `Campaign`、`CampaignMember`、`CampaignInvite`、`CampaignConversation`、`CampaignConversationRead`、`CampaignChange`、`CampaignSyncState` |
| 战役角色 | `CampaignCharacter`、`CampaignCharacterAudit`、`CharacterCampaignBinding` |
| 战役内容/档案 | `CampaignContentEntry`、`CampaignArchiveEntry` |
| 聊天与检定 | `CampaignChatMessage`、`CheckRequest`、`CheckResponse` |
| 角色 | `Character`、`CharacterState`、`GameEvent` |
| 媒体 | `MediaAsset`（媒体模块已删除，模型保留） |

**保留但当前无运行时代码使用的模型**（旧产品线遗留，供数据兼容/迁移）：
`Session`、`SessionMember`、`ChatMessage`、`DiceRoll`、`JournalEntry`、`Npc`、
`Encounter`、`EncounterParticipant`。**不要基于它们新增接口**；如需清理须配套迁移。

其他需要注意的列：

- `CampaignMember.boundCharacterId` 在数据库中的列名仍是 `boundActorId`
  （`@map` 兼容映射），这是 Actor→Character 迁移的遗留，不是新概念。
- `CampaignCharacter.healthVisibility` 目前**没有任何读写代码**，属于未启用列。

### 5.3 私人工作区与会话

- 每个服务器账号一份本地工作区；未登录使用 `local` 工作区。
- 工作区由 `core/workspace/` 管理（存储管理器 + 会话协调器 + 身份），切换账号/服务器时隔离。
- **数据库文件命名**：扁平命名 `workspace_<storageKey>.db`，账号工作区的
  `storageKey = account_<sha256>`（不存在 `accounts/<id>/workspace.db` 目录树）。
- **引导库**：`bootstrap.db` 使用的是**同一套完整 Drift schema**（19 张表），
  并非简化的"引导域表"；服务器档案即存于此库。
- **切换顺序**：先打开新库，旧库进入待回收集合并于 `completeHandoff()` 后关闭
  （不是"先关旧库再开新库"）。
- 服务端会话：JWT access token + refresh token；客户端持久化于安全存储并可自动登录；
  断网时保留本地会话（`auth` 功能包）。

---

## 6. 接口边界

### 6.1 REST（前缀 `/api`）

**认证** `auth.controller.ts`
`POST /auth/register`、`POST /auth/login`、`GET /auth/me`、`POST /auth/refresh`、`POST /auth/logout`

**战役** `campaigns.controller.ts`
`POST /campaigns`、`GET /campaigns`、`GET /campaigns/:id`、`GET /campaigns/:id/context`、
`GET /campaigns/:id/messages`、`POST /campaigns/:id/messages`、`POST /campaigns/:id/read`、
`GET /campaigns/:id/check-requests`、`GET /campaigns/:id/journal`、
`PUT /campaigns/:id/members/:userId/binding`、`PUT /campaigns/:id/speaker`、
`POST /campaigns/:id/invites`、`GET /campaigns/:id/invites`、`POST /campaigns/join`

**会话** `campaign-conversations.controller.ts`
`GET /campaigns/:campaignId/conversations`、`POST …/direct`、`POST …/group`、
`PATCH …/:conversationId`、`POST …/:conversationId/read`

**档案** `campaign-archives.controller.ts`
`GET /campaigns/:campaignId/archives`、`POST …`、`PUT …/:entryId`、`DELETE …/:entryId`

**战役角色** `campaign-characters.controller.ts`
`GET|POST /campaigns/:campaignId/characters`、`GET|PUT …/:characterId`、
`POST …/publish`、`POST …/:characterId/assign`、`POST …/:characterId/archive`、
`POST …/:characterId/restore`、`POST …/:characterId/runtime-commands`、
`GET …/:characterId/audits`

**战役内容与增量** `campaign-content.controller.ts`
`POST /campaigns/:campaignId/content/entries/validate`、`GET|POST …/content/entries`、
`PUT|DELETE …/content/entries/:entryId`、`GET /campaigns/:campaignId/changes`

**状态事件** `campaign-events.controller.ts`（前缀 `/campaigns/:campaignId/characters/:characterId`）
`POST /hp`、`POST /items`、`POST /conditions`

**角色** `characters.controller.ts`
`POST|GET /characters`、`GET /characters/:id`、`GET /characters/:id/summary`、`PATCH /characters/:id`、
`POST /characters/:characterId/actions/{adjust-hp,add-condition,remove-condition,consume-resource,restore-resource}`、
`POST /characters/:characterId/items`、
`POST /characters/:characterId/items/:itemId/actions/{consume,equip,transfer}`

**事件** `game-events.controller.ts`
`GET /characters/:characterId/events`、`GET /campaigns/:campaignId/events`

**Vault** `vault.controller.ts`
`POST /vault/push`、`GET /vault/changes`、`GET /vault/devices`、`DELETE /vault/devices/:deviceId`

> **不存在** `POST /api/vault/devices`：设备通过 `push` / `changes` 请求头 `X-Device-Id`
> 隐式注册（`vault.service.ts`）。

**服务器设置** `server-settings.controller.ts`
`GET /server-settings`、`PATCH /server-settings`

**前缀之外**：`GET /health`、`GET /.well-known/dnd-tool-server`

### 6.2 WebSocket

- namespace：`campaigns`；客户端连接 `${origin}/campaigns`。
- 用途：战役变更广播（消息、角色、档案、内容），客户端据此做增量拉取。
- 反向代理需放行 WebSocket 升级 `/campaigns`。

### 6.3 契约约定

- 无 Swagger/OpenAPI；接口以本文件与控制器实现为准，客户端 DTO 手写。
- 写操作必须经服务端业务服务 → 权限策略 → 持久化，并记录结构化事件。
- `GET /campaigns/:id/messages` 支持 `conversationId` 查询参数；
  `GET /campaigns/:campaignId/changes` 会为 upsert 项附带完整实体。
- 服务端未实现限流（无 throttler）；429 `rate_limited` 属**规划**而非现状。

---

## 7. 领域行为

### 7.1 角色

- **本地优先**：角色先存本地 Drift（`Characters` / `CharacterContentRefs` 等）。
- **Character 文档 v2**：Markdown v2 导入/导出 + 原生自动镜像；外部文件被改动时生成差异，
  由用户在冲突界面确认（`character_import_preview_sheet`、`character_conflict_resolution_page`）。
  - frontmatter 关键字段：`format: dnd-table-character/v2`、`mode`、`id`、`revision`、
    `contentHash`、`generatedAt`、`owner`、`armorClass`、`hitPoints`、`speed`、`abilities`；
    `snapshot` 字段存放 base64url 编码的规范 JSON（规则快照，离线可读）。
  - 正文小节：基础资料 / 属性 / 豁免 / 技能 / 战斗 / 资源 / 状态 / 装备 / 货币 / 描述 / 笔记，
    以及由 `ruleSnapshots` 生成的规则特性 / 法术 / 角色动作。
  - v1 仅支持读取，不产出。
- **文档 data 分区**：`build`、`runtime`、`contentRefs`、`ruleSnapshots`、`actions`、
  `monster`、`profile`、`manualOverrides`、`extensions`；`ruleSnapshots` 以条目 ID 为键并带
  `snapshotVersion`。
- **结构化状态**：`CharacterState`（HP/临时 HP/资源/状态/法术位等）；
  `GameEvent` 记录运行时事件，字段为 `initiatorType` / `initiatorId`（**不是** `characterType`/`characterId`）。
- **角色类型**：`CampaignCharacter.characterType` ∈ `player` / `npc` / `monster` / `companion` / `unclaimed`；
  另有 `visibleToPlayers`、`healthVisibility`、`avatarAssetId`。
- **同步冲突**：`CharacterSyncConflicts` + 冲突横幅与解决页。

### 7.2 战役

- 战役 = 长期聊天与协作工作区（主聊 / 私聊 / 小群 / 角色 / 成员 / 档案 / 共享资料）。
- 成员角色与权限：owner 可管理战役；DM/玩家通过 `ClientMode` 切换客户端能力集合。
- 邀请：`CampaignInvite`（邀请码、有效期、次数、是否需审批）。
- 角色发布与绑定：玩家把本地角色**发布**为战役角色并绑定；DM 可管理全部战役角色
  （指派发言身份、归档/恢复、代改运行时状态）。
- 审计：`CampaignCharacterAudit` 记录战役角色变更。

### 7.3 聊天与消息

- `CampaignChatMessage.kind` ∈ `say` / `action` / `roll` / `system` / `checkRequest` /
  `ooc` / `archivePublished`；`ooc` 同时是一个**独立布尔字段**，不是仅靠 kind 区分。
- 消息还带 `conversationId`、`speakerAvatarAssetId`、`publicHealthFraction` 等字段。
- 会话模型：`CampaignConversation`（direct/group）+ `CampaignConversationRead` 未读游标。
- 增量刷新：`CampaignChange` / `CampaignSyncState` + WebSocket 广播；客户端以游标拉取。

### 7.4 检定请求

- DM 发起 `CheckRequest`（属性/技能、DC、优劣势、可见性），玩家提交 `CheckResponse`。
- 状态通过 `GET /campaigns/:id/check-requests` 与消息流同步。

### 7.5 事件与预留契约（AI Agent）

- `GameEvent` 是**已实现**的运行时事件流（角色 HP/物品/状态等），可由
  `GET /characters/:id/events`、`GET /campaigns/:id/events` 查询。
- 战役作用域仍在用：客户端在角色相关请求中继续携带 `campaignId`，服务端
  `scopeKey` 形如 `campaign:<id>`（**未废弃**）。
- **未实现**：Agent 专用查询/操作端点、限流、事件订阅协议。相关设计属预留，
  不得当作现存接口调用。

### 7.6 权限策略（真实方法名）

`campaign.policy.ts` 公开方法（唯一权限入口）：

```
canCreateCampaign  canViewCampaign  canManageCampaign  canJoinCampaign
canViewCharacter   canManageCharacter  canEditOwnedCharacter  canPublishCharacter
canBindCharacter   canManageMembershipBinding  canSpeakAsCharacter
```

> 不存在 `canEditCharacter`、`canViewCampaignContent`、`canSendDmOnlyMessage`、`canManageEncounter`。

---

## 8. 离线与同步

### 8.1 本地优先

| 能力 | 是否需要服务器 |
|---|---|
| 角色（创建/编辑/升级/Markdown 镜像） | 否 |
| 资料库（内容包、自制内容、检索、阅读） | 否 |
| 设置与外观、骰子 | 否 |
| 战役协作（聊天/档案/角色共享） | 是 |
| 账号与 Personal Vault 同步 | 是（可选） |

### 8.2 同步机制

- **出站队列** `SyncOutbox` + **游标** `SyncCursors`：本地变更排队上行，远端变更按游标下行。
- **刷新资源类型只有 4 种**：`messages`、`characters`、`archives`、`conversations`；
  成员与已读游标归入 `messages`，内容归入 `archives`（不存在按实体的 7 类划分）。
- 网络恢复、应用回到前台触发重试；失败保留在队列并可视化错误状态。
- 冲突：角色以 `CharacterSyncConflicts` 呈现人工确认；战役内容以 revision/hash 比对。
- 战役角色同步会**回写本地角色**（`CampaignSyncService`），使本地卡与战役快照保持一致。

### 8.3 Personal Vault

- 服务端模型：`VaultEntity` / `VaultChange` / `VaultOperation` / `VaultDevice`。
- **实体类型**（6 种）：`character`、`favorite`、`note`、`preferences`、
  `personalContentEntry`、`installedPackageManifest`。
- 客户端 Vault 实体版本记录于 `VaultEntityRevisions`。
- **本地专属实体**：`preferences`、`installedPackageManifest`、`personalContentEntry`
  的远端 apply 是 **no-op**（仅本地生效，不落远端库）。
- 设备：`GET /vault/devices`、`DELETE /vault/devices/:deviceId`；注册是隐式的
  （`X-Device-Id` 请求头随 `push`/`changes` 写入，设备名/平台以 `Unknown` 占位）。
- 分页：`GET /vault/changes` 页大小固定 500，**没有** `limit` 参数。
- 同步是**手动触发**（设置内按钮），不是后台自动轮询。

---

## 9. 内容体系

### 9.1 内容包格式 v2

**聚合包 / 内置包**（JSON，用于 `bundled_content.json` 或私有聚合）：

```jsonc
{
  "formatVersion": 2,
  "id": "core-2024-private-test",
  "name": "…", "version": "0.1.1", "locale": "zh-CN", "system": "dnd5e-2024",
  "entryCount": 1880,
  "entries": [
    { "id": "…", "name": "…", "slug": "…", "type": "spell|monster|item|class|…",
      "source": "…", "revision": 1, "summary": "…", "tags": [], "aliases": [],
      "structured": { }, "body": "…" }
  ]
}
```

**可分发包 `.dndpack`**（zip）：必须包含 `manifest.json` 与 `entries.json`，可选 `assets/`；
限制：压缩 ≤ 50MB、文件数 ≤ 5000、单文件 ≤ 20MB、解压后 ≤ 200MB；只允许上述三类路径
（拒绝路径穿越与重复路径），图片必须是 PNG/JPEG/GIF/WebP 且签名匹配。

**校验规则（任一失败整包不写）**：

- `manifest.json` 必填 `formatVersion`（新包用 `2`，`1` 仅兼容读取）、
  `id`、`name`、`version`、`locale`、`system`（白名单 `dnd5e-2024`）、`entryCount`；
  `entryCount` 必须等于 `entries.length`。
- entry 必填 `id`（须以 `<packageId>:` 开头且不可重复）、`type`、`slug`、`name`、`body`、
  `revision`；结构化字段放 `structured`。
- `relations` 枚举：`subclassOf` / `featureOf` / `spellOf` / `requires` / `replaces` /
  `related`，目标必须存在于同包。
- `rules.progression` 等级 1–20；选择键为 `{sourceEntryId}#{choiceId}`；非法或被篡改的
  选择进入 pending；规则应用递归且带环检测。
- `grant.kind` 枚举 12 项：`feature`、`proficiency`、`spell`、`equipment`、`resource`、
  `action`、`conditionResistance`、`speed`、`armorClass`、`hitPoints`、`ability`、`note`；
  `id` + `kind` 必填；`formula` 仅存储、不在客户端求值。
- `choice`：`id` + `optionType` 必填，`minimum` 默认 1、`maximum` 默认等于 `minimum`；
  `maximumOptionLevel` 0–9；`builderStep` ∈ `class` / `origin` / `abilities` /
  `proficiencies` / `equipment` / `spells` / `details`。
- 过滤语义：跨字段 AND、同字段多值 OR；`optionEntryIds` 白名单、`optionTags` 需全含、
  `subclass` 选项必须存在指向来源的 `subclassOf` 关系、`recommendedEntryIds` 需通过同一套
  过滤后 `take(maximum)`。

> `structured.itemTemplate` 只由私有提取脚本产出（**客户端不消费**）；客户端物品实例使用
> `id / templateRef / name / quantity / equipped / attuned / instanceData`。
> 规则声明的完整字段清单（含 `startingEquipmentChoice.maximum`、`preparedSpellcasting`、
> `structured.spellcasting`、classFeature 的 `classSlug`/`featureOf`/`subclassName`）见归档的
> v2 格式文档（`archive/content/`）。

### 9.2 自制内容与检索

- 客户端：自制内容与导入包**共用同一套类型注册与校验**（`ContentSchemaRegistry`，
  含类型/必填/数据类型/范围/枚举校验）。
- 服务端另有独立的 `CampaignEntryValidatorService`（校验更弱：非空、10 种区块类型、
  禁止 overlay 字段），仅用于战役私有条目。
- 检索支持类型、来源、标签、收藏等筛选；条目详情由区块渲染器呈现
  （标题/段落/列表/表格/引用/提示框/骰式/图片/关联条目）。

### 9.3 内置资料注入

- 公开构建 `apps/client_flutter/assets/bundled_content.json` 恒为 `{}`。
- 私有构建由脚本临时注入，构建后恢复（见 §13）。
- 安装器 `BundledContentInstaller` 读取该文件；空包直接跳过。

---

## 10. 设计与前端规范

### 10.1 设计契约

完整 token 与规范见 [`../DESIGN.md`](../DESIGN.md)。要点：

- 颜色全部来自 `ColorScheme.fromSeed`（用户可选种子色 + 高对比 + 动效变体），
  文字必须用匹配的 `on-*` 角色；`outline` 只作描边，不作正文色。
- 圆角：组件 `8dp`、对话框/弹层 `16dp`、聊天气泡胶囊 `24dp`（唯一例外）。
- 间距：4/8px 刻度（4/8/12/16/24/32/48），FAB 让位统一 96。
- 高度：扁平化（`elevation: 0`、`surfaceTint` 透明），仅 SnackBar 浮动。
- 组件：填充/抬升/文字/描边/tonal 按钮、chip 选中态 `onSecondaryContainer`、
  输入框统一走 `inputDecorationTheme`（8dp 填充式）、纯图标控件必须有 Tooltip、触达 ≥48dp。

### 10.2 共享组件

- `core/widgets/empty_state.dart`（统一空态）、`app_search_bar.dart`、`numeric_input_field.dart`
- `app/theme/app_theme.dart`（组件主题单一来源）、`app_text_styles.dart`（语义排版 token）、
  `core/presentation/dialog_sizes.dart`（对话框尺寸 token）

### 10.3 回归保护

| 手段 | 位置 |
|---|---|
| 主题契约测试 | `apps/client_flutter/test/app_theme_test.dart` |
| Golden 基线 | `apps/client_flutter/test/golden/`（默认跳过，CI 在 Linux 校验） |
| 设计 lint | `npm run lint:design`（官方 `@google/design.md`），CI `design` job |
| UI 审查记录 | 归档的 `design/design-audit.md`（约 430 个元素的审查与修复清单） |

---

## 11. 部署与运维

### 11.1 部署流程（唯一主流程）

```powershell
# 1) 本地生成部署包（需要 apps/server_nest/engines/，见 §13.5）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-linux-server-package.ps1
# 产物：dist/ohmydungeon-server-linux-0.1.0.tar.gz
```

```bash
# 2) 服务器上
tar xzf ohmydungeon-server-linux-0.1.0.tar.gz
cd ohmydungeon-server-linux-0.1.0
chmod +x start.sh stop.sh
./start.sh
```

`start.sh` 行为：`.env` 不存在则从 `.env.example` 创建 → 生成随机 `JWT_SECRET` /
`POSTGRES_PASSWORD` → 探测公网 IP 写入 `PUBLIC_BASE_URL` → `docker compose up -d --build`
→ 轮询 `/health`（30 次 × 2s）后宣告就绪并打印 `PUBLIC_BASE_URL`。

常用运维：

```bash
docker compose ps                 # 状态
docker compose logs -f server     # 日志
./stop.sh                         # 停止（保留数据卷）
docker compose down -v            # ⚠️ 删除数据卷（数据库与上传全部丢失）
```

### 11.2 升级

```bash
# 备份后（见 §11.4）
./stop.sh
tar xzf <新部署包>.tar.gz && cd <新目录>
cp ../<旧目录>/.env .             # 复用密钥与 PUBLIC_BASE_URL
chmod +x start.sh stop.sh && ./start.sh
```

镜像内启动命令为 `prisma migrate deploy && prisma db seed && node dist/main.js`，
因此升级会自动应用迁移。

### 11.3 数据库迁移

- `prisma/migrations/` 共 **18 个**目录：基线 `20260714000000_initial_schema`
  （一次性创建协作与 Vault 表），**3 个为 `SELECT 1;` 占位**（`campaign_sync_tables`、
  `campaign_collaboration`、`vault_and_actors`），另有若干 `ADD COLUMN IF NOT EXISTS` 前滚。
- 变更流程：改 `schema.prisma` → `prisma migrate dev` 生成迁移 → 本地验证 →
  提交迁移目录 → 部署时由容器 `migrate deploy` 应用。
- **不要**用 `prisma db push` 指向托管库；若库不是由 `migrate deploy` 建立，
  `migrate status` 会不同步。
- 排查：`npx prisma migrate status`（需 `DATABASE_URL`）。

### 11.4 备份与恢复

**必须备份**：PostgreSQL 数据卷 `postgres-data`、上传卷 `uploads`、`.env`（含密钥）。

```bash
# 数据库
docker compose exec -T postgres pg_dump -U dnd -d dnd_table > dnd_table_$(date +%F).sql

# 上传卷（命名卷，宿主机没有 uploads/ 目录，必须从卷导出）
docker run --rm -v ohmydungeon-server-linux-010_uploads:/data -v "$PWD":/backup alpine \
  tar czf /backup/uploads_$(date +%F).tar.gz -C /data .
# 卷名前缀来自 compose 项目名，先用 `docker volume ls` 确认

cp .env .env.backup_$(date +%F)
```

恢复：

```bash
./stop.sh
docker compose up -d postgres
docker compose exec -T postgres psql -U dnd -d dnd_table < dnd_table_2026-09-10.sql
docker run --rm -v ohmydungeon-server-linux-010_uploads:/data -v "$PWD":/backup alpine \
  sh -c 'rm -rf /data/* && tar xzf /backup/uploads_2026-09-10.tar.gz -C /data'
./start.sh
curl http://127.0.0.1:3000/health
```

注意：

- 丢失 `JWT_SECRET` 只会让已签发 token 失效，不影响数据。
- 恢复前确认部署包版本与新库 schema 兼容（必要时先应用迁移）。
- **客户端备份（`.ohmydungeon-backup`）与服务端备份是两件事**：前者由客户端
  「设置 → 数据管理」导出，仅含本地角色与资料；后者才是上述数据库/卷备份。
- 客户端备份格式：zip 内含 `manifest.json` + `database.json` + `assets/`，
  manifest 记录 `formatVersion: 1`、`createdAt`、`clientVersion`、`totalSize`、`sha256`
  与 `serverProfileCount` / `packageCount` / `entryCount` / `assetCount` / `characterCount`；
  恢复时在**单个事务内**清空并重建 10 张个人数据表，资源字节在事务提交后写入。
  战役缓存与同步状态**不在**备份范围内。

### 11.5 故障排查

| 症状 | 原因与处理 |
|---|---|
| 公网打不开 `/health` | ① 服务器防火墙放行（`ufw allow 3000/tcp`）；② **云安全组放行 TCP 3000**（实例访问自身公网 IP 也受安全组约束） |
| 服务端日志正常但客户端连不上 | `PUBLIC_BASE_URL` 不是客户端可达地址；改 `.env` 后重跑 `./start.sh` |
| 镜像构建失败于 `npm ci` | 服务器访问不到 npm 官方源；给 Dockerfile 的 `npm ci` 加镜像参数（`--registry=https://registry.npmmirror.com --replace-registry-host=always`） |
| 镜像构建失败于 `prisma generate` | 部署包缺 `apps/server_nest/engines/`；重新打包（脚本会提前报错） |
| 容器反复重启 | `docker compose logs --tail=200 server`；常见为数据库未就绪或 `.env` 缺密钥 |

### 11.6 反向代理

- 代理到 `127.0.0.1:3000`，需放行 WebSocket 升级路径 `/campaigns`。
- 对外建议使用 HTTPS，并把 `PUBLIC_BASE_URL` 设为该域名（客户端据此获得 `apiBaseUrl`）。
- 上传大小受 `MAX_UPLOAD_SIZE_MB` 限制，反代层需相应放大 body 限制。

---

## 12. 本地开发

### 12.1 环境

| 工具 | 版本 |
|---|---|
| Node.js | 22（`.nvmrc` / `.node-version`；`engines: >=22 <25`） |
| npm | 10+ |
| Flutter | stable `3.41.4`（CI golden job 固定该版本） |
| Python | 3（仅私有资料工具与脚本测试） |
| Docker | Engine + Compose v2（本地数据库/部署） |

### 12.2 初始化

```powershell
npm run setup          # = setup:server + setup:client
# 或
npm run bootstrap      # 服务端 install + prisma generate + flutter pub get
```

### 12.3 命令

| 命令 | 作用 |
|---|---|
| `npm run check` | **阶段门** = `lint:server` + `analyze:client` + `test` |
| `npm run doctor` | 额外校验：Drift 代码生成 + `docker compose config` |
| `npm run test` / `test:server` / `test:client` | 测试 |
| `npm run lint:server` / `analyze:client` | 静态检查 |
| `npm run lint:design` | `DESIGN.md` 契约 lint |
| `npm run test:scripts` / `test:phb-tools` | Python 脚本层测试 |
| `npm run validate:phb-private` | 私有 PHB 包验证 |
| `npm run dev:server` / `dev:client` / `preview:client` | 开发运行 |
| `npm run docker:up` / `docker:down` / `docker:logs` | 本地 PostgreSQL（**本地跑服务端前必须先起库**） |

> 不存在 `npm run lint` / `npm run format`。

### 12.4 代码生成

改动 Drift 表后必须重新生成：

```powershell
cd apps/client_flutter
dart run build_runner build --delete-conflicting-outputs
```

`npm run doctor` 会执行该步骤（CI 的 client job 不执行，因此提交前务必本地生成并提交产物）。

### 12.5 CI（`.github/workflows/ci.yml`，5 个 job）

| job | 内容 |
|---|---|
| `server` | Node 22 → `npm ci` → `npm run lint` → `npm test` |
| `client` | Flutter stable → `pub get` → `analyze` → `test` |
| `design` | `npm ci` → `npm run lint:design`（DESIGN.md 契约） |
| `golden` | 固定 Flutter `3.41.4` → `flutter test --tags golden --dart-define=GOLDEN_TESTS=true` |
| `docker` | `docker compose config`（仅校验编排，不构建镜像） |

---

## 13. 私有资料流水线

> 硬约束：公开仓库、公开构建与公开分发**不包含**商业规则正文。以下流程仅限本地自用。

### 13.1 目录

```text
private-imports/                       # Git 忽略
  phb-2024-v2/ + phb-2024-v2-bundle.json
  mm-2024-v1/  + mm-2024-v1-bundle.json
  dmg-2024-items-v1/ + dmg-2024-items-v1-bundle.json
  private-test-all-bundle.json         # 聚合中间产物
assets/bundled_content.json            # 公开构建恒为 {}
```

### 13.2 提取与校验

| 脚本 | 用途 |
|---|---|
| `python scripts/extract_phb_2024_v2.py` | 玩家手册 → v2 包 |
| `python scripts/extract_monster_manual_private.py` | 怪物图鉴 → 怪物包 |
| `python scripts/extract_dmg_2024_items.py` | 城主指南 → 物品包 |
| `python scripts/generate_phb_private_index.py` | 目录/页码索引（不含正文） |
| `python scripts/extract_phb_from_chm.py` | 旧 CHM 一次性提取（历史工具） |
| `python scripts/check_subclass.py` | 子职业数据完整性校验 |

```powershell
npm run validate:phb-private     # schema/引用/规则 + 真实 Flutter 导入
npm run test:scripts             # 脚本层单测
npm run test:phb-tools
```

### 13.3 私有客户端构建

```powershell
pwsh -File scripts/build_private_client.ps1 -Target apk -BuildArgs @(
  '--release',
  '--dart-define=BUNDLED_DEFAULT_SERVER=true',
  '--dart-define=DEFAULT_SERVER_BASE_URL=http://<host>:3000'
)
```

- `-Target`：`apk` / `web` / `windows` / `linux` / `macos`
- 流程：聚合三包 → 覆盖 `bundled_content.json` → `flutter build` → **finally 恢复 `{}`**
- 内嵌默认服务器由 `BundledDefaultServerSeeder` 消费（仅发布构建启用；测试与公开构建保持
  「无服务器」语义）
- 另有 `scripts/build-private-test-apk.ps1`（打包 APK 到 `dist/android/`）与
  `scripts/serve_private_web.py`（私有 Web 反代，5181 → 后端 3000）

### 13.4 服务端部署包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-linux-server-package.ps1
```

打包前会在缺少 `apps/server_nest/engines/` 时**立即失败**；产物为
`dist/ohmydungeon-server-linux-0.1.0.tar.gz`（含 compose、`.env.example`、`start.sh`、
服务端源码与 `engines/`）。

### 13.5 离线 Prisma 引擎

```powershell
cd apps/server_nest
npm ci
npx prisma generate
Copy-Item node_modules\@prisma\engines\schema-engine-linux-musl-openssl-3.0.x engines\
Copy-Item node_modules\@prisma\engines\libquery_engine-linux-musl-openssl-3.0.x.so.node engines\
```

> Windows 打包会丢失可执行位，`Dockerfile` 在构建与运行阶段各执行一次
> `chmod +x engines/*`；不要删除这两行。

### 13.6 合规检查清单

- [ ] `private-imports/`、`dist/` 未出现在 `git status`
- [ ] 构建后 `assets/bundled_content.json` 为 `{}`
- [ ] 私有产物未上传公开 Release / 镜像仓库 / 网盘
- [ ] 分享任何构建产物前确认不含规则正文

---

## 14. 工程规范

### 14.1 分层与目录

- **服务端**：`module`（装配）+ `controller`（HTTP）+ `service`（业务）+ `policy`（权限）
  + `*.types.ts`（类型与视图）；测试为并列的 `*.spec.ts`，部分模块另有 `domain/`。
  **没有** `repository.ts` / `dto/` / `events/` 目录约定。
- **客户端**：feature-first，`features/<name>/{data,domain,presentation}`；
  `core/` 放跨功能基础设施；UI 不直连数据库。

### 14.2 硬性约束

1. 读现有实现与测试后再改行为；行为变更先写失败测试（TDD）。
2. 通过业务服务修改状态并记录结构化事件；UI 与未来 Agent 使用同一套查询/操作服务。
3. 权限判断只经 `policy`，写操作必须调用对应 `can*`。
4. 复用 Material 3 主题与共享组件，遵守 `DESIGN.md` 契约。
5. 未完成功能必须隐藏，不暴露占位入口。
6. 删除代码前必须完成引用与静态分析审计。
7. 不覆盖工作树中来源不明的改动。

### 14.3 提交与版本

- Conventional Commits，中文正文：`feat(0.1): …` / `fix(0.1): …` / `docs(0.1): …` /
  `refactor(0.1): …` / `chore(0.1): …`
- 对外版本只有 `0.1.0`；不为未发布能力预先开新版本线。
- **PowerShell 脚本若含中文注释，必须保存为带 UTF-8 BOM**，否则 Windows PowerShell 5.1
  会按 ANSI 解析并报错。

### 14.4 测试策略

- 客户端：`flutter test`（widget/单元）、契约测试、golden（CI 校验）。
- 服务端：`jest` 单元 + `supertest` e2e。
- 脚本：`python -m unittest`（`npm run test:scripts`）。
- 私有内容：`npm run validate:phb-private`（不进公开 CI）。

---

## 15. Agent 协作规范

### 15.1 必读顺序

`README.md` → `docs/README.md`（本文件）→ `AGENTS.md` → 涉及 UI 时 `DESIGN.md`。

### 15.2 当前边界（不得越界）

- 对外版本统一 `0.1`；领域用 Character，不新增 Actor 产品接口。
- 战役是长期工作区，不恢复 Room/Session 前置流程。
- 客户端离线优先；只有战役协作与 Vault 同步需要服务器。
- UI 与未来 Agent 共用查询/操作服务，不直写数据库。
- 不实现战斗系统、AI Agent 运行时、通用 TRPG 引擎。
- 商业规则正文不得进入公开仓库或公开构建；`private-imports/` 仅供本地验证。

### 15.3 阶段收口验证

```powershell
npm run check
npm --prefix apps/server_nest run build
$env:DATABASE_URL='postgresql://dnd:dnd@localhost:5432/dnd_table?schema=public'
Push-Location apps/server_nest; npx prisma validate; Pop-Location
git diff --check
```

私有内容只使用专用脚本：`npm run validate:phb-private`、
`pwsh -File scripts/build_private_client.ps1 -Target web -BuildArgs --release`。

---

## 16. 当前状态与验收基线

**版本** `0.1` · **更新时间** `2026-09-10`

### 已完成能力

本地私人工作区（每账号隔离）、服务器实例身份与备注、离线账号恢复与旧数据迁移；
本地角色与战役角色发布/绑定/DM 管理；战役主聊/私聊/小群/未读/档案/增量同步；
资料库（内容包、自制内容、检索、阅读）；角色 Markdown v2 与自动镜像、外部变更确认；
结构化怪物模板、物品、状态、资源；检定请求；Vault 同步；
Material 3 设计系统契约（`DESIGN.md` 与契约测试/golden）；自托管 Docker 部署
（离线 Prisma 引擎 + 部署包脚本）。

### 实测基线（2026-09-10）

| 项 | 结果 |
|---|---|
| `flutter analyze` | 0 问题 |
| `flutter test` | 864 通过 / 5 跳过（3 golden 默认跳过 + 2 私有路径） |
| 服务端 `npm run lint` + `npm test` | 24 套件 / 351 测试通过，0 跳过 |
| `npm run test:scripts` | 27 通过（4 个脚本测试套件） |
| `npm run lint:design` | 0 error / 0 warning（1 条 token 统计 info） |
| 自托管部署 | Docker Compose 下 `/health` 与 `/.well-known/dnd-tool-server` 验证通过 |

### 下一步

先基于真实使用反馈建立新规格，再从当前边界内推进；不得从历史版本线继续顺序开发，
也不得恢复已隐藏的战斗、Room、Session 或旧 Actor 入口。

---

## 17. 归档说明

- 2026-07-29：100 份旧路线、Agent prompt、交接报告、计划与规格移入 `archive/`。
- 2026-09-10（本轮）：文档收敛为**本文件一份**，其余全部归档：
  - `archive/architecture/`、`archive/content/`、`archive/deployment/`、
    `archive/development/`、`archive/engineering/`、`archive/acceptance/`、
    `archive/roadmap/`、`archive/design/`、`archive/agents/`
  - 归档内容仅用于追溯，**不得**作为当前接口或待办依据。
- 已删除的代码：`features/encounters`（客户端）、`modules/encounters` 与 `modules/media`
  （服务端，未挂载）、旧战役内容编辑器与 JSON 导入对话框、空的 `check_requests` 目录。
  服务端 `Session`/`ChatMessage`/`Encounter` 等 Prisma 模型保留以兼容历史数据，
  但无运行时代码使用。
