# 私人工作区基础实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为服务器提供稳定实例身份，将服务器公开名称与本地备注分离，并让未登录和不同服务器账号使用独立本地工作区。

**架构：** `BootstrapDatabase` 保存服务器连接和当前工作区索引；`AppDatabase` 只作为私人 `workspace.db` 使用。`WorkspaceStorageManager` 根据 local 或 `{instanceId,userId}` 打开数据库，认证切换通过 `WorkspaceSessionCoordinator` 原子替换工作区依赖。现有旧库先迁入 local，不自动归属账号。

**技术栈：** Flutter、Drift、IndexedDB/SQLite、NestJS、Prisma、PostgreSQL、TDD

**实施状态（2026-07-29）：** 任务 1–6 已实现；任务 7 验证通过。服务端 351 项测试（27 suites）通过，lint、build、Prisma validate 通过；Flutter 828 项测试通过、2 项未提供私有包路径的校验按设计跳过，analyze 无问题。生产中的 `bootstrap.db` 暂时复用 `AppDatabase` 的 Drift schema 以降低迁移风险，但业务层只允许服务器 Profile 和迁移标记访问它；角色、私人资料和同步状态只使用 workspace 数据库。角色 schema v10 已增加 `markdownMirror`，所有本地与远端角色写入都会从结构化事实源重建可读 Markdown。

---

## 文件结构

### 服务端

- 修改：`apps/server_nest/prisma/schema.prisma`
- 创建：`apps/server_nest/prisma/migrations/20260729120000_add_server_instance_id/migration.sql`
- 修改：`apps/server_nest/src/modules/server-settings/server-settings.types.ts`
- 修改：`apps/server_nest/src/modules/server-settings/server-settings.service.ts`
- 修改：`apps/server_nest/src/modules/server-info/server-metadata.type.ts`
- 修改：`apps/server_nest/src/modules/server-info/server-info.service.ts`
- 修改：`apps/server_nest/src/modules/server-info/server-info.controller.ts`
- 修改：`apps/server_nest/test/server-info.e2e-spec.ts`
- 修改：`apps/server_nest/src/modules/server-settings/server-settings.service.spec.ts`

### 客户端服务器配置

- 修改：`apps/client_flutter/lib/src/features/server_profiles/domain/server_metadata.dart`
- 修改：`apps/client_flutter/lib/src/features/server_profiles/domain/server_profile.dart`
- 修改：`apps/client_flutter/lib/src/core/database/tables/core_tables.dart`
- 修改：`apps/client_flutter/lib/src/core/database/app_database.dart`
- 修改：`apps/client_flutter/lib/src/features/server_profiles/data/drift_server_profile_store.dart`
- 修改：`apps/client_flutter/lib/src/features/server_profiles/presentation/server_profiles_page.dart`
- 修改：`apps/client_flutter/test/server_metadata_test.dart`
- 修改：`apps/client_flutter/test/server_profile_migration_test.dart`

### 客户端工作区

- 创建：`apps/client_flutter/lib/src/core/workspace/workspace_identity.dart`
- 创建：`apps/client_flutter/lib/src/core/workspace/workspace_database_factory.dart`
- 创建：`apps/client_flutter/lib/src/core/workspace/workspace_storage_manager.dart`
- 创建：`apps/client_flutter/lib/src/core/workspace/workspace_session_coordinator.dart`
- 修改：`apps/client_flutter/lib/src/core/database/app_database.dart`
- 修改：`apps/client_flutter/lib/src/app/dnd_table_app.dart`
- 修改：`apps/client_flutter/lib/src/features/auth/presentation/auth_controller.dart`
- 创建：`apps/client_flutter/test/workspace_identity_test.dart`
- 创建：`apps/client_flutter/test/workspace_storage_manager_test.dart`
- 创建：`apps/client_flutter/test/workspace_session_coordinator_test.dart`
- 修改：`apps/client_flutter/test/widget_test.dart`

## 任务 1：服务端稳定实例身份

- [ ] **步骤 1：编写失败的服务端测试**

