# 离线数据与同步边界

更新时间：2026-07-16

本文档定义 `0.1` 开发线下客户端、Personal Vault 与战役协作三条数据流的边界。所有跨端同步实现都必须遵守本文约定，不得在公开仓库、默认数据库或客户端安装包中内置 SRD/PHB 或任何受版权保护的官方规则正文。

## 1. 总体原则

- **离线优先**：客户端基于 Drift 的本地数据库是唯一事实来源。未配置服务器、未登录或断网时，资料库、角色、收藏、笔记、设置、规则计算和本地备份必须完整可用。
- **服务器可选**：服务器只承担跨设备同步和战役联机，不作为本地功能的门禁。`MainShell` 始终打开，未登录时显示「同步可选」提示。
- **私有资料显式导入**：客户端不声明、编译或自动加载 `assets/private/`。用户持有的商业规则资料包只能从「设置 → 资料包」手动导入 Drift；新安装的资料库默认为空。
- **正文永不上传**：本地资料包正文与 assets 永远不进入 Vault payload，也不进入战役同步。Vault 只同步个人实体和资料包 manifest（`id/version/locale/system/contentHash`），战役只同步 DM 创建的独立 JSON 条目。
- **不信任客户端身份**：聊天身份必须绑定 `CampaignActor`，服务器以 `campaignActorId` 为准，不接受客户端 displayName 作为权威来源。
- **WebSocket 仅广播游标**：实时通道只推送最新 cursor 和 entityType，完整实体通过 HTTP `changes` 端点拉取，避免信任客户端增量。

## 2. 本地数据层（Drift）

`AppDatabase` 的 `schemaVersion = 6`，跨平台（Native SQLite + Web WASM）。表分为三组：

### 2.1 个人数据（10 张表）

`ServerProfiles`、`LocalContentPackages`、`LocalContentEntries`、`LocalContentAssets`、`ContentLinks`、`ContentFavorites`、`ContentNotes`、`ContentReadHistory`、`Characters`、`CharacterContentRefs`。

这组表是离线优先的根：所有个人角色、资料库、收藏、笔记和服务器 profile 都驻留在此，可被本地备份导出。

### 2.2 Vault 同步（Outbox + Cursor）

`VaultOutbox`、`VaultCursors`、`VaultDevices`、`VaultSyncConflicts`。个人实体在本地写入时原子入队 Outbox；同步服务按 push → pull → apply → save cursor 的固定顺序执行；409 转为冲突态，网络异常保留 Outbox 并增加重试计数。

### 2.3 战役缓存（5 张表）

`CampaignActorsCache`、`CampaignActorBacklinks`、`CampaignContentCache`、`CampaignSyncCursors`、`CharacterSyncConflicts`。这组表只是远端战役的本地镜像，离线可读，可在「设置 → 数据管理」一键清理，不进入个人备份。

## 3. Personal Vault 同步

### 3.1 实体类型

`character`、`contentFavorite`、`contentNote`、`preference`、`contentPackageManifest`。

`contentPackageManifest` 的 payload 仅含 `id / version / locale / system / contentHash`，用于跨设备告知「这台设备装过这个资料包」，正文与 assets 永远不进 payload。

### 3.2 服务端 API

- `POST /api/vault/push`：客户端推送 Outbox，按 `(userId, entityType, entityId)` 唯一约束 upsert，revision 单调递增；提供 `operationId` 实现幂等。
- `GET /api/vault/changes?cursor=&limit=`：按 `VaultChange.cursor` 单调分页返回远端变化。
- `POST /api/vault/devices` / `GET /api/vault/devices` / `DELETE /api/vault/devices/:id`：设备注册、列表、撤销；撤销写入 tombstone，cursor 不再前进。
- 冲突返回 HTTP 409 与当前 `revision`，客户端转人工冲突态，不自动覆盖。

### 3.3 客户端流程

1. 用户在本地任意操作 → 个人实体写入 Drift → 同步事件原子入队 `VaultOutbox`。
2. 后台或手动触发 → `VaultSyncService` 执行 push → pull → apply → save cursor。
3. push 失败：保留 Outbox，标记 `attempts++`，按指数退避重试。
4. pull 阶段按 cursor 分页拉取远端变化，逐条 merge 进本地；409 写入 `VaultSyncConflicts` 由用户决策。

## 4. 战役协作同步

### 4.1 服务端数据模型

- `CampaignSyncState`：每战役一行，记录当前 cursor。
- `CampaignChange`：每条变更一行，`(campaignId, cursor)` 唯一，含 `entityType / entityId / operation / revision`。
- `CampaignActor`：战役角色实体，含 `sheetJson`、`revision`、`ownerUserId`、`sourceCharacterId`、`updatedBy`。
- `CampaignActorAudit`：Actor 的每次修改审计，含 `baseRevision / resultRevision / changedPaths / beforeJson / afterJson`。
- `CampaignContentEntry`：DM 创建的独立 JSON 条目，`(campaignId, slug)` 唯一，含 `type / name / entryJson / revision / deletedAt`。
- `CampaignChatMessage`：聊天消息，持久化 `campaignActorId`，不信任客户端 displayName。

### 4.2 同步边界

- **只同步 DM 创建的独立 JSON 条目**：`CampaignContentEntry` 是独立条目，不存在 overlay / patch / 依赖选项 / 公共包市场。
- **玩家发布角色形成完整 CampaignActor**：本地角色发布时把整张角色卡快照写入 `CampaignActor.sheetJson`，owner/DM 都有完整编辑权。
- **owner/DM 编辑权**：所有修改记录在 `CampaignActorAudit`，revision 单调递增，客户端冲突可见、可回滚。
- **资料正文不进入战役同步**：`CampaignContentEntry.entryJson` 是 DM 自己写的独立条目，不会引用本地资料包正文；客户端在 Wiki 检索时把本地包和战役缓存合并显示，同名不覆盖，来源 chip 标注「本地」/「战役」。

