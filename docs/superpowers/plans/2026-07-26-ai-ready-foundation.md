# D&D AI Ready 基础实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复当前可靠性缺陷，并建立可由 Flutter UI 与未来 AI 共用的结构化角色操作、事件查询和可读 Markdown 交换基础。

**架构：** 保留当前 NestJS Service 与 Flutter Repository/Controller，不引入通用命令总线。数据库当前状态仍是真相；每个已验证的角色操作在同一事务中更新状态并追加不可变 `GameEvent`。旧 `Character.data`、`CampaignActor.sheetJson` 和 Drift 数据由版本化适配器兼容读取，逐条迁移写路径。

**技术栈：** NestJS 11、Prisma 6、PostgreSQL、Socket.IO、Flutter、Drift、Jest、Flutter Test。

---

## 文件结构

- `apps/server_nest/prisma/schema.prisma`：会话阅读游标、结构化角色运行状态和游戏事件持久化。
- `apps/server_nest/src/modules/realtime/campaigns.gateway.ts`：认证后的战役与会话 Socket 房间。
- `apps/server_nest/src/modules/campaigns/campaign-conversations.service.ts`：会话可见性、归档和独立未读状态。
- `apps/server_nest/src/modules/characters/domain/character-state.ts`：v2 角色 HP、资源、状态和物品类型与解析器。
- `apps/server_nest/src/modules/characters/character-operations.service.ts`：角色高频操作及事件事务。
- `apps/server_nest/src/modules/characters/character-queries.service.ts`：完整视图、摘要和事件查询。
- `apps/server_nest/src/modules/game-events/`：事件类型、服务和控制器。
- `apps/client_flutter/lib/src/features/characters/domain/character_document.dart`：客户端 v2 角色文档。
- `apps/client_flutter/lib/src/features/characters/data/character_markdown_codec.dart`：可读 Markdown 编解码。
- `apps/client_flutter/lib/src/features/characters/data/character_repository.dart`：本地操作与同步边界。
- `apps/client_flutter/lib/src/features/characters/presentation/`：完整编辑保留、快捷操作与导入预览。

### 任务 1：隔离私聊、小群与会话阅读状态

**文件：**
- 修改：`apps/server_nest/prisma/schema.prisma`
- 创建：`apps/server_nest/prisma/migrations/20260726000100_conversation_reads/migration.sql`
- 修改：`apps/server_nest/src/modules/realtime/campaigns.gateway.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaign-conversations.service.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.service.ts`
- 测试：`apps/server_nest/src/modules/realtime/campaigns.gateway.spec.ts`
- 测试：`apps/server_nest/test/campaign-conversations.e2e-spec.ts`

- [x] **步骤 1：编写失败测试**

增加测试证明：私聊消息仅发送到 `conversation:<id>`；非参与者不能加入房间；每位用户每个会话有独立 `lastReadAt`；归档会话默认不列出且不能发送；主会话元数据包含 `conversationId = null` 的旧消息。

```ts
expect(server.to).toHaveBeenCalledWith(`conversation:${conversationId}`);
expect(conversations.find((item) => item.id === archivedId)).toBeUndefined();
expect(first.unreadCount).toBe(0);
expect(second.unreadCount).toBe(2);
```

- [x] **步骤 2：验证红灯**

运行：

```powershell
npm --prefix apps/server_nest test -- campaigns.gateway.spec.ts campaign-conversations.e2e-spec.ts
```

预期：现有实现广播到战役房间、共用成员阅读时间并返回归档会话，测试失败。

- [x] **步骤 3：实现最小修复**

新增 `CampaignConversationRead(userId, conversationId, lastReadAt)` 唯一记录。Socket 加入会话前验证成员与 participant；主聊继续使用战役房间，私聊和小群使用会话房间。归档会话仅在显式管理查询中返回，并拒绝消息写入。

- [x] **步骤 4：验证绿灯并提交**

运行上述测试及 `npm run lint:server`，提交：

```text
fix(0.1): isolate campaign conversations
```

### 任务 2：固定部署依赖、密钥与媒体上传

**文件：**
- 修改：`apps/server_nest/package.json`
- 修改：`apps/server_nest/Dockerfile`
- 修改：`docker-compose.yml`
- 修改：`apps/server_nest/src/main.ts`
- 修改：`apps/server_nest/src/modules/media/media.controller.ts`
- 创建：`apps/server_nest/test/media.e2e-spec.ts`
- 修改：`docs/handoff-2026-07-25.md`

- [x] **步骤 1：编写媒体失败测试**

使用超过 100 KiB 的合法 Base64 上传应成功；包含非法字符或非规范 padding 的 Base64 返回 400；超限返回 400。

```ts
await request(app.getHttpServer())
  .post('/media')
  .set('Authorization', `Bearer ${token}`)
  .send({ purpose: 'avatar', mimeType: 'image/png', base64 })
  .expect(201);
```

