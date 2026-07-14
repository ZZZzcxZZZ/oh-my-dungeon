# 战役角色、资料与聊天协作实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不破坏客户端离线能力的前提下，实现玩家角色发布、DM 完整角色管理、战役独立 JSON 条目同步，以及以战役角色为身份的聊天室。

**架构：** 服务端新增 `CampaignActor`、审计日志、`CampaignContentEntry` 和统一的 `CampaignChange` 游标流。Flutter 将远端变化写入 Drift 战役缓存，再由角色页、Wiki 和聊天室读取；WebSocket 只通知最新游标，正文始终通过带权限校验的 HTTP 拉取。

**技术栈：** Flutter、Drift、Material 3、NestJS、Prisma、PostgreSQL、REST、Socket.IO、flutter_test、Jest

---

## 前置条件

依次完成：

1. `docs/superpowers/plans/2026-07-14-offline-foundation.md`
2. `docs/superpowers/plans/2026-07-14-local-compendium.md`
3. `docs/superpowers/plans/2026-07-14-local-characters-vault.md`

本计划不得上传本地资料包正文。战役资料只同步 DM 创建的独立 JSON 条目，不实现覆盖层、补丁、依赖包或服务器资料包市场。

## 文件与职责

- 新建 `apps/server_nest/src/modules/campaign-sync/`：Actor、资料条目、变化流与审计服务。
- 修改 `apps/server_nest/prisma/schema.prisma`：新增战役协作模型，逐步取代旧角色绑定与服务端资料包模型。
- 修改 `apps/server_nest/src/modules/realtime/campaigns.gateway.ts`：只广播变化通知。
- 新建 `apps/client_flutter/lib/src/features/campaigns/data/sync/`：变化拉取、命令推送和缓存应用。
- 新建 `apps/client_flutter/lib/src/features/campaigns/data/local/`：战役 Actor、资料与聊天缓存。
- 新建 `apps/client_flutter/lib/src/features/campaigns/presentation/actors/`：DM 角色目录和完整编辑页。
- 新建 `apps/client_flutter/lib/src/features/campaigns/presentation/content/`：战役创建与中途资料管理 GUI。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`：Actor 身份、说/做输入、资料卡和离线历史。
- 修改 `apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`：按 Player/DM 模式切换数据语义。

### 任务 1：建立服务端战役协作模型与统一游标

**文件：**
- 修改：`apps/server_nest/prisma/schema.prisma`
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-sync.types.ts`
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-change.service.ts`
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-sync.module.ts`
- 修改：`apps/server_nest/src/app.module.ts`
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-change.service.spec.ts`

- [x] **步骤 1：编写游标单调递增与事务回滚测试**

```typescript
it('allocates one campaign cursor per accepted mutation', async () => {
  const first = await service.record('campaign-1', 'actor', 'actor-1', 'upsert');
  const second = await service.record('campaign-1', 'content', 'entry-1', 'upsert');
  expect(BigInt(second.cursor)).toBe(BigInt(first.cursor) + 1n);
});
```

- [x] **步骤 2：运行测试并确认模型缺失**

运行：`npm run test:server -- campaign-change.service.spec.ts`

预期：FAIL，Prisma 尚无战役变化模型，`CampaignChangeService` 不存在。

- [x] **步骤 3：增加 Prisma 模型**

模型字段固定为：

```prisma
model CampaignSyncState {
  campaignId String   @id
  cursor     BigInt   @default(0)
  updatedAt  DateTime @updatedAt
  campaign   Campaign @relation(fields: [campaignId], references: [id], onDelete: Cascade)
}

model CampaignActor {
  id                String   @id @default(uuid())
  campaignId        String
  ownerUserId       String?
  sourceCharacterId String?
  actorType         String   @default("player")
  status            String   @default("active")
  sheetJson         Json
  revision          Int      @default(1)
  updatedBy         String
  createdAt         DateTime @default(now())
  updatedAt         DateTime @updatedAt
  campaign          Campaign @relation(fields: [campaignId], references: [id], onDelete: Cascade)
  audits            CampaignActorAudit[]

  @@unique([campaignId, sourceCharacterId])
  @@index([campaignId, status])
  @@index([ownerUserId])
}

model CampaignActorAudit {
  id              String        @id @default(uuid())
  campaignActorId String
  campaignId      String
  actorUserId     String
  baseRevision    Int
  resultRevision  Int
  changedPaths    Json
  beforeJson      Json
  afterJson       Json
  createdAt       DateTime      @default(now())
  campaignActor   CampaignActor @relation(fields: [campaignActorId], references: [id], onDelete: Cascade)

  @@index([campaignId, createdAt])
}

model CampaignContentEntry {
  id         String    @id @default(uuid())
  campaignId String
  type       String
  slug       String
  name       String
  entryJson  Json
  revision   Int       @default(1)
  createdBy  String
  updatedBy  String
  createdAt  DateTime  @default(now())
  updatedAt  DateTime  @updatedAt
  deletedAt  DateTime?
  campaign   Campaign  @relation(fields: [campaignId], references: [id], onDelete: Cascade)

  @@unique([campaignId, slug])
  @@index([campaignId, type, deletedAt])
}