在 `server-settings.service.spec.ts` 增加：

```ts
it('creates and then reuses one stable server instance id', async () => {
  prismaService.serverSetting.findFirst
    .mockResolvedValueOnce(null)
    .mockResolvedValueOnce({
      id: 'singleton',
      instanceId: 'instance-1',
      serverName: 'Friday Table',
      registrationEnabled: true,
      defaultLocale: 'zh-CN',
      maxUploadSizeMb: 20
    });
  prismaService.serverSetting.create.mockResolvedValue({
    id: 'singleton',
    instanceId: 'instance-1',
    serverName: 'D&D Table Tool',
    registrationEnabled: true,
    defaultLocale: 'zh-CN',
    maxUploadSizeMb: 20
  });

  expect((await service.getDiscoverySettings()).instanceId).toBe('instance-1');
  expect((await service.getDiscoverySettings()).instanceId).toBe('instance-1');
});
```

在 `server-info.e2e-spec.ts` 断言：

```ts
expect(body.instanceId).toBe('instance-1');
expect(body.name).toBe('Friday Table');
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```powershell
npm test -- --runInBand src/modules/server-settings/server-settings.service.spec.ts test/server-info.e2e-spec.ts
```

预期：FAIL，缺少 `getDiscoverySettings()` 或 `instanceId`。

- [ ] **步骤 3：增加 Prisma 字段和迁移**

在现有 `ServerSetting` 模型中加入：

```prisma
instanceId String @unique @default(uuid())
```

迁移：

```sql
ALTER TABLE "ServerSetting"
ADD COLUMN "instanceId" TEXT;

UPDATE "ServerSetting"
SET "instanceId" = gen_random_uuid()::text
WHERE "instanceId" IS NULL;

ALTER TABLE "ServerSetting"
ALTER COLUMN "instanceId" SET NOT NULL;

CREATE UNIQUE INDEX "ServerSetting_instanceId_key"
ON "ServerSetting"("instanceId");
```

- [ ] **步骤 4：统一发现设置**

定义：

```ts
export interface ServerDiscoverySettings {
  instanceId: string;
  serverName: string;
  registrationEnabled: boolean;
}
```

`ServerSettingsService.getDiscoverySettings()` 必须查找现有行；不存在时创建一次。`ServerInfoService.getMetadata()` 改为异步并读取该方法，环境变量只提供 `PUBLIC_BASE_URL`。

- [ ] **步骤 5：运行目标测试**

运行相同步骤 2 命令，预期所有测试 PASS。

- [ ] **步骤 6：提交**

```powershell
git commit -m "feat(0.1): add stable server instance identity"
```

## 任务 2：服务器名称与本地备注分离

- [ ] **步骤 1：编写失败的客户端测试**

`server_metadata_test.dart`：

```dart
test('keeps the discovered server name separate from local alias', () {
  const metadata = ServerMetadata(
    instanceId: 'instance-1',
    name: 'Silver Sword',
    version: '0.1.0',
    apiBaseUrl: 'https://table.example/api',
    websocketUrl: 'wss://table.example/campaigns',
    registrationEnabled: true,
    serverMode: 'self_hosted',
    supportedSystems: ['dnd5e'],
  );

  final profile = ServerProfile.fromMetadata(
    baseUrl: 'https://table.example',
    metadata: metadata,
  ).copyWith(localAlias: '周五团');

  expect(profile.id, 'instance-1');
  expect(profile.serverName, 'Silver Sword');
  expect(profile.localAlias, '周五团');
  expect(profile.displayName, '周五团');
});
```

`server_profile_migration_test.dart` 增加重新发现时保留 `localAlias` 的测试。

- [ ] **步骤 2：运行测试并确认失败**

```powershell
flutter test test/server_metadata_test.dart test/server_profile_migration_test.dart
```

预期：FAIL，缺少 `instanceId/serverName/localAlias/displayName`。

- [ ] **步骤 3：扩展客户端模型**

`ServerMetadata` 增加必需 `instanceId`。`ServerProfile` 使用：

```dart
final String id;
final String serverName;
final String? localAlias;
String get displayName =>
    localAlias?.trim().isNotEmpty == true ? localAlias!.trim() : serverName;
