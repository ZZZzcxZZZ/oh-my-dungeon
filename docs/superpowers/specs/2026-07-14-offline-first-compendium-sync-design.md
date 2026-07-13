# 离线优先资料库、角色与战役同步设计

状态：已确认设计，等待实施计划

日期：2026-07-14

适用版本：`0.1`

## 1. 目标

将客户端重构为真正的离线优先应用：资料库、角色卡、规则计算、收藏、笔记和设置在未配置服务器、未登录或断网时仍可完整使用。服务器只承担跨设备同步与战役协作，包括聊天、战役角色、DM 自定义条目和实时状态。

资料库应提供接近完整产品的 Wiki 体验，但公开仓库、公开构建和测试夹具不携带任何 SRD、PHB 或其他官方规则正文。资料库首次启动为空，由用户在设置中从本地文件导入内容。

## 2. 已确认的产品决策

1. 客户端不内置任何规则资料，空资料库是合法且必须测试的首启状态。
2. 本地基础资料包只保存在当前设备，不上传服务器，也不通过战役同步。
3. 用户可以从设置页导入、启用、停用、升级、导出和删除本地资料包。
4. 跨设备同步覆盖角色、设置、收藏、笔记和个人自定义条目；大型本地基础资料包正文不跨设备上传。
5. DM 创建战役时以及战役进行中都可以管理战役自定义条目。
6. 战役只同步 DM 新增的独立 JSON 条目，不同步本地基础资料，不提供基础条目覆盖、补丁、依赖或勘误机制。
7. DM 是战役自定义条目的唯一写入者，Player 只读。
8. Player 模式的角色页管理用户自己的角色；DM 模式的角色页按战役管理玩家角色、未认领角色和 NPC。
9. 玩家将本地角色发布到战役后形成 `CampaignActor`。DM 对 `CampaignActor` 拥有完整编辑权，修改必须有审计记录并同步回玩家本地角色。
10. 应用不再要求先添加服务器才能进入。服务器配置和登录是可选的同步与协作能力。

## 3. 非目标

- 不在仓库、Release、CI 产物或 Docker 镜像中保存非授权官方正文。
- 不提供官方资料下载地址、共享市场或自动抓取远程受版权保护内容的功能。
- 不让战役 JSON 条目覆盖玩家本地基础资料。
- 不实现资料包依赖树、差量补丁、翻译层、勘误层或包签名市场。
- 不把服务器变成角色卡、资料库或规则计算的运行前提。
- `0.1` 不实现多人同时编辑同一 Wiki 条目。

## 4. 产品边界

### 4.1 无服务器时可用

- 启动应用和切换 Player/DM 模式。
- 导入与管理本地资料包。
- 浏览、检索、筛选、收藏和记录阅读历史。
- 创建、编辑、升级、复制、导入和导出角色。
- 使用本地内容完成角色创建、装备与法术管理。
- 进行本地骰点和规则计算。
- 导出与恢复客户端备份。

### 4.2 需要服务器时可用

- 注册、登录与跨设备个人 Vault 同步。
- 创建、加入和管理战役。
- 战役聊天室、在线状态、实时骰点和系统事件。
- 发布本地角色为战役角色。
- DM 查看和编辑战役角色。
- 同步 DM 创建的战役自定义 JSON 条目。
- 同步战役资料链接、角色状态和审计记录。

### 4.3 核心原则

> 客户端是功能主体，服务器只负责跨设备同步和战役协作。页面读取本地数据库，网络同步不得成为个人功能的前置条件。

## 5. 总体架构

```text
Flutter UI
    |
Application Services / Use Cases
    |
Repository interfaces
    |-- Local data sources (Drift, source of truth)
    |-- Personal vault sync adapter (optional)
    |-- Campaign collaboration adapter (optional)
    `-- Realtime gateway (campaign only)
             |
        NestJS / PostgreSQL / WebSocket