model CampaignChange {
  id         String   @id @default(uuid())
  campaignId String
  cursor     BigInt
  entityType String
  entityId   String
  operation  String
  revision   Int
  createdAt  DateTime @default(now())
  campaign   Campaign @relation(fields: [campaignId], references: [id], onDelete: Cascade)

  @@unique([campaignId, cursor])
  @@index([campaignId, cursor])
}
```

在 `Campaign` 增加对应 relations。`CampaignChangeService.recordInTransaction` 必须在同一个 Prisma 事务中原子递增 `CampaignSyncState.cursor` 并创建 `CampaignChange`；API 将 `BigInt` cursor 序列化为十进制字符串。

- [x] **步骤 4：生成 Prisma Client 并验证**

```powershell
npm --prefix apps/server_nest run prisma:generate
npm run test:server -- campaign-change.service.spec.ts
npm run lint:server
```

预期：游标测试通过，lint 无错误。

- [x] **步骤 5：提交**

```powershell
git add apps/server_nest/prisma/schema.prisma apps/server_nest/src/modules/campaign-sync apps/server_nest/src/app.module.ts
git commit -m "feat(0.1): add campaign collaboration models"
```

### 任务 2：实现 CampaignActor 发布、读取、编辑与审计

**文件：**
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-actors.controller.ts`
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-actors.service.ts`
- 修改：`apps/server_nest/src/modules/campaign-sync/campaign-sync.types.ts`
- 修改：`apps/server_nest/src/modules/campaign-sync/campaign-sync.module.ts`
- 修改：`apps/server_nest/src/modules/campaigns/policies/campaign.policy.ts`
- 修改：`apps/server_nest/src/modules/campaigns/policies/campaign.policy.spec.ts`
- 创建：`apps/server_nest/test/campaign-actors.e2e-spec.ts`

- [x] **步骤 1：编写权限、冲突和审计失败测试**

在 e2e 测试沿用现有注册、登录和创建战役装配，覆盖：玩家发布自己的本地角色成功；DM 创建 NPC 或未认领 Actor 成功而 player 返回 403；非成员读取返回 403；DM 用 `baseRevision` 完整编辑成功；旧修订更新返回 409 和当前 Actor；DM 更新后生成一条审计记录；DM 不能删除玩家本地角色，只能归档战役副本。

```typescript
await request(server)
  .put(`/api/campaigns/${campaignId}/actors/${actorId}`)
  .set('Authorization', `Bearer ${dmToken}`)
  .send({ baseRevision: 1, sheet: { name: 'Arannis', currentHp: 7 } })
  .expect(200)
  .expect(({ body }) => expect(body.revision).toBe(2));

await request(server)
  .put(`/api/campaigns/${campaignId}/actors/${actorId}`)
  .set('Authorization', `Bearer ${playerToken}`)
  .send({ baseRevision: 1, sheet: { name: 'stale' } })
  .expect(409);
```

- [x] **步骤 2：运行测试并确认端点不存在**

运行：`npm run test:server -- campaign-actors.e2e-spec.ts`

预期：FAIL，Actor 路由返回 404。

- [x] **步骤 3：实现固定端点与权限**

端点固定为：

```text
POST   /api/campaigns/:campaignId/actors/publish
POST   /api/campaigns/:campaignId/actors
GET    /api/campaigns/:campaignId/actors
GET    /api/campaigns/:campaignId/actors/:actorId
PUT    /api/campaigns/:campaignId/actors/:actorId
POST   /api/campaigns/:campaignId/actors/:actorId/runtime-commands
POST   /api/campaigns/:campaignId/actors/:actorId/assign
POST   /api/campaigns/:campaignId/actors/:actorId/archive
GET    /api/campaigns/:campaignId/actors/:actorId/audits
```

发布请求使用 `{ sourceCharacterId, actorType, baseRevision, sheet }`。DM 创建请求使用 `{ actorType: 'npc' | 'unclaimed' | 'companion', ownerUserId?, sheet }`，sourceCharacterId 为 null；完整更新使用 `{ baseRevision, sheet }`；assign 使用 `{ ownerUserId: string | null, baseRevision }` 且目标必须是战役成员。运行时命令只允许 `setHp`、`adjustHp`、`setTemporaryHp`、`setCondition`、`removeCondition` 和 `setResource`，由服务端按接收顺序应用。owner/DM 可创建、分配并完整编辑所有 Actor；玩家可发布和更新自己拥有的 Actor；所有写入在同一事务内递增 revision、写审计和写 `CampaignChange`。

- [x] **步骤 4：验证服务与权限**

```powershell
npm run test:server -- campaign.policy.spec.ts
npm run test:server -- campaign-actors.e2e-spec.ts
npm run lint:server
```

预期：成员隔离、DM 完整编辑、409 冲突、审计与运行时命令测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/server_nest/src/modules/campaign-sync apps/server_nest/src/modules/campaigns/policies apps/server_nest/test/campaign-actors.e2e-spec.ts
git commit -m "feat(0.1): publish and manage campaign actors"
```