- [x] **步骤 2：验证红灯**

运行 `npm --prefix apps/server_nest test -- media.e2e-spec.ts`，预期大请求在控制器前返回 413，非法 Base64 被接受。

- [x] **步骤 3：实现媒体修复**

在 `main.ts` 使用与 `MAX_UPLOAD_SIZE_MB` 一致、包含 Base64 开销的 JSON limit。使用严格的 Base64 正则、长度与重新编码等价检查后再解码。

- [x] **步骤 4：固定容器启动**

将与 `@prisma/client` 同版本的 `prisma` CLI 作为生产依赖安装，Docker 启动调用本地 `./node_modules/.bin/prisma`。Compose 使用 `${POSTGRES_PASSWORD:?required}` 和 `${JWT_SECRET:?required}`，不提供弱默认值。

- [x] **步骤 5：验证并提交**

运行媒体 e2e、服务端构建、`docker compose config`（使用临时强密钥环境变量）及 `git diff --check`，提交：

```text
fix(0.1): harden media and deterministic deployment
```

### 任务 3：建立版本化角色领域模型

**文件：**
- 创建：`apps/server_nest/src/modules/characters/domain/character-state.ts`
- 创建：`apps/server_nest/src/modules/characters/domain/character-state.spec.ts`
- 修改：`apps/server_nest/src/modules/characters/characters.types.ts`
- 创建：`apps/client_flutter/lib/src/features/characters/domain/character_document.dart`
- 创建：`apps/client_flutter/test/character_document_test.dart`

- [x] **步骤 1：编写失败测试**

覆盖旧数据缺失字段、数值边界、自定义资源、状态来源、物品实例、未知 namespaced extension 和 v2 round trip。

```ts
expect(parseCharacterState({ hp: '25/40' })).toEqual({
  schemaVersion: 2,
  hitPoints: { current: 25, maximum: 40, temporary: 0 },
  resources: [],
  conditions: [],
  items: [],
  extensions: {},
});
```

- [x] **步骤 2：验证红灯**

运行服务端领域测试与 Flutter 新测试，预期类型和解析器不存在。

- [x] **步骤 3：实现纯领域适配器**

实现不可依赖 Prisma、HTTP 或 Flutter Widget 的 v2 类型、默认值、校验、旧字段兼容和序列化。自定义扩展只接受包含 `.` 的命名空间键和 JSON 值。

- [x] **步骤 4：验证并提交**

运行两端领域测试和静态分析，提交：

```text
feat(0.1): add versioned character document
```

### 任务 4：持久化角色状态与 GameEvent

**文件：**
- 修改：`apps/server_nest/prisma/schema.prisma`
- 创建：`apps/server_nest/prisma/migrations/20260726000200_character_state_events/migration.sql`
- 创建：`apps/server_nest/src/modules/game-events/game-events.types.ts`
- 创建：`apps/server_nest/src/modules/game-events/game-events.service.ts`
- 创建：`apps/server_nest/src/modules/game-events/game-events.controller.ts`
- 创建：`apps/server_nest/src/modules/game-events/game-events.module.ts`
- 修改：`apps/server_nest/src/app.module.ts`
- 测试：`apps/server_nest/test/characters.e2e-spec.ts`

- [x] **步骤 1：编写失败测试**

证明本地默认状态和不同战役状态互不污染，事件拥有稳定 `requestId` 并按角色/战役/游标分页。

- [x] **步骤 2：验证红灯**

运行 `npm --prefix apps/server_nest test -- characters.e2e-spec.ts`，预期新状态和事件接口不存在。

- [x] **步骤 3：实现最小持久化**

新增 `CharacterState(characterId, campaignId?, stateJson, revision)` 和
`GameEvent(schemaVersion, type, campaignId?, characterId?, actorType,
actorId, requestId, targets, cause, before, after, payload, occurredAt)`。
默认状态使用确定性的 scope key，避免 PostgreSQL 对 nullable unique 的歧义。

- [x] **步骤 4：验证并提交**

运行迁移、Prisma generate 和角色 e2e，提交：

```text
feat(0.1): persist scoped character state and game events
```

### 任务 5：统一 HP、状态、资源和物品操作

**文件：**
- 创建：`apps/server_nest/src/modules/characters/character-operations.service.ts`
- 修改：`apps/server_nest/src/modules/characters/characters.controller.ts`
- 修改：`apps/server_nest/src/modules/characters/characters.module.ts`
- 修改：`apps/server_nest/src/modules/characters/characters.service.ts`
- 测试：`apps/server_nest/test/characters.e2e-spec.ts`

- [x] **步骤 1：逐项编写失败测试**

覆盖伤害/治疗边界、临时 HP、重复 `requestId`、添加/移除状态、资源消耗/休息恢复、物品发放/消耗/转移/装备，以及角色所有者和 DM 权限。