```

Flutter 官方推荐 Repository 作为离线优先功能的统一访问点。本项目采用本地数据库作为 UI 的直接事实来源，远端变化先合并到本地数据库，再由响应式查询刷新 UI。

### 5.1 依赖规则

- Presentation 只能依赖 Application 和只读 View Model。
- Application 只能依赖 Domain 与 Repository 接口。
- Local/Remote Data Source 实现 Repository 接口，不得被页面直接调用。
- Domain 不得导入 Flutter、HTTP、WebSocket、Prisma 或 Drift。
- `apiBaseUrl`、Access Token 和 HTTP Client 不得出现在资料库、角色编辑器或规则计算 API 中。
- 网络失败只能改变同步状态，不能清空本地可用数据。

### 5.2 客户端启动

启动顺序固定为：

1. 初始化 Drift 数据库并执行迁移。
2. 加载本地设置和客户端身份。
3. 进入本地 Main Shell。
4. 若配置了默认服务器，在后台恢复登录和同步；失败时显示离线状态，不阻塞启动。
5. 未配置服务器时，战役页显示协作功能说明和添加服务器入口，其他标签保持可用。

## 6. 本地持久化

采用 Drift + SQLite。Native 平台使用本地 SQLite 文件；Web 使用 WASM SQLite，并根据浏览器能力保存到 OPFS 或 IndexedDB。

SharedPreferences 仅保留启动前必须读取的小型标志。角色、资料、收藏、同步队列和服务器配置均迁入 Drift。

### 6.1 本地表

#### `local_content_packages`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | text PK | 稳定包 ID |
| `name` | text | 显示名称 |
| `version` | text | SemVer |
| `locale` | text | BCP-47，例如 `zh-CN` |
| `system` | text | 例如 `dnd5e-2024` |
| `enabled` | bool | 是否进入检索和选择器 |
| `sourceFileName` | text nullable | 原始文件名 |
| `contentHash` | text | 导入内容 SHA-256 |
| `entryCount` | int | 条目数量 |
| `importedAt` | datetime | 导入时间 |
| `updatedAt` | datetime | 最近升级时间 |

#### `local_content_entries`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | text PK | 稳定条目 ID |
| `packageId` | text FK | 所属本地包 |
| `type` | text | 条目类型 |
| `slug` | text | 包内稳定 slug |
| `name` | text | 主名称 |
| `aliasesJson` | text | 别名数组 |
| `summary` | text | 列表摘要 |
| `bodyJson` | text | 安全内容块数组 |
| `structuredJson` | text | 类型专属字段 |
| `tagsJson` | text | 标签数组 |
| `sourceJson` | text | 来源元数据 |
| `revision` | int | 本地包修订号 |
| `searchText` | text | 标准化检索文本 |

唯一约束：`(packageId, slug)`。

#### `content_links`

| 字段 | 类型 | 说明 |
|---|---|---|
| `sourceEntryId` | text | 来源条目 |
| `targetEntryId` | text | 目标条目 |
| `relation` | text | `feature`、`spell`、`prerequisite` 等 |
| `label` | text | 显示文本 |

唯一约束：`(sourceEntryId, targetEntryId, relation)`。

#### 其他本地表

- `content_favorites(userLocalId, entryKey, createdAt)`
- `content_notes(id, userLocalId, entryKey, markdown, updatedAt, syncRevision)`
- `content_read_history(userLocalId, entryKey, lastOpenedAt, openCount)`
- `characters(id, ownerLocalId, sheetJson, revision, createdAt, updatedAt)`
- `character_content_refs(characterId, slot, entryKey, snapshotJson, sourceRevision)`
- `campaign_cache(id, serverProfileId, name, role, lastSyncedAt)`
- `campaign_actor_cache(id, campaignId, ownerUserId, actorJson, revision, syncState)`
- `campaign_content_cache(id, campaignId, entryJson, revision, deletedAt)`
- `sync_outbox(id, scope, entityType, entityId, baseRevision, payloadJson, createdAt, attempts)`
- `sync_cursors(scope, remoteId, cursor, updatedAt)`
- `server_profiles(id, name, baseUrl, accountId, lastConnectedAt)`

## 7. 本地资料包规范 v1

### 7.1 文件形式

支持两种等价导入形式：

1. 单文件 `*.content.json`，用于纯文本资料。
2. `*.dndpack` ZIP，用于包含图片等资源的资料。

`.dndpack` 目录固定为：

```text
manifest.json
entries.json
assets/
```

不允许 ZIP 中出现绝对路径、`..` 路径穿越、可执行文件或嵌套压缩包。

### 7.2 `manifest.json`

```json
{
  "formatVersion": 1,
  "id": "com.example.rules.zh-cn",
  "name": "示例规则资料",
  "version": "1.0.0",
  "locale": "zh-CN",
  "system": "dnd5e-2024",
  "description": "用户自行导入的本地资料",
  "entryCount": 2
}
```

必填字段为 `formatVersion`、`id`、`name`、`version`、`locale`、`system`、`entryCount`。`formatVersion` 在 `0.1` 只接受整数 `1`。

### 7.3 `entries.json`

```json
[
  {
    "id": "com.example.rules.zh-cn:class/fighter",
    "type": "class",
    "slug": "fighter",
    "name": "战士",
    "aliases": ["Fighter"],
    "summary": "精通武器与战术的职业。",
    "body": [
      {"type": "heading", "level": 2, "text": "职业特性"},
      {"type": "paragraph", "text": "正文内容"},
      {
        "type": "entryLink",
        "targetId": "com.example.rules.zh-cn:feature/action-surge",
        "text": "动作如潮"
      }
    ],
    "structured": {
      "hitDie": "d10",
      "primaryAbility": ["strength", "dexterity"],
      "levelFeatures": [
        {
          "level": 2,
          "entryId": "com.example.rules.zh-cn:feature/action-surge"
        }
      ]
    },
    "tags": ["class"],
    "source": {"label": "本地资料", "page": 1},
    "revision": 1
  }
]
```

### 7.4 安全内容块

允许的 `body` 类型：

- `heading`：`level` 只允许 2 至 4。
- `paragraph`：纯文本，可包含受限 Markdown 行内标记。
- `list`：有序或无序文本项。
- `table`：纯文本表头与单元格。
- `quote`：引用文本。
- `callout`：`info`、`warning`、`rule` 三种样式。
- `image`：只允许相对 `assets/` 路径及替代文本。
- `statBlock`：结构化属性列表。
- `entryLink`：指向稳定条目 ID。
- `diceExpression`：经骰点解析器校验的表达式。

禁止任意 HTML、JavaScript、外部 iframe、远程脚本和 `data:` URL。

### 7.5 条目类型

`0.1` 内置类型定义而不内置内容：

- `class`
- `subclass`
- `classFeature`
- `species`
- `background`
- `feat`
- `spell`
- `equipment`
- `item`
- `condition`
- `rule`
- `monster`
- `custom`

每种类型由 `ContentTypeDefinition` 注册字段校验器、列表摘要、详情区块、筛选器和角色创建适配器。新增类型不得修改资料库核心查询和路由。

### 7.6 导入事务

导入必须按以下顺序在单个本地事务内完成：

1. 解析容器并验证大小、文件路径和 JSON。
2. 验证 manifest 与条目 schema。
3. 验证包内 ID 唯一性和内部链接。
4. 计算内容哈希并生成预览报告。
5. 用户确认后写入包、条目和链接。
6. 重建该包的本地搜索索引。
7. 写入导入历史。

任一步失败都不得留下半个资料包。

升级同 ID 资料包时，先保留自动快照；成功后替换该包条目。收藏、笔记和角色引用按稳定条目 ID 保留。缺失条目引用继续使用角色快照并标记来源不可用。

## 8. Wiki 产品设计

### 8.1 资料库首页

- 空状态：导入资料包、创建个人条目、打开格式帮助。
- 有内容时：搜索栏、类型分类、资料包入口、收藏、最近阅读。
- 顶部不显示服务器连接要求。

### 8.2 检索

搜索范围包括名称、别名、摘要、正文、标签和来源。支持类型、资料包、语言、职业、等级、环阶、学派与收藏筛选。

中文索引同时保存原文、标准化英文和拼音首字母；排序依次考虑精确名称、别名前缀、名称包含、正文命中和最近使用。

### 8.3 条目详情

- 标题、类型、来源与收藏。
- 页面内目录和章节锚点。
- 类型专属结构化信息。
- 安全内容块正文。
- 关联条目和反向链接。
- 个人笔记。
- 复制链接、发送到战役和加入角色的上下文操作。

宽屏使用列表/详情双栏，窄屏使用列表到详情路由。详情不是 AlertDialog。

### 8.4 职业详情

- 概览页显示生命骰、主要属性、豁免和熟练。
- 等级表固定显示 1 至 20 级。
- 特性按等级分组，每项链接到独立 `classFeature` 条目。
- 子职、推荐法术和相关专长显示为关联列表。
- 缺少分级信息的特性放入“其他特性”，不静默丢弃。

### 8.5 资料包管理

设置页提供：

- 从文件导入。
- 导入前预览条目数、类型统计和错误。
- 启用或停用。
- 从新文件升级。
- 导出原始包或个人自制包。
- 删除并显示受影响的角色引用、收藏和笔记数量。
- 显示数据库空间占用和最近备份时间。

## 9. 角色模型与模式语义

### 9.1 Player 模式

角色页展示当前用户的本地角色，按最近使用、战役和归档状态筛选。角色创建、编辑和运行时状态先写本地数据库。

角色引用资料条目时同时保存：

- `entryKey`
- `sourceRevision`
- 影响角色的必要 `snapshot`

因此删除资料包不会让角色卡无法打开。

### 9.2 DM 模式

角色页首先选择战役，然后展示：

- 玩家角色
- 未认领角色
- NPC
- 随从或召唤物
- 已死亡、退休或归档角色

DM 可以查看和编辑完整战役角色，执行 HP、临时生命、状态、资源、装备、法术和备注修改。所有修改写入审计日志。

### 9.3 `CampaignActor`

玩家把本地角色发布到战役时创建完整战役副本：

```text
CampaignActor
  id
  campaignId
  ownerUserId
  sourceCharacterId
  actorType
  status
  sheetJson
  revision
  updatedBy
  createdAt
  updatedAt