### 任务 3：实现 DM 独立 JSON 条目与变化拉取

**文件：**
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-content.controller.ts`
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-content.service.ts`
- 创建：`apps/server_nest/src/modules/campaign-sync/campaign-entry-validator.service.ts`
- 修改：`apps/server_nest/src/modules/campaign-sync/campaign-sync.module.ts`
- 创建：`apps/server_nest/test/campaign-content-sync.e2e-spec.ts`

- [x] **步骤 1：编写 JSON 校验、权限、删除和 cursor 测试**

```typescript
await request(server)
  .post(`/api/campaigns/${campaignId}/content/entries`)
  .set('Authorization', `Bearer ${dmToken}`)
  .send({
    type: 'location',
    slug: 'moon-harbor',
    name: '月港',
    entry: { body: [{ type: 'paragraph', text: '港口描述' }], tags: ['港口'] },
  })
  .expect(201);

const changes = await request(server)
  .get(`/api/campaigns/${campaignId}/changes?cursor=0`)
  .set('Authorization', `Bearer ${playerToken}`)
  .expect(200);
expect(changes.body.items[0].entityType).toBe('content');
```

再覆盖 player 写入 403、非成员读取 403、重复 slug 409、非法内容块返回带 JSON path 的 400、删除产生 tombstone、分页 `nextCursor` 不跳项。

- [x] **步骤 2：运行测试并确认路由缺失**

运行：`npm run test:server -- campaign-content-sync.e2e-spec.ts`

预期：FAIL，content 与 changes 路由返回 404。

- [x] **步骤 3：实现简单同步协议**

端点固定为：

```text
GET    /api/campaigns/:campaignId/changes?cursor=&limit=
POST   /api/campaigns/:campaignId/content/entries/validate
POST   /api/campaigns/:campaignId/content/entries
PUT    /api/campaigns/:campaignId/content/entries/:entryId
DELETE /api/campaigns/:campaignId/content/entries/:entryId
```

`changes` 返回 `{ items, nextCursor, hasMore }`。Actor upsert 项带完整 Actor，content upsert 项带完整 `ContentEntry`，delete 项只带 `entityType/entityId/revision`。limit 默认 100、最大 500。Validator 复用本地资料包允许的内容块和字段约束，但禁止 package manifest、baseEntryId、patch、override 和 dependency 字段；条目 ID 由服务器生成 UUID。

- [x] **步骤 4：验证完整变化流**

```powershell
npm run test:server -- campaign-content-sync.e2e-spec.ts campaign-actors.e2e-spec.ts
npm run lint:server
```

预期：独立条目 CRUD、dry-run、权限、tombstone 和分页游标全部通过。

- [x] **步骤 5：提交**

```powershell
git add apps/server_nest/src/modules/campaign-sync apps/server_nest/test/campaign-content-sync.e2e-spec.ts
git commit -m "feat(0.1): sync campaign json entries"
```

### 任务 4：将 WebSocket 限定为变化通知

**文件：**
- 修改：`apps/server_nest/src/modules/realtime/campaigns.gateway.ts`
- 修改：`apps/server_nest/src/modules/realtime/campaigns.gateway.spec.ts`
- 修改：`apps/server_nest/src/modules/campaign-sync/campaign-change.service.ts`
- 修改：`apps/server_nest/src/modules/campaign-sync/campaign-sync.module.ts`

- [x] **步骤 1：编写最小通知载荷失败测试**

```typescript
it('broadcasts a cursor notification without entry or sheet bodies', () => {
  gateway.broadcastChange({
    campaignId: 'campaign-1',
    cursor: '8',
    entityType: 'content',
  });
  expect(emit).toHaveBeenCalledWith('campaign:changed', {
    campaignId: 'campaign-1',
    cursor: '8',
    entityType: 'content',
  });
});
```

- [x] **步骤 2：运行测试并确认新方法缺失**

运行：`npm run test:server -- campaigns.gateway.spec.ts`

预期：FAIL，`broadcastChange` 不存在。

- [x] **步骤 3：实现提交后广播**

定义：

```typescript
export interface CampaignChangedEvent {
  campaignId: string;
  cursor: string;
  entityType: 'actor' | 'content';
}
```

仅在数据库事务提交成功后调用 `broadcastChange`。事件不得包含 `sheetJson`、`entryJson`、Token 或审计正文。客户端收到事件后按本地 cursor 调 HTTP changes，不能直接信任事件内容更新缓存。

- [x] **步骤 4：验证网关与服务回归**

```powershell
npm run test:server -- campaigns.gateway.spec.ts campaign-change.service.spec.ts
npm run test:server -- campaign-content-sync.e2e-spec.ts
```

预期：通知载荷精简，事务失败不广播，HTTP 拉取仍完整。

- [x] **步骤 5：提交**

```powershell
git add apps/server_nest/src/modules/realtime apps/server_nest/src/modules/campaign-sync
git commit -m "feat(0.1): notify campaign cache changes"
```