```

旧 JSON 没有 `serverName` 时读取 `name`；没有 `instanceId` 时回退旧 `id`。

- [ ] **步骤 4：迁移 Drift**

`ServerProfiles` 保留现有 `name` 物理列作为 `serverName`，新增可空 `localAlias`。数据库 schema 递增到 9，在迁移中添加该列。

`DriftServerProfileStore.saveProfile()`：

- 按 instance ID 保存；
- 相同 base URL 的 legacy profile 在发现后合并；
- 刷新公开名称时保留原 `localAlias/isDefault/lastConnectedAt`。

- [ ] **步骤 5：修改服务器页面**

编辑命令只修改 `localAlias`，文案使用“服务器备注”。列表主标题使用 `displayName`，副标题在存在备注时显示 `serverName`。

- [ ] **步骤 6：运行目标测试与 analyze**

```powershell
flutter test test/server_metadata_test.dart test/server_profile_migration_test.dart
flutter analyze --no-fatal-infos
```

预期：PASS，无 analyze 问题。

- [ ] **步骤 7：提交**

```powershell
git commit -m "feat(0.1): separate server name from local alias"
```

## 任务 3：工作区身份和数据库命名

- [ ] **步骤 1：编写失败的纯领域测试**

`workspace_identity_test.dart`：

```dart
test('builds stable and path-safe workspace keys', () {
  const local = LocalWorkspaceIdentity();
  const account = AccountWorkspaceIdentity(
    serverInstanceId: 'server/unsafe',
    userId: 'user:1',
  );

  expect(local.storageKey, 'local');
  expect(account.storageKey, startsWith('account_'));
  expect(account.storageKey, isNot(contains('/')));
  expect(account.storageKey, isNot(contains(':')));
});
```

- [ ] **步骤 2：运行并确认失败**

```powershell
flutter test test/workspace_identity_test.dart
```

- [ ] **步骤 3：实现身份**

账号 storage key 使用两个原始 ID 的 SHA-256 摘要，不把用户输入直接写入路径：

```dart
String get storageKey =>
    'account_${sha256.convert(utf8.encode('$serverInstanceId:$userId'))}';
```

- [ ] **步骤 4：让 AppDatabase 支持命名**

增加：

```dart
AppDatabase.named(String databaseName)
    : super(_openConnection(databaseName));