```

聊天室消息只引用 `campaignActorId`，显示信息来自战役 Actor 的当前缓存。

### 9.4 角色同步和冲突

- 本地角色和战役 Actor 均有单调递增 `revision`。
- 上传必须携带 `baseRevision`。
- 修订一致时接受写入并返回新版本。
- 修订不一致时返回当前服务端版本和冲突字段。
- HP、临时生命、状态和资源使用按服务端时间顺序应用的运行时命令，不进行整张表覆盖。
- 构建字段发生冲突时保留双方版本，玩家进入角色页时显示比较确认。
- DM 修改拥有战役内最终权限，但不能删除玩家的本地角色。
- 退出或删除战役只解除绑定，本地角色继续存在。

## 10. 个人 Vault 跨设备同步

个人 Vault 是可选能力。未登录时所有功能继续工作。

### 10.1 同步范围

- 角色和角色运行状态。
- 个人自定义条目。
- 收藏、笔记和书签。
- 应用设置。
- 本地资料包安装清单：只包含 ID、版本、语言和哈希，不包含条目正文或资源。

### 10.2 不同步范围

- 导入的本地基础资料包正文和资源。
- 本地导入源文件。
- 临时搜索索引和阅读缓存。

新设备恢复 Vault 后，若角色引用的资料包未安装，角色仍通过快照可用，并在设置中列出缺失包 ID 与版本。

### 10.3 同步协议

- 每个用户拥有独立 cursor。
- 客户端先推送 Outbox，再从 cursor 拉取远端变化。
- 每批提交使用幂等 `operationId`。
- 服务端保留删除 tombstone，直到所有活跃设备 cursor 越过删除修订或超过保留期。
- 默认后台同步；设置页提供立即同步、暂停同步和查看错误。

## 11. 战役自定义 JSON 条目

### 11.1 范围

战役自定义条目是独立条目，不能覆盖或修改玩家本地资料。条目 ID 使用服务器生成 UUID；可通过普通 Wiki 链接关联其他战役条目，但不能假设所有成员都安装了同一基础包。

### 11.2 创建入口

- 创建战役向导中的“自定义资料”步骤。
- 战役设置中的“战役资料”页面。
- 战役聊天室 `+` 菜单中的“创建资料条目”。

DM 可以使用 GUI 表单创建条目，也可以粘贴单条或多条 JSON。导入前必须 dry-run 并显示错误。

### 11.3 权限

- Campaign owner 与 DM：创建、编辑、删除、排序和发布。
- Player：读取和缓存。
- 非成员：不可访问。
- Server admin 不自动出现在产品 UI 中，但可按服务器运维策略访问数据库。

### 11.4 同步模型

服务端保存：

```text
CampaignContentEntry
  id
  campaignId
  type
  slug
  name
  entryJson
  revision
  createdBy
  updatedBy
  createdAt
  updatedAt
  deletedAt