### 任务 5：建立 Flutter 战役缓存与同步服务

**文件：**
- 创建：`apps/client_flutter/lib/src/features/campaigns/domain/campaign_actor.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/domain/campaign_change.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/data/local/campaign_cache_tables.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/data/local/campaign_cache_repository.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/data/sync/campaign_sync_api_client.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/data/sync/campaign_sync_service.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/data/sync/campaign_actor_backlink_service.dart`
- 修改：`apps/client_flutter/lib/src/core/database/app_database.dart`
- 创建：`apps/client_flutter/test/campaign_cache_repository_test.dart`
- 创建：`apps/client_flutter/test/campaign_sync_service_test.dart`
- 创建：`apps/client_flutter/test/support/campaign_test_support.dart`

- [x] **步骤 1：编写原子应用分页和 tombstone 测试**

```dart
test('applies a page atomically and advances cursor after writes', () async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = DriftCampaignCacheRepository(database);
  final page = CampaignChangePage.fromJson({
    'items': [
      {
        'cursor': '1',
        'entityType': 'content',
        'entityId': 'entry-1',
        'operation': 'upsert',
        'revision': 1,
        'entity': {'id': 'entry-1', 'type': 'location', 'slug': 'moon-harbor', 'name': '月港', 'body': []}
      }
    ],
    'nextCursor': '1',
    'hasMore': false,
  });
  await repository.applyPage('campaign-1', page);
  expect((await repository.getContentEntry('campaign-1', 'entry-1'))!.name, '月港');
  expect(await repository.cursorFor('campaign-1'), '1');
  await database.close();
});
```

再测试 delete 移除缓存、重复页幂等、写入失败不推进 cursor、Actor JSON 保持完整，以及 DM 的 Actor 更新按 `sourceCharacterId` 回写角色所有者的本地角色。

- [x] **步骤 2：运行测试并确认缓存不存在**

运行：`cd apps/client_flutter; flutter test test/campaign_cache_repository_test.dart`

预期：FAIL，缓存 Repository 和表不存在。

- [x] **步骤 3：实现表、接口和拉取循环**

Drift 表固定为 `CampaignActorsCache`、`CampaignActorBacklinks`、`CampaignContentCache`、`CampaignMessagesCache`、`CampaignSyncCursors` 和 `CharacterSyncConflicts`。`CampaignActorBacklinks` 保存 campaignActorId、sourceCharacterId、lastPublishedLocalRevision 和 lastAppliedActorRevision，用于判断双向同步基线。接口固定为：

```dart
abstract interface class CampaignCacheRepository {
  Stream<List<CampaignActor>> watchActors(String campaignId);
  Future<CampaignActor?> getActor(String campaignId, String actorId);
  Future<ContentEntry?> getContentEntry(String campaignId, String entryId);
  Future<String> cursorFor(String campaignId);
  Future<void> applyPage(String campaignId, CampaignChangePage page);
  Future<void> clearCampaign(String campaignId);
}
```

`CampaignSyncService.pullUntilCurrent` 循环请求 `changes` 直到 `hasMore=false`。应用 ownerUserId 为当前用户且带 `sourceCharacterId` 的 Actor 后，调用 `CampaignActorBacklinkService`：HP、临时生命、状态和资源按服务端 Actor 值直接回写本地角色；构建字段在本地未偏离 lastPublishedRevision 时回写，否则把 local/remote sheet 和字段路径写入 `CharacterSyncConflicts`，由角色页比较解决。不得删除本地角色。401 暂停同步但保留缓存；403 将战役标记为 revoked 和只读；网络失败保留 cursor 并返回可重试状态。将数据库 schema 升至下一连续版本。

在 `test/support/campaign_test_support.dart` 实现 `MemoryCampaignCacheRepository`（构造参数 `actors` 与 `entriesByCampaign`）和 `MemoryCampaignSyncApiClient`（记录 publish/create/update/runtime/assign/archive 调用并可返回 409 冲突）。两个类型完整实现生产接口，后续 Widget 与组合 Repository 测试统一复用。

- [x] **步骤 4：生成并验证同步服务**

```powershell
cd apps/client_flutter
dart run build_runner build --delete-conflicting-outputs
flutter test test/campaign_cache_repository_test.dart test/campaign_sync_service_test.dart test/app_database_test.dart
flutter analyze
```

预期：分页、幂等、错误保留和数据库迁移测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/core/database apps/client_flutter/lib/src/features/campaigns/domain apps/client_flutter/lib/src/features/campaigns/data apps/client_flutter/test/campaign_cache_repository_test.dart apps/client_flutter/test/campaign_sync_service_test.dart apps/client_flutter/test/app_database_test.dart apps/client_flutter/test/support/campaign_test_support.dart
git commit -m "feat(0.1): cache campaign collaboration data"
```

### 任务 6：实现角色发布与 DM 模式角色管理

**文件：**
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/actors/campaign_actor_controller.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/actors/campaign_actor_directory_page.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/actors/campaign_actor_sheet_page.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/actors/publish_character_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/app/dnd_table_app.dart`
- 创建：`apps/client_flutter/test/campaign_actor_pages_test.dart`
- 修改：`apps/client_flutter/test/client_mode_test.dart`