### 4.3 客户端缓存流程

1. 用户进入战役 → 客户端拉取 `GET /api/campaigns/:id/changes?cursor=0` 增量。
2. 每条 change 按 `entityType` 路由到 `CampaignActorsCache` 或 `CampaignContentCache`，更新 `CampaignSyncCursors`。
3. 离线时只能读缓存，不能写战役；写入必须等到联网后通过 HTTP 提交。
4. WebSocket 仅广播 `{ campaignId, cursor, entityType }`，客户端收到后用 HTTP `changes` 拉取完整实体。

### 4.4 聊天身份

- 客户端发送消息时携带 `campaignActorId`，服务端以此为准；displayName 只是缓存字段，不可作为权威。
- 消息持久化在 `CampaignChatMessage`，与 `CampaignActor` 软关联（`onDelete: SetNull`），Actor 被删除时消息保留但 Actor 引用置空。
- 资料引用以快照形式写入消息，避免本地资料包被删除后聊天失去上下文。

## 5. 本地备份与恢复

### 5.1 归档格式

`.dndtable-backup` 是 ZIP 文件，包含：

- `manifest.json`：`formatVersion=1`、`createdAt`、`clientVersion`、计数（角色 / 资料包 / 条目 / 收藏 / 笔记 / assets）、`totalSize`、`sha256`（`database.json` 的 SHA-256）。
- `database.json`：10 张个人数据表的序列化 JSON。
- `assets/<packageId>/<relativePath>`：资料包二进制资源。

### 5.2 不进入备份的内容

- 任何 token、密码或会话凭据。
- 战役缓存（5 张表）—— 可单独清理，但不属于个人数据。
- Vault Outbox、Vault Cursors、Vault Devices、Vault Sync Conflicts —— 同步状态不属于数据备份。
- `CharacterContentRefs` 的快照字段会随角色一起导出，但不导出资料包正文（用户需要自行保管 `.dndpack` 包）。

### 5.3 恢复流程

1. 用户在「设置 → 数据管理」选择 `.dndtable-backup` 文件。
2. `DriftLocalDataArchiveService.previewArchive` 解码 ZIP、读取 manifest、校验 `database.json` 的 SHA-256，返回 `ArchivePreview`。
3. UI 显示预览（角色数、资料包数、总大小、版本、错误），仅在 `preview.valid` 时启用「确认恢复」。
4. 用户二次确认 → `restoreArchive` 在单事务内清空 10 张个人表并按 JSON 重新插入，然后更新 assets 字节。
5. 战役缓存和同步游标不受影响；用户恢复后需要重新登录服务器（token 不在备份里）。

### 5.4 其他维护操作

- **清理战役缓存**：单事务删除 5 张战役缓存表，用于「战役数据异常 / 切换战役 / 隐私清理」场景。
- **重建资料索引**：当前实现是 no-op，因为资料检索使用 LIKE 查询而非外部 FTS 索引；保留入口以便未来切换到 FTS5 时复用 UI。

## 6. 边界速查表

| 数据 | 存储 | Vault 同步 | 战役同步 | 本地备份 |
|------|------|------------|----------|----------|
| 个人角色 | Drift `Characters` | ✅ `character` | 发布后形成 `CampaignActor` | ✅ |
| 资料包正文 | Drift `LocalContentEntries` | ❌ | ❌ | ✅ |
| 资料包 manifest | Drift `LocalContentPackages` | ✅ `contentPackageManifest` | ❌ | ✅ |
| 资料包 assets | Drift `LocalContentAssets` | ❌ | ❌ | ✅ |
| 收藏 / 笔记 | Drift `ContentFavorites` / `ContentNotes` | ✅ | ❌ | ✅ |
| 偏好 | Drift `AppPreferences` | ✅ `preference` | ❌ | ✅ |
| 服务器 profile | Drift `ServerProfiles` | ❌（按设备本地） | ❌ | ✅ |
| Vault Outbox / Cursor | Drift | ❌ | ❌ | ❌ |
| 战役 Actor 缓存 | Drift `CampaignActorsCache` | ❌ | ✅ | ❌ |
| 战役 ContentEntry 缓存 | Drift `CampaignContentCache` | ❌ | ✅ | ❌ |
| 战役聊天消息 | 服务端 `CampaignChatMessage` | ❌ | ✅ | ❌ |
| Token / 密码 | 系统安全存储 | ❌ | ❌ | ❌ |

## 7. 验证清单

- 未配置服务器、未登录和断网时，个人角色、资料库、收藏、笔记、设置、规则计算、本地备份与恢复完整可用。
- Player 角色页只管理本地个人角色；DM 角色页管理所选战役 Actor，并具备完整编辑权和审计。
- 本地角色发布后形成完整 `CampaignActor`，revision 冲突可见，DM 变更可同步回玩家。
- 战役只同步 DM 新增的独立 JSON 条目；玩家可离线读取缓存，不存在资料包覆盖或依赖选项。
- Wiki 同时检索本地包和当前战役缓存，来源明确且同名不覆盖。
- 聊天身份绑定 `CampaignActor`，支持说/做、头像角色卡、资料引用快照和离线历史。
- 公开仓库、默认数据库和客户端安装包不含 SRD 或官方规则正文。
- `npm run doctor` 与 `flutter build web` 使用新鲜输出通过。