```

唯一约束：`(campaignId, slug)`。

同步端点：

- `GET /api/campaigns/:id/content/changes?cursor=`
- `POST /api/campaigns/:id/content/entries/validate`
- `POST /api/campaigns/:id/content/entries`
- `PUT /api/campaigns/:id/content/entries/:entryId`
- `DELETE /api/campaigns/:id/content/entries/:entryId`

变化流返回 `upsert` 或 `delete`，每项包含 campaign cursor 和 entry revision。客户端合并到 `campaign_content_cache` 后再刷新 Wiki。

WebSocket 只广播“内容已变化”和最新 cursor，不广播完整正文；客户端通过 HTTP 拉取，避免断线丢失。

## 12. 战役聊天集成

- 聊天身份必须绑定 `CampaignActor`。
- 点击头像在 Player 模式显示允许查看的信息，在 DM 模式打开完整可编辑角色卡。
- 输入 `[[` 搜索本地资料和当前战役缓存条目。
- 资料卡消息保存 `entryKey`、名称快照、摘要快照和可选骰点表达式。
- 接收方找不到本地条目时仍显示快照，不出现空白消息。
- DM 自定义条目通过同步缓存后可完整打开。
- 聊天、骰点和在线状态需要网络；历史消息使用本地缓存提供只读离线浏览。

## 13. 设置与导航

### 13.1 设置页

新增分组：

- `本地资料库`：导入、管理、空间和备份。
- `同步`：账户、同步状态、暂停、立即同步和设备列表。
- `服务器`：添加、编辑、测试和删除服务器 Profile。
- `数据`：完整备份、恢复、清空缓存和重建索引。

### 13.2 导航语义

Player 模式：`首页 / 战役 / 角色 / 资料库 / 设置`。

DM 模式：`首页 / 战役 / 角色 / 资料库 / 设置`，但角色页变为当前战役 Actor 管理，首页突出最近战役和同步异常。

模式切换不改变底层数据所有权，只改变任务入口和默认视图。

## 14. 错误处理

- 数据库初始化失败：显示可恢复错误页，允许导出诊断和重试，不显示空白页。
- 资料包无效：保持原数据库不变，显示精确 JSON 路径和错误原因。
- Web 持久化不可用：明确提示当前会话可能丢失数据，并提供立即导出。
- 服务器离线：Outbox 保留，页面继续使用本地数据。
- 身份过期：暂停远端同步，不删除本地数据。
- 战役权限被撤销：隐藏远端战役，保留只读缓存直到用户选择清理。
- 同步冲突：状态中心显示实体、双方版本和可执行解决动作。
- 缺少本地资料包：角色使用快照，Wiki 链接显示缺失来源，不自动联网下载。

## 15. 安全与隐私

- 导入器限制解压后总大小、单文件大小、文件数量和路径。
- JSON 使用显式 schema 校验，不进行动态代码执行。
- 图片解码失败不得影响其他条目导入。
- Token 使用平台安全存储；Web 端遵循现有可用安全边界并避免写入普通日志。
- 服务端所有战役与 Vault 端点执行用户和战役权限校验。
- 审计日志记录 DM 对角色和战役条目的写操作。
- 日志不得输出角色整表、资料正文、访问令牌或导入文件内容。

## 16. 从当前实现迁移

当前客户端把主界面绑定到 Server Profile，并通过 `ContentApiClient` 和远端 `ContentController` 读取资料。迁移必须分阶段进行，禁止一次性删除现有 API。

### 阶段 A：离线外壳与本地数据库

- 引入 Drift 和数据库迁移测试。
- 取消 Server Profile 启动门禁。
- 将服务器配置迁入本地数据库。
- 建立同步状态中心和 Outbox 基础设施。

### 阶段 B：本地资料库

- 实现资料包 schema、事务导入和安全内容块。
- 让资料库页面只读取 `ContentRepository`。
- 完成 Wiki 搜索、详情路由、反向链接和职业等级视图。
- 当前服务端全局 Content API 标记 deprecated，不再作为个人资料库来源。

### 阶段 C：本地角色

- 将 Character Repository 迁到 Drift。
- 角色创建和角色卡不再依赖 Access Token。
- 增加条目引用快照与缺包降级。
- 实现角色和设置的个人 Vault 同步。

### 阶段 D：战役协作

- 引入 CampaignActor 完整副本和审计。
- DM 模式角色页切换为战役 Actor 管理。
- 实现战役自定义 JSON 条目和 cursor 同步。
- 聊天资料卡改为本地优先渲染。

### 阶段 E：旧边界清理

- 删除页面对 Content API 的直接依赖。
- 删除服务器上的全局/用户资料包托管入口，只保留战役自定义条目。
- 保留旧数据库迁移脚本，将已有战役作用域内容转换为 `CampaignContentEntry`。
- 更新部署、备份和 Agent 文档。

## 17. 测试策略

### 17.1 单元测试

- 包 manifest、条目、内容块和链接校验。
- 稳定 ID、全文索引与类型筛选。
- Character 引用快照和缺包行为。
- Outbox 幂等、cursor 与 tombstone 合并。
- Player/DM 权限策略。

### 17.2 数据库测试

- 空数据库首启。
- Schema 升级和失败回滚。
- 包首次导入、升级、删除和事务失败。
- Web 与 Native 数据库实现共享同一 Repository 契约测试。

### 17.3 Widget 测试

- 无服务器时进入主界面并创建角色。
- 空资料库状态和设置页导入。
- 宽屏 Wiki 双栏与窄屏详情路由。
- Player 角色页与 DM 战役 Actor 页语义不同。
- 离线状态下角色、资料和设置仍可编辑。
- 缺包角色仍能打开完整快照。

### 17.4 服务端测试

- Vault 数据按用户隔离。
- DM 对战役 Actor 完整编辑，Player 权限受限。
- 非成员不能读取战役条目。
- Player 不能写战役条目。
- cursor 增量、幂等操作和 tombstone。
- WebSocket 只发送变化通知。

### 17.5 端到端验收

1. 全新安装且无服务器，应用进入本地首页，资料库为空，可创建角色。
2. 从设置导入本地资料包后，断网仍可搜索、跳转和用于角色创建。
3. 登录另一设备后恢复角色、设置、收藏和笔记，但不会下载本地资料包正文。
4. 玩家发布角色到战役，DM 点击头像查看并编辑完整角色，玩家设备收到修改。
5. DM 创建战役 JSON 条目，在线玩家自动缓存；断网后仍可打开。
6. Player 尝试修改战役 JSON 条目得到 403，客户端不显示管理入口。
7. DM 删除战役条目，离线玩家下次上线根据 tombstone 清理缓存。
8. 删除本地资料包后，已有角色仍可通过快照正常显示。

## 18. 实施计划拆分

本规格覆盖四个相互依赖但可独立验收的子项目，应分别编写实施计划并按顺序执行：

1. `offline-foundation`：Drift、本地 Shell、Server Profile 解耦、Outbox。
2. `local-compendium`：资料包规范、导入器、完整 Wiki 和设置管理。
3. `local-characters-vault`：本地角色、引用快照与跨设备个人同步。
4. `campaign-actors-content`：DM 角色管理、CampaignActor、战役 JSON 条目和聊天集成。

任何后续 Agent 都不得在跳过 `offline-foundation` 的情况下直接改造页面，也不得继续扩展当前远端 `ContentController` 作为离线资料库的核心。

## 19. 参考资料

- Flutter Offline-first support：<https://docs.flutter.dev/app-architecture/design-patterns/offline-first>
- Drift 跨平台数据库：<https://pub.dev/packages/drift>
- Drift Web 持久化：<https://drift.simonbinder.eu/platforms/web/>
- Foundry VTT Actors：<https://foundryvtt.com/article/actors/>
- Foundry VTT Users and Permissions：<https://foundryvtt.com/article/users/>

参考产品只用于信息架构、权限与交互模式分析，不代表复制其视觉资产、商标、受版权保护正文或私有实现。