- [x] **步骤 1：编写模式语义和 DM 编辑失败测试**

Widget 测试使用 `MemoryCampaignCacheRepository` 与 `MemoryCampaignSyncApiClient`，覆盖：Player 模式显示本地角色和“发布到战役”；DM 模式先选择战役并显示玩家角色、NPC、未认领和归档筛选；点击 Actor 打开完整角色卡；DM 修改 HP、状态、装备、法术和备注后发送带 `baseRevision` 的更新；409 显示比较与重新加载动作；玩家角色页能处理 DM 回写产生的构建冲突并选择保留本地或接受战役版本。

```dart
expect(find.byKey(const Key('player-local-characters')), findsOneWidget);
await tester.tap(find.byKey(const Key('mode-switch-dm')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('campaign-actor-directory')), findsOneWidget);
expect(find.text('发布到战役'), findsNothing);
```

- [x] **步骤 2：运行测试并确认现有角色页语义错误**

运行：`cd apps/client_flutter; flutter test test/campaign_actor_pages_test.dart test/client_mode_test.dart`

预期：FAIL，DM 模式仍显示个人角色页或缺少 Actor 目录。

- [x] **步骤 3：实现 Material 3 角色工作流**

窄屏使用 `NavigationBar` 保持"角色"主入口，Actor 目录使用搜索、`FilterChip` 和 `ListTile`；宽屏在同页使用 master-detail 双栏。Actor 详情使用 `SliverAppBar`、状态摘要、`TabBar`（概览、能力、装备、法术、备注、历史）和标准 `FilledButton`/`IconButton`。完整编辑权必须覆盖 sheet 全字段，但危险动作使用确认对话框；每次成功更新立即写本地缓存并触发后台拉取。

- [x] **步骤 4：验证两种模式和响应式布局**

```powershell
cd apps/client_flutter
flutter test test/campaign_actor_pages_test.dart test/client_mode_test.dart test/character_pages_test.dart
flutter analyze
```

预期：Player/DM 语义隔离、发布、完整编辑、冲突状态和窄/宽布局测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/app apps/client_flutter/lib/src/features/campaigns/presentation/actors apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart apps/client_flutter/test/campaign_actor_pages_test.dart apps/client_flutter/test/client_mode_test.dart
git commit -m "feat(0.1): manage campaign actors in dm mode"
```

### 任务 7：提供战役创建与中途资料管理 GUI

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaigns_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_detail_page.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/content/campaign_content_controller.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/content/campaign_content_page.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/content/campaign_content_editor.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/content/campaign_json_import_dialog.dart`
- 创建：`apps/client_flutter/test/campaign_content_pages_test.dart`

- [x] **步骤 1：编写创建入口、表单和 dry-run 失败测试**

覆盖战役创建向导中的可跳过"自定义资料"步骤、战役详情 `+` 菜单入口、owner/DM 可见而 player 隐藏、GUI 创建、JSON 粘贴预览、错误 path 展示、确认后同步和离线时保存草稿但不伪装发布成功。

```dart
await tester.tap(find.byKey(const Key('campaign-more-actions')));
await tester.tap(find.text('战役资料'));
await tester.pumpAndSettle();
expect(find.byKey(const Key('campaign-content-page')), findsOneWidget);
expect(find.text('新建条目'), findsOneWidget);
```

- [x] **步骤 2：运行测试并确认管理入口缺失**

运行：`cd apps/client_flutter; flutter test test/campaign_content_pages_test.dart`

预期：FAIL，战役资料页面不存在。

- [x] **步骤 3：实现简洁 GUI 与 JSON 预览**

编辑器只展示条目类型、名称、slug、摘要、标签和安全内容块，不展示 package、dependency、overlay 或 patch 概念。JSON 导入允许单对象或数组，先调用本地解析器显示本地错误，再调用服务器 validate；预览明确列出新增数量和错误。列表从 Drift 战役缓存读取，因此断网时可查阅；只有发布、编辑和删除操作要求连接服务器。

- [x] **步骤 4：验证权限和离线阅读**

```powershell
cd apps/client_flutter
flutter test test/campaign_content_pages_test.dart test/content_package_model_test.dart
flutter analyze
```