```ts
expect(result.state.hitPoints.current).toBe(17);
expect(result.event.type).toBe('character.hp.adjusted');
expect(result.event.before).toEqual({ current: 25 });
expect(result.event.after).toEqual({ current: 17 });
```

- [x] **步骤 2：验证每组红灯**

每增加一种操作测试就单独运行，确认因端点或行为缺失而失败。

- [x] **步骤 3：实现普通应用服务**

每个方法执行权限、revision、D&D 边界、事务状态更新和事件写入。调用方不能提交任意 `before`、`after` 或 actor 身份。

- [x] **步骤 4：验证并提交**

运行角色 e2e、全量服务端测试和 lint，提交：

```text
feat(0.1): add auditable character operations
```

### 任务 6：角色详情、摘要和事件查询

**文件：**
- 创建：`apps/server_nest/src/modules/characters/character-queries.service.ts`
- 修改：`apps/server_nest/src/modules/characters/characters.controller.ts`
- 修改：`apps/server_nest/src/modules/characters/characters.types.ts`
- 测试：`apps/server_nest/test/characters.e2e-spec.ts`

- [x] **步骤 1：编写失败测试**

摘要仅返回姓名、等级、职业、HP、状态名和主要装备；详情返回 resolved view；玩家不能读取无权限角色；DM 可读取战役角色；事件支持 cursor、type 与时间筛选。

- [x] **步骤 2：验证红灯并实现**

运行角色 e2e 确认失败，随后实现查询服务，避免控制器拼接 JSON。

- [x] **步骤 3：验证并提交**

运行角色 e2e、全量服务端测试和 lint，提交：

```text
feat(0.1): expose character summaries and event history
```

### 任务 7：Flutter 使用统一操作与同步状态

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/data/character_api_client.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/data/character_repository.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_controller.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character_quick_edit_service.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_event_dispatcher.dart`
- 测试：`apps/client_flutter/test/character_api_client_test.dart`
- 测试：`apps/client_flutter/test/character_controller_test.dart`
- 测试：`apps/client_flutter/test/character_quick_edit_service_test.dart`

- [x] **步骤 1：编写失败测试**

快捷 HP、状态、资源和物品操作应调用统一 action API，离线时写本地状态与 outbox；联网回包替换缓存；完整角色编辑仍可保存。

- [x] **步骤 2：验证红灯并实现**

逐个迁移现有 UI 写路径，不改变页面布局。删除已无调用的直接 JSON 修改函数。

- [x] **步骤 3：验证并提交**

运行相关 Flutter 测试和 `flutter analyze`，提交：

```text
refactor(0.1): route character actions through operations
```

### 任务 8：可读 Markdown 导入导出

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/data/character_markdown_codec.dart`
- 创建：`apps/client_flutter/lib/src/features/characters/domain/character_import_diff.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 创建：`apps/client_flutter/lib/src/features/characters/presentation/character_import_preview_sheet.dart`
- 创建：`apps/client_flutter/test/character_markdown_codec_test.dart`
- 创建：`apps/client_flutter/test/character_import_preview_test.dart`

- [x] **步骤 1：编写失败 codec 测试**

覆盖中文可读导出、标准与自定义字段 round trip、HTML 稳定引用、用户调整空行、非法数值、未知章节保留和基础/战役快照两种导出。

- [x] **步骤 2：验证红灯并实现 codec**

使用 Markdown AST 与 YAML parser；不使用标题字符串切片解析。生成固定章节顺序和易读表格。

- [x] **步骤 3：编写并实现预览测试**

预览按新增、修改、删除分组显示自然语言差异；提供新建、覆盖、合并三个明确动作；执行导入时调用现有角色保存/操作接口。

- [x] **步骤 4：验证并提交**

运行 Markdown、预览、角色页面测试和 analyze，提交：

```text
feat(0.1): add readable character markdown exchange
```

### 任务 9：全量回归与文档对齐

**文件：**
- 修改：`docs/current-execution-status.md`
- 修改：`docs/handoff-2026-07-25.md`
- 修改：`README.md`

- [x] **步骤 1：运行全量验证**

```powershell
npm run lint:server
npm run analyze:client
npm run test:server
npm run test:client
npm --prefix apps/server_nest run build
```

Docker 可用时额外构建镜像并以无网络运行迁移启动测试。Docker 不可用时必须明确记录未验证项。

- [x] **步骤 2：核验迁移与兼容**

对空数据库执行 migrations，对旧测试 fixture 验证 v1 到 v2 读取，运行 `git diff --check` 并确认没有私有资料包进入 Git。

- [x] **步骤 3：更新状态并提交**

只记录实际通过的测试数量、当前 HEAD、迁移数量和残留边界，提交：

```text
docs(0.1): record AI-ready foundation status
```