```

原 `AppDatabase()` 继续打开 legacy `app.db`，测试构造器不变。`_openConnection` 将名称传给 Drift。

- [ ] **步骤 5：实现数据库工厂**

```dart
abstract interface class WorkspaceDatabaseFactory {
  Future<AppDatabase> open(WorkspaceIdentity identity);
}
```

生产实现按 `workspace_${identity.storageKey}` 命名，测试实现返回独立内存数据库。

- [ ] **步骤 6：运行测试**

```powershell
flutter test test/workspace_identity_test.dart
```

- [ ] **步骤 7：提交**

```powershell
git commit -m "feat(0.1): add stable workspace identities"
```

## 任务 4：工作区管理与生命周期

- [ ] **步骤 1：编写失败测试**

`workspace_storage_manager_test.dart` 覆盖：

```dart
test('closes the previous database before publishing the next workspace', () async {
  final factory = RecordingWorkspaceDatabaseFactory();
  final manager = WorkspaceStorageManager(factory: factory);

  await manager.activate(const LocalWorkspaceIdentity());
  await manager.activate(const AccountWorkspaceIdentity(
    serverInstanceId: 'server-1',
    userId: 'user-1',
  ));

  expect(factory.events, ['open:local', 'close:local', 'open:account']);
  expect(manager.identity, isA<AccountWorkspaceIdentity>());
});
```

并覆盖相同身份不重复打开、dispose 关闭数据库和打开失败时保留旧工作区。

- [ ] **步骤 2：运行并确认失败**

```powershell
flutter test test/workspace_storage_manager_test.dart
```

- [ ] **步骤 3：实现 manager**

`WorkspaceStorageManager` 暴露：

```dart
WorkspaceIdentity? get identity;
AppDatabase? get database;
int get generation;
Future<void> activate(WorkspaceIdentity identity);
Future<void> dispose();
```

成功打开新数据库后才替换公开引用；替换完成后关闭旧数据库。通过 generation 让应用重建依赖树。

- [ ] **步骤 4：运行测试**

重复步骤 2，预期 PASS。

- [ ] **步骤 5：提交**

```powershell
git commit -m "feat(0.1): manage private workspace lifecycle"
```

## 任务 5：旧数据库迁入 local

- [ ] **步骤 1：编写迁移测试**

构造 legacy 内存库，写入一个角色和一个资料包；运行迁移后断言：

- local 工作区存在相同角色和资料；
- legacy 数据未被删除；
- 第二次运行不重复写入；
- 迁移标记只在全部复制成功后写入。

- [ ] **步骤 2：运行并确认失败**

```powershell
flutter test test/workspace_storage_manager_test.dart
```

- [ ] **步骤 3：实现迁移器**

创建 `LegacyWorkspaceMigrator`，复用 `DriftLocalDataArchiveService` 的结构化导出/导入边界，不手写表级字符串复制。迁移目标固定为 local，账号认领留给后续 UI。

- [ ] **步骤 4：运行测试**

目标测试预期 PASS。

- [ ] **步骤 5：提交**

```powershell
git commit -m "feat(0.1): migrate legacy data into local workspace"
```

## 任务 6：认证驱动工作区切换

- [ ] **步骤 1：编写失败测试**

`workspace_session_coordinator_test.dart` 覆盖：

- 未登录激活 local；
- 登录 `server-1/user-1` 激活对应账号；
- 网络断开但认证对象仍存在时不切回 local；
- 明确 logout 后切回 local；
- 切换账号时旧同步停止后再切数据库。

- [ ] **步骤 2：运行并确认失败**

```powershell
flutter test test/workspace_session_coordinator_test.dart
```

- [ ] **步骤 3：实现协调器**

协调器监听 `ActiveServerSession` 和 `AuthController`。账号身份只取服务端 metadata 的 instanceId 与认证 user.id，不取用户名。

- [ ] **步骤 4：接入应用组合**

`DndTableApp`：

- 全局依赖持有 bootstrap store 和 workspace manager；
- `MainShell` 使用当前 workspace database；
- generation 改变时用 `ValueKey` 重建工作区 Controller；
- 测试注入 database 时保持单库兼容模式。

- [ ] **步骤 5：运行应用测试**

```powershell
flutter test test/workspace_session_coordinator_test.dart test/widget_test.dart
flutter analyze --no-fatal-infos
```

- [ ] **步骤 6：提交**

```powershell
git commit -m "feat(0.1): switch private workspace with authentication"
```

## 任务 7：基础批次验证

- [ ] **步骤 1：服务端验证**

```powershell
npm test -- --runInBand src/modules/server-settings/server-settings.service.spec.ts test/server-info.e2e-spec.ts
npm run lint
npm run build
npx prisma validate
```

- [ ] **步骤 2：客户端验证**

```powershell
flutter test test/server_metadata_test.dart test/server_profile_migration_test.dart test/workspace_identity_test.dart test/workspace_storage_manager_test.dart test/workspace_session_coordinator_test.dart test/widget_test.dart
flutter analyze --no-fatal-infos
```

- [ ] **步骤 3：迁移与启动验证**

```powershell
docker compose build server
docker compose up -d --force-recreate server
```

验证：

- `/.well-known/dnd-tool-server` 返回稳定 instanceId；
- 修改服务器名称后发现接口返回新名称但 instanceId 不变；
- local 创建角色后登录不会直接出现在账号工作区；
- 登录状态断网后角色仍来自账号工作区；
- logout 后只显示 local 数据。

- [ ] **步骤 4：更新执行状态**

在 `docs/roadmap/current-execution-status.md` 记录实际测试总数、迁移结果和残余风险。