预期：创建与中途入口、权限、预览、错误展示和离线缓存阅读通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation apps/client_flutter/test/campaign_content_pages_test.dart
git commit -m "feat(0.1): manage campaign json entries"
```

### 任务 8：让 Wiki 合并本地与当前战役条目

**文件：**
- 修改：`apps/client_flutter/lib/src/features/content/domain/content_entry.dart`
- 修改：`apps/client_flutter/lib/src/features/content/data/local/content_repository.dart`
- 创建：`apps/client_flutter/lib/src/features/content/data/campaign_aware_content_repository.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_library_controller.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_detail_page.dart`
- 创建：`apps/client_flutter/test/campaign_aware_content_repository_test.dart`

- [x] **步骤 1：编写合并与同名隔离失败测试**

```dart
test('searches local packages and current campaign cache without overriding', () async {
  final localEntry = ContentEntry.fromJson({
    'id': 'example:location/moon-harbor',
    'type': 'location',
    'slug': 'moon-harbor',
    'name': '月港',
    'body': <Map<String, Object?>>[],
    'revision': 1,
  });
  final campaignEntry = ContentEntry.fromJson({
    'id': 'campaign-entry-1',
    'type': 'location',
    'slug': 'moon-harbor-homebrew',
    'name': '月港',
    'body': <Map<String, Object?>>[],
    'revision': 1,
  });
  final memoryLocalContentRepository = MemoryContentRepository(
    initialEntries: [localEntry],
  );
  final memoryCampaignCacheRepository = MemoryCampaignCacheRepository(
    entriesByCampaign: {'campaign-1': [campaignEntry]},
  );
  final repository = CampaignAwareContentRepository(
    local: memoryLocalContentRepository,
    campaign: memoryCampaignCacheRepository,
    activeCampaignId: () => 'campaign-1',
  );
  final results = await repository.search(const ContentQuery(text: '月港'));
  expect(
    results.map((entry) => entry.origin),
    containsAll([ContentOrigin.local, ContentOrigin.campaign]),
  );
});
```

战役端复用任务 5 已定义的 `MemoryCampaignCacheRepository`，本地端复用计划二的 `MemoryContentRepository`。再覆盖无当前战役时只返回本地、战役撤权后不显示、详情来源标识和链接跳转。

- [x] **步骤 2：运行测试并确认组合 Repository 缺失**

运行：`cd apps/client_flutter; flutter test test/campaign_aware_content_repository_test.dart`

预期：FAIL，`CampaignAwareContentRepository` 不存在。

- [x] **步骤 3：实现只读组合查询**

在 `content_entry.dart` 增加 `enum ContentOrigin { local, campaign }` 和不可由导入 JSON 指定的运行时 `origin` 字段；本地 Repository 返回 `local`，组合 Repository 为战役缓存条目复制 `campaign`。条目键分别使用 `local:<packageId>:<entryId>` 与 `campaign:<campaignId>:<entryId>`，同名条目不得覆盖。搜索结果显示来源 chip；战役条目完整打开缓存正文；本地缺少链接目标时显示缺失来源状态。收藏与笔记仍写个人 Vault，不写战役条目服务端。

- [x] **步骤 4：验证 Wiki 回归**

```powershell
cd apps/client_flutter
flutter test test/campaign_aware_content_repository_test.dart test/content_repository_test.dart test/content_wiki_page_test.dart
flutter analyze
```

预期：本地、战役和空库三种状态均正常。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/content apps/client_flutter/test/campaign_aware_content_repository_test.dart
git commit -m "feat(0.1): merge campaign entries into wiki"
```

### 任务 9：以 CampaignActor 重构聊天身份和资料卡

**文件：**
- 修改：`apps/server_nest/prisma/schema.prisma`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.types.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.controller.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.service.ts`
- 修改：`apps/server_nest/test/campaigns.e2e-spec.ts`
- 修改：`apps/client_flutter/lib/src/features/campaigns/domain/campaign.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/data/campaign_api_client.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 修改：`apps/client_flutter/test/campaign_api_client_test.dart`
- 修改：`apps/client_flutter/test/campaign_controller_test.dart`
- 创建：`apps/client_flutter/test/campaign_chat_actor_test.dart`

- [x] **步骤 1：编写 Actor 身份、说/做和快照降级测试**

服务端测试要求发送者必须选择自己拥有的 Actor，DM 可选择任意战役 Actor，伪造 `displayName/avatarUrl` 被忽略。客户端测试要求输入框有“说”和“做”两种分段状态；say 显示气泡，action 显示斜体动作；点击头像时 DM 打开完整可编辑页、Player 打开公开只读页；`[[` 同时搜索本地与战役缓存；缺失条目仍显示名称与摘要快照。

```dart
await tester.tap(find.byKey(const Key('chat-mode-action')));
await tester.enterText(find.byKey(const Key('campaign-chat-input')), '拔出长剑');
await tester.tap(find.byKey(const Key('campaign-chat-send')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('action-message')), findsOneWidget);
```

- [x] **步骤 2：运行测试并确认旧自由身份失败**

```powershell
npm run test:server -- campaigns.e2e-spec.ts
cd apps/client_flutter
flutter test test/campaign_api_client_test.dart test/campaign_chat_actor_test.dart
```

预期：FAIL，消息仍接受客户端自由填写的角色名与头像。

- [x] **步骤 3：绑定消息到 Actor 并缓存历史**

将 `CampaignChatMessage.characterId` 迁移为 `campaignActorId` relation；服务端从 Actor sheet 提取 `displayName/avatarUrl/statusSummary` 快照，忽略客户端同名字段。消息 payload 增加可选 `contentReference`：`{ entryKey, nameSnapshot, summarySnapshot, diceExpression }`。客户端成功收发消息后写 `CampaignMessagesCache`；离线时显示历史只读状态并禁用发送，但角色、资料库和其他本地页面保持可用。

- [x] **步骤 4：验证聊天和缓存回归**

```powershell
npm run test:server -- campaigns.e2e-spec.ts campaign-actors.e2e-spec.ts
npm run lint:server
cd apps/client_flutter
flutter test test/campaign_api_client_test.dart test/campaign_controller_test.dart test/campaign_chat_actor_test.dart
flutter analyze
```

预期：身份不可伪造、说/做格式、头像跳转、资料快照和离线历史测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/server_nest/prisma/schema.prisma apps/server_nest/src/modules/campaigns apps/server_nest/test/campaigns.e2e-spec.ts apps/client_flutter/lib/src/features/campaigns apps/client_flutter/test/campaign_api_client_test.dart apps/client_flutter/test/campaign_controller_test.dart apps/client_flutter/test/campaign_chat_actor_test.dart
git commit -m "feat(0.1): bind campaign chat to actors"
```

### 任务 10：实现本地完整备份、恢复与缓存维护

**文件：**
- 创建：`apps/client_flutter/lib/src/core/backup/local_backup_models.dart`
- 创建：`apps/client_flutter/lib/src/core/backup/local_data_archive_service.dart`
- 创建：`apps/client_flutter/lib/src/core/backup/drift_local_data_archive_service.dart`
- 创建：`apps/client_flutter/lib/src/features/server_home/presentation/data_management_page.dart`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`
- 创建：`apps/client_flutter/test/local_data_archive_service_test.dart`
- 创建：`apps/client_flutter/test/data_management_page_test.dart`

- [ ] **步骤 1：编写无凭据备份与原子恢复失败测试**

```dart
test('exports local-owned data and restores it atomically without tokens', () async {
  final source = AppDatabase.forTesting(NativeDatabase.memory());
  final target = AppDatabase.forTesting(NativeDatabase.memory());
  final sourceService = DriftLocalDataArchiveService(source);
  final targetService = DriftLocalDataArchiveService(target);
  await seedBackupFixture(source);

  final bytes = await sourceService.exportArchive();
  final preview = await targetService.previewArchive(bytes);
  expect(preview.valid, isTrue);
  expect(preview.characterCount, 1);
  final archive = ZipDecoder().decodeBytes(bytes);
  final databaseFile = archive.findFile('database.json')!;
  final databaseJson = utf8.decode(databaseFile.content as List<int>);
  expect(databaseJson, isNot(contains('access-token')));

  await targetService.restoreArchive(preview);
  expect(await target.select(target.characters).get(), hasLength(1));
  expect(await target.select(target.localContentAssets).get(), isNotEmpty);
  await source.close();
  await target.close();
});
```

在测试文件内实现 `seedBackupFixture(AppDatabase)`，写入一个服务器 Profile（不写 Token）、一个资料包及 asset、一个角色、收藏、笔记、书签和偏好。再测试损坏 archive、未知 schema、哈希不符或中途写失败时目标数据库完全不变。

- [x] **步骤 2：运行测试并确认服务缺失**

运行：`cd apps/client_flutter; flutter test test/local_data_archive_service_test.dart`

预期：FAIL，备份模型和服务不存在。

- [x] **步骤 3：实现版本化 archive 和事务恢复**

备份格式固定为 `.dndtable-backup` ZIP：

```text
manifest.json
database.json
assets/<packageId>/<relativePath>
```

`manifest.json` 包含 `formatVersion=1`、`createdAt`、客户端版本、各类计数、总大小和 SHA-256；`database.json` 只含服务器 Profile 的名称/URL、本地资料、角色、收藏、笔记、书签、偏好和安装清单，不含 access/refresh token、密码、Outbox、cursor、战役缓存或聊天缓存。恢复先完整解析和校验，再用单个 Drift transaction 替换本地所有权数据；失败回滚。assets 使用与资料包导入相同的路径和大小限制。

- [x] **步骤 4：编写设置页面失败测试**

```dart
testWidgets('opens data tools and requires confirmation before restore', (tester) async {
  final service = MemoryLocalDataArchiveService(validPreview: true);
  await tester.pumpWidget(MaterialApp(
    home: DataManagementPage(archiveService: service),
  ));
  await tester.tap(find.text('恢复备份'));
  await tester.pumpAndSettle();
  expect(find.text('将替换此设备上的本地数据'), findsOneWidget);
  expect(service.restoreCalls, 0);
});
```

`MemoryLocalDataArchiveService` 在同一测试文件中完整实现接口并记录 export、preview、restore、clearCache 和 rebuildIndex 调用。

- [x] **步骤 5：实现 Material 3 数据管理页**

设置页“数据”分组提供导出备份、恢复备份、清理战役缓存、重建资料索引四个 `ListTile`。文件动作使用平台无关 picker/saver 接口；恢复必须先显示来源、版本、计数、大小和错误，再二次确认。清缓存只删除 `CampaignActorsCache`、`CampaignContentCache`、`CampaignMessagesCache` 和 cursor，不删除个人角色或本地资料；重建索引从 `LocalContentEntries` 事务重建搜索数据。

- [x] **步骤 6：验证备份与设置 UI**

```powershell
cd apps/client_flutter
flutter test test/local_data_archive_service_test.dart test/data_management_page_test.dart test/app_database_test.dart
flutter analyze
```

预期：无凭据导出、assets、原子恢复、损坏回滚、清缓存边界、重建索引和确认 UI 通过。

- [x] **步骤 7：提交**

```powershell
git add apps/client_flutter/lib/src/core/backup apps/client_flutter/lib/src/features/server_home/presentation apps/client_flutter/test/local_data_archive_service_test.dart apps/client_flutter/test/data_management_page_test.dart
git commit -m "feat(0.1): back up and restore local app data"
```

### 任务 11：迁移旧服务端资料与角色边界并封版验证

**文件：**
- 创建：`apps/server_nest/prisma/migrations/20260714090000_campaign_collaboration/migration.sql`
- 修改：`apps/server_nest/prisma/schema.prisma`
- 删除：`apps/server_nest/src/modules/content/content.controller.ts`
- 删除：`apps/server_nest/src/modules/content/content.service.ts`
- 删除：`apps/server_nest/src/modules/content/content.module.ts`
- 删除：`apps/server_nest/src/modules/content/content.types.ts`
- 修改：`apps/server_nest/src/app.module.ts`
- 修改：`apps/server_nest/test/content.e2e-spec.ts`
- 修改：`README.md`
- 修改：`docs/roadmap/current-execution-status.md`
- 修改：`docs/agents/agent-execution-guide.md`
- 创建：`docs/architecture/offline-data-and-sync.md`

- [x] **步骤 1：编写迁移与已移除 API 测试**

迁移测试准备一个 campaign scoped `ContentPackage` 和两个 `ContentItem`，执行迁移后断言得到两个 `CampaignContentEntry`，slug 和正文保留，变化游标可从 0 拉取。接口测试断言旧全局/用户 package 写入端点返回 404，战役新端点仍可用。已有 `Character` 数据只迁移到所属战役的 Actor；没有 binding 的角色不复制，避免把个人角色误放进战役。

- [x] **步骤 2：先运行迁移测试确认失败**

运行：`npm run test:server -- content.e2e-spec.ts campaign-content-sync.e2e-spec.ts`

预期：FAIL，旧 Content API 仍存在，迁移尚未转换数据。

- [x] **步骤 3：完成一次性 SQL 与边界清理**

迁移顺序固定为：创建新表；转换 campaign scoped 内容；转换 `CharacterCampaignBinding`；为转换记录建立 change cursor；将聊天关联更新到 Actor；删除旧 `ContentOverride`、`CampaignContentPackage`、服务端用户/global package 和 `CharacterCampaignBinding` 表；保留个人数据的客户端/Vault 迁移路径。公开代码与数据库种子不得包含 SRD 或官方规则正文。

文档明确：

```text
- 默认资料库为空。
- 本地资料包只驻留客户端，正文不上传。
- Vault 只同步个人实体和资料包安装清单。
- 战役只同步 DM 独立 JSON 条目、CampaignActor、聊天及实时状态。
- owner/DM 对战役 Actor 有完整编辑权，所有修改有审计。
```

- [x] **步骤 4：执行完整封版验证**

```powershell
npm run setup
npm run check
npm run doctor
cd apps/client_flutter
flutter build web
```

预期：服务端 lint、Flutter analyze、全部服务端/客户端测试、Docker Compose 配置和 Web build 全部通过；Web 控制台无启动错误；未配置服务器时资料库、角色和设置可打开。

- [x] **步骤 5：检查仓库不含受版权保护的默认正文**

```powershell
rg -n -i "srd|player.?s handbook|players handbook|玩家手册" apps packages --glob '!**/build/**' --glob '!**/node_modules/**'
git diff --check
git status --short
```

预期：搜索结果只允许出现在兼容性代码、测试名或说明文字中，不存在规则正文或默认资料包；diff 无空白错误，状态只包含本计划变更。

- [x] **步骤 6：提交**

```powershell
git add apps/server_nest apps/client_flutter docs README.md
git commit -m "refactor(0.1): complete offline-first campaign collaboration"
```

## 完成标准

- 未配置服务器、未登录和断网时，个人角色、资料库、收藏、笔记、设置与规则计算完整可用。
- Player 角色页只管理本地个人角色；DM 角色页管理所选战役 Actor，并具备完整编辑权和审计。
- 本地角色发布后形成完整 `CampaignActor`，修订冲突可见，DM 变更可同步回玩家。
- 战役只同步 DM 新增的独立 JSON 条目；玩家可离线读取缓存，不存在资料包覆盖或依赖选项。
- Wiki 同时检索本地包和当前战役缓存，来源明确且同名不覆盖。
- 聊天身份绑定 Actor，支持说/做、头像角色卡、资料引用快照和离线历史。
- 公开仓库、默认数据库和客户端安装包不含 SRD 或官方规则正文。
- `npm run doctor` 与 `flutter build web` 使用新鲜输出通过。
