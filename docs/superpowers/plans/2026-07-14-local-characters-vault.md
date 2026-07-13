# 本地角色与跨设备 Vault 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 把个人角色迁移为本地事实来源，并通过可选 Personal Vault 跨设备同步角色、设置、收藏、笔记和个人自定义条目，同时永不上传本地基础资料包正文。

**架构：** `CharacterRepository` 只操作 Drift；角色命令先提交本地事务和 Vault Outbox。NestJS Vault 使用通用 JSON 实体、单调 cursor 和幂等 operation ID；客户端推送 Outbox 后拉取变化并合并。本地资料引用保存稳定键与必要快照，缺少资料包时角色仍完整可用。

**技术栈：** Flutter、Drift、NestJS、Prisma、PostgreSQL、REST、flutter_test、Jest

---

## 前置条件

按顺序完成：

1. `docs/superpowers/plans/2026-07-14-offline-foundation.md`
2. `docs/superpowers/plans/2026-07-14-local-compendium.md`

## 文件与职责

- 创建 `apps/client_flutter/lib/src/features/characters/data/local/character_tables.dart`。
- 创建 `apps/client_flutter/lib/src/features/characters/data/character_repository.dart`。
- 创建 `apps/client_flutter/lib/src/features/characters/data/local/drift_character_repository.dart`。
- 创建 `apps/client_flutter/lib/src/features/characters/domain/character_content_reference.dart`。
- 重构 `apps/client_flutter/lib/src/features/characters/presentation/character_controller.dart`。
- 修改角色创建、详情和列表页面以移除登录门禁。
- 创建 `apps/client_flutter/lib/src/features/vault/domain/vault_models.dart`。
- 创建 `apps/client_flutter/lib/src/features/vault/data/vault_api_client.dart`。
- 创建 `apps/client_flutter/lib/src/features/vault/data/vault_sync_service.dart`。
- 创建 `apps/client_flutter/lib/src/features/vault/presentation/vault_sync_controller.dart`。
- 创建 `apps/server_nest/src/modules/vault/` 模块。
- 修改 `apps/server_nest/prisma/schema.prisma`。
- 测试 `apps/client_flutter/test/character_repository_test.dart`。
- 测试 `apps/client_flutter/test/character_offline_test.dart`。
- 测试 `apps/client_flutter/test/vault_sync_service_test.dart`。
- 测试 `apps/server_nest/test/vault.e2e-spec.ts`。

### 任务 1：持久化本地角色和资料快照

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/data/local/character_tables.dart`
- 创建：`apps/client_flutter/lib/src/features/characters/data/character_repository.dart`
- 创建：`apps/client_flutter/lib/src/features/characters/data/local/drift_character_repository.dart`
- 创建：`apps/client_flutter/lib/src/features/characters/domain/character_content_reference.dart`
- 修改：`apps/client_flutter/lib/src/core/database/app_database.dart`
- 创建：`apps/client_flutter/test/character_repository_test.dart`
- 创建：`apps/client_flutter/test/support/character_test_support.dart`

- [x] **步骤 1：写离线角色和快照失败测试**

```dart
test('creates a character and keeps a content snapshot after package removal', () async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = DriftCharacterRepository(database);
  final character = CharacterSheet.local(
    id: 'character-1',
    name: 'Arannis',
    level: 2,
    contentReferences: const [
      CharacterContentReference(
        slot: 'class',
        entryKey: 'example:class/fighter',
        sourceRevision: 1,
        snapshot: {'name': '战士', 'hitDie': 'd10'},
      ),
    ],
  );

  await repository.save(character);
  final loaded = await repository.getById('character-1');
  expect(loaded!.name, 'Arannis');
  expect(loaded.contentReferences.single.snapshot['name'], '战士');
  await database.close();
});
```

- [x] **步骤 2：运行并确认本地 Repository 缺失**

```powershell
cd apps/client_flutter
flutter test test/character_repository_test.dart
```

预期：FAIL，`DriftCharacterRepository` 和 `CharacterContentReference` 不存在。

- [x] **步骤 3：实现表与接口**

```dart
abstract interface class CharacterRepository {
  Stream<List<CharacterSheet>> watchOwnedCharacters();
  Future<CharacterSheet?> getById(String id);
  Future<void> save(CharacterSheet character);
  Future<void> archive(String id);
  Future<void> delete(String id);
}
```

`Characters` 表保存 `id/ownerLocalId/sheetJson/revision/syncRevision/archivedAt/createdAt/updatedAt`；`CharacterContentRefs` 保存 `characterId/slot/entryKey/sourceRevision/snapshotJson`。`save` 在单事务内 upsert 角色并替换其引用。将数据库 schema 升至 `3`。

在 `test/support/character_test_support.dart` 创建 `MemoryCharacterRepository implements CharacterRepository`，用 `Map<String, CharacterSheet>` 存储角色并支持 `initial` 构造参数；提供 `testCharacter({id, name, notes})`，返回完整且稳定的最小角色。后续测试统一使用这些名字，不再依赖隐式 fixture。

- [x] **步骤 4：生成代码并验证**

```powershell
cd apps/client_flutter
dart run build_runner build --delete-conflicting-outputs
flutter test test/character_repository_test.dart test/app_database_test.dart
```

预期：角色、快照和 schema 升级测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/core/database apps/client_flutter/lib/src/features/characters/data apps/client_flutter/lib/src/features/characters/domain apps/client_flutter/test/character_repository_test.dart apps/client_flutter/test/support/character_test_support.dart
git commit -m "feat(0.1): persist characters and content snapshots locally"
```

### 任务 2：让角色创建与角色卡完全离线

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_controller.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart`
- 创建：`apps/client_flutter/test/character_offline_test.dart`

- [x] **步骤 1：写未登录创建失败测试**

```dart
Widget buildOfflineCharacterApp(CharacterRepository repository) {
  return MaterialApp(
    home: CharactersTabPage(
      controller: CharacterController(repository: repository),
    ),
  );
}

testWidgets('creates and edits a character without an auth session', (tester) async {
  final repository = MemoryCharacterRepository();
  await tester.pumpWidget(buildOfflineCharacterApp(repository));
  await tester.tap(find.widgetWithText(FloatingActionButton, '新角色'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('character-name')), 'Arannis');
  await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
  await tester.pumpAndSettle();
  expect(find.text('Arannis'), findsOneWidget);
  expect(await repository.getById('character-1'), isNotNull);
});
```

- [x] **步骤 2：运行并确认登录门禁失败**

```powershell
cd apps/client_flutter
flutter test test/character_offline_test.dart
```

预期：FAIL，当前 Controller 因 Access Token 为空返回 false。

- [x] **步骤 3：改造 Controller 构造与命令**

```dart
class CharacterController extends ChangeNotifier {
  CharacterController({required CharacterRepository repository})
      : _repository = repository;
  final CharacterRepository _repository;

  Future<bool> createCharacter(CharacterEditDraft draft) async {
    final character = draft.toLocalCharacter();
    await _repository.save(character);
    _lastCreatedCharacter = character;
    notifyListeners();
    return true;
  }
}
```

移除个人角色列表、创建、编辑和运行时状态对 `AuthController`、`apiBaseUrl` 和 `CharacterClient` 的依赖。战役发布动作留在第四份计划的独立 `CampaignActorController`。

- [x] **步骤 4：验证所有角色测试**

```powershell
cd apps/client_flutter
flutter test test/character_offline_test.dart test/character_pages_test.dart test/character_controller_test.dart
flutter analyze
```

预期：未登录创建、现有角色卡、运行时资源和编辑测试全部通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/characters/presentation apps/client_flutter/test/character_offline_test.dart apps/client_flutter/test/character_pages_test.dart apps/client_flutter/test/character_controller_test.dart
git commit -m "refactor(0.1): make personal characters fully offline"
```

### 任务 3：建立服务端 Personal Vault 数据模型

**文件：**
- 修改：`apps/server_nest/prisma/schema.prisma`
- 创建：`apps/server_nest/src/modules/vault/vault.types.ts`
- 创建：`apps/server_nest/src/modules/vault/vault.service.ts`
- 创建：`apps/server_nest/src/modules/vault/vault.controller.ts`
- 创建：`apps/server_nest/src/modules/vault/vault.module.ts`
- 修改：`apps/server_nest/src/app.module.ts`
- 创建：`apps/server_nest/test/vault.e2e-spec.ts`

- [x] **步骤 1：写用户隔离和幂等失败测试**

```typescript
it('pushes an operation once and returns changes after the cursor', async () => {
  const operation = {
    operationId: 'op-1',
    entityType: 'character',
    entityId: 'character-1',
    baseRevision: 0,
    operation: 'upsert',
    payload: { name: 'Arannis' },
  };
  await request(app.getHttpServer())
    .post('/api/vault/push')
    .set('Authorization', 'Bearer player-token')
    .set('X-Device-Id', 'device-1')
    .send({ operations: [operation, operation] })
    .expect(200);

  const response = await request(app.getHttpServer())
    .get('/api/vault/changes?cursor=0')
    .set('Authorization', 'Bearer player-token')
    .set('X-Device-Id', 'device-1')
    .expect(200);
  expect(response.body.changes).toHaveLength(1);
  expect(response.body.changes[0].entityId).toBe('character-1');
});
```

- [x] **步骤 2：运行并确认端点不存在**

```powershell
npm --prefix apps/server_nest test -- vault.e2e-spec.ts
```

预期：FAIL，Vault 路由返回 404。

- [x] **步骤 3：增加 Prisma 模型**

```prisma
model VaultEntity {
  id         String   @id @default(uuid())
  userId     String
  entityType String
  entityId   String
  payload    Json
  revision   Int      @default(1)
  deletedAt  DateTime?
  updatedAt  DateTime @updatedAt
  user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@unique([userId, entityType, entityId])
  @@index([userId, updatedAt])
}

model VaultChange {
  cursor     BigInt   @id @default(autoincrement())
  userId     String
  entityType String
  entityId   String
  operation  String
  payload    Json
  revision   Int
  createdAt  DateTime @default(now())
  @@index([userId, cursor])
}

model VaultOperation {
  operationId String   @id
  userId      String
  createdAt   DateTime @default(now())
  @@index([userId])
}

model VaultDevice {
  id         String    @id @default(uuid())
  userId     String
  deviceId   String
  name       String
  platform   String
  lastCursor BigInt    @default(0)
  lastSeenAt DateTime  @default(now())
  revokedAt  DateTime?
  user       User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  @@unique([userId, deviceId])
  @@index([userId, lastSeenAt])
}
```

给 `User` 增加 `vaultEntities VaultEntity[]` 和 `vaultDevices VaultDevice[]`。服务端把 BigInt cursor 序列化为十进制字符串。

- [x] **步骤 4：实现 push/changes 并验证**

`POST /vault/push` 在事务中跳过已存在 operation ID，校验 `baseRevision`，upsert/tombstone 实体并写 change；冲突返回 HTTP 409 和当前实体。`GET /vault/changes` 只查询当前用户且 `cursor > supplied`，最多返回 500 项。push/changes 都要求 `X-Device-Id`，并更新设备名称、平台、lastCursor 和 lastSeenAt；已撤销设备返回 403。增加 `GET /vault/devices` 与 `DELETE /vault/devices/:deviceId`，只允许用户查看和撤销自己的设备，不能撤销当前请求设备。删除 tombstone 仅在所有 90 天内活跃且未撤销设备的 lastCursor 越过该 change 后清理，超过 180 天可强制过期。测试覆盖设备隔离、撤销、cursor 更新和 tombstone 保留。

运行：

```powershell
npm --prefix apps/server_nest run prisma:generate
npm --prefix apps/server_nest test -- vault.e2e-spec.ts
npm run lint:server
```

预期：隔离、幂等、cursor 和冲突测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/server_nest/prisma/schema.prisma apps/server_nest/src/modules/vault apps/server_nest/src/app.module.ts apps/server_nest/test/vault.e2e-spec.ts
git commit -m "feat(0.1): add personal vault sync api"
```

### 任务 4：实现客户端 Vault push/pull

**文件：**
- 创建：`apps/client_flutter/lib/src/features/vault/domain/vault_models.dart`
- 创建：`apps/client_flutter/lib/src/features/vault/data/vault_api_client.dart`
- 创建：`apps/client_flutter/lib/src/features/vault/data/vault_sync_service.dart`
- 创建：`apps/client_flutter/test/vault_api_client_test.dart`
- 创建：`apps/client_flutter/test/vault_sync_service_test.dart`
- 创建：`apps/client_flutter/test/support/vault_test_support.dart`

- [x] **步骤 1：写 push 后 pull 的失败测试**

```dart
test('pushes outbox before applying remote changes and cursor', () async {
  const characterOperation = SyncOperation(
    id: 'op-1',
    scope: 'vault',
    entityType: 'character',
    entityId: 'character-1',
    baseRevision: 0,
    payloadJson: '{"name":"Arannis"}',
  );
  const remoteNoteChange = VaultChange(
    cursor: '8',
    operation: 'upsert',
    entityType: 'note',
    entityId: 'note-1',
    revision: 1,
    payloadJson: '{"markdown":"Remember the harbor"}',
  );
  const session = VaultSession(
    remoteUserId: 'user-1',
    deviceId: 'device-1',
    baseUrl: 'https://table.example',
    accessToken: 'token',
  );
  final outbox = MemorySyncRepository(pendingOperations: [characterOperation]);
  final api = MemoryVaultApiClient(
    changes: VaultChangePage(
      cursor: '8',
      changes: [remoteNoteChange],
      hasMore: false,
    ),
  );
  final applier = MemoryVaultChangeApplier();
  final service = VaultSyncService(
    syncRepository: outbox,
    apiClient: api,
    changeApplier: applier,
  );

  await service.sync(session);
  expect(api.pushedOperationIds, ['op-1']);
  expect(applier.appliedEntityIds, ['note-1']);
  expect(await outbox.readCursor('vault', 'user-1'), '8');
});
```

- [x] **步骤 2：运行并确认 Vault 客户端缺失**

```powershell
cd apps/client_flutter
flutter test test/vault_api_client_test.dart test/vault_sync_service_test.dart
```

预期：FAIL，Vault 类型和服务不存在。

- [x] **步骤 3：实现接口和同步顺序**

```dart
abstract interface class VaultApiClient {
  Future<VaultPushResult> push(VaultSession session, List<SyncOperation> operations);
  Future<VaultChangePage> changes(VaultSession session, String cursor);
  Future<List<VaultDeviceView>> listDevices(VaultSession session);
  Future<void> revokeDevice(VaultSession session, String deviceId);
}

abstract interface class VaultChangeApplier {
  Future<void> applyAll(List<VaultChange> changes);
}
```

`vault_models.dart` 同时定义不可变 `VaultSession(remoteUserId, deviceId, baseUrl, accessToken)` 和 `VaultDeviceView(deviceId, name, platform, lastSeenAt, isCurrent)`；后两个字段为可空时间和默认 false。不得把 Token 写入 Drift 或日志。deviceId 在首次运行生成并持久化，恢复备份时不覆盖当前设备 ID。在 `test/support/vault_test_support.dart` 实现 `MemorySyncRepository`、`MemoryVaultApiClient` 和 `MemoryVaultChangeApplier`：分别记录 pending/cursor、`pushedOperationIds` 与 `appliedEntityIds`，方法签名完整实现生产接口。

`VaultSyncService.sync` 固定执行：读取 Outbox、最多 100 项 push、标记完成、读取 cursor、循环拉取直至 `hasMore == false`、事务应用、保存 cursor。网络异常增加 attempts 并保持 Outbox；409 转为 `SyncPhase.conflict`。

- [x] **步骤 4：验证 URL、Bearer、失败保留与幂等**

```powershell
cd apps/client_flutter
flutter test test/vault_api_client_test.dart test/vault_sync_service_test.dart test/sync_repository_test.dart
flutter analyze
```

预期：HTTP 契约和同步顺序测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/vault apps/client_flutter/test/vault_api_client_test.dart apps/client_flutter/test/vault_sync_service_test.dart apps/client_flutter/test/support/vault_test_support.dart
git commit -m "feat(0.1): sync personal vault across devices"
```

### 任务 5：把个人实体接入 Vault Outbox

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/data/local/drift_character_repository.dart`
- 修改：`apps/client_flutter/lib/src/features/content/data/local/content_repository.dart`
- 修改：`apps/client_flutter/lib/src/features/app_preferences/data/app_preferences_store.dart`
- 创建：`apps/client_flutter/lib/src/features/vault/data/drift_vault_change_applier.dart`
- 修改：`apps/client_flutter/test/vault_sync_service_test.dart`
- 修改：`apps/client_flutter/test/character_repository_test.dart`

- [x] **步骤 1：写本地修改自动入队失败测试**

```dart
test('saving a character writes the character and vault operation atomically', () async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = DriftCharacterRepository(database);
  final arannis = testCharacter(
    id: 'character-1',
    name: 'Arannis',
    notes: 'Local notes',
  );
  await repository.save(arannis);
  final pending = await DriftSyncRepository(database).pending(scope: 'vault');
  expect(pending, hasLength(1));
  expect(pending.single.entityType, 'character');
  expect(pending.single.entityId, arannis.id);
  await database.close();
});
```

- [x] **步骤 2：运行并确认 Outbox 为空**

```powershell
cd apps/client_flutter
flutter test test/character_repository_test.dart --plain-name "saving a character writes the character and vault operation atomically"
```

预期：FAIL，角色保存尚未写 Outbox。

- [x] **步骤 3：实现原子入队和远端应用**

个人实体类型固定为 `character`、`personalContentEntry`、`favorite`、`note`、`bookmark`、`preferences`、`installedPackageManifest`。资料包 manifest payload 只含 `id/version/locale/system/contentHash`，不得含 `body`、`entries` 或 assets。远端应用使用 `syncRevision` 防止重复，不再产生新的 Outbox 操作。

- [x] **步骤 4：验证所有实体及禁止正文上传**

增加测试断言 package manifest operation JSON 不包含 `entries` 和 `body`。运行：

```powershell
cd apps/client_flutter
flutter test test/character_repository_test.dart test/content_repository_test.dart test/vault_sync_service_test.dart
```

预期：原子保存、远端合并和正文禁止测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/characters/data/local apps/client_flutter/lib/src/features/content/data/local apps/client_flutter/lib/src/features/app_preferences/data apps/client_flutter/lib/src/features/vault/data apps/client_flutter/test
git commit -m "feat(0.1): enqueue personal data for vault sync"
```

### 任务 6：迁移已有服务器角色且不覆盖本地数据

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/data/legacy_character_importer.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/data/character_api_client.dart`
- 创建：`apps/client_flutter/test/legacy_character_importer_test.dart`
- 修改：`apps/client_flutter/test/support/character_test_support.dart`

- [x] **步骤 1：写一次性迁移失败测试**

```dart
test('imports legacy remote characters once and preserves local conflicts', () async {
  final localArannis = testCharacter(
    id: 'character-1',
    name: 'Arannis',
    notes: 'Keep local notes',
  );
  final remoteArannis = testCharacter(
    id: 'character-1',
    name: 'Arannis',
    notes: 'Remote notes',
  );
  final remoteBorin = testCharacter(
    id: 'character-2',
    name: 'Borin',
    notes: '',
  );
  const session = VaultSession(
    remoteUserId: 'user-1',
    deviceId: 'device-1',
    baseUrl: 'https://table.example',
    accessToken: 'token',
  );
  final local = MemoryCharacterRepository(initial: [localArannis]);
  final legacy = MemoryLegacyCharacterClient(
    characters: [remoteArannis, remoteBorin],
  );
  final markers = MemoryMigrationMarkers();
  final importer = LegacyCharacterImporter(local, legacy, markers);

  await importer.run(session);
  await importer.run(session);

  expect((await local.getById(localArannis.id))!.notes, localArannis.notes);
  expect(await local.getById(remoteBorin.id), isNotNull);
  expect(markers.completed, contains('legacy-characters:server-1:user-1'));
});
```

- [x] **步骤 2：运行并确认 importer 缺失**

```powershell
cd apps/client_flutter
flutter test test/legacy_character_importer_test.dart
```

预期：FAIL，迁移器不存在。

- [x] **步骤 3：实现明确迁移策略**

首次登录旧服务器时拉取角色；本地不存在相同 ID 则导入，相同 ID 且内容不同则复制远端角色并使用新本地 UUID，名称追加“（服务器导入）”。成功后写服务器+用户 marker。任何失败都不写 marker。

在 `test/support/character_test_support.dart` 增加 `MemoryLegacyCharacterClient`，其 `list(VaultSession)` 返回构造函数传入角色；增加 `MemoryMigrationMarkers`，用 `Set<String> completed` 实现 `contains` 和 `markCompleted`。`LegacyCharacterImporter.run` 参数固定为 `VaultSession`。

- [x] **步骤 4：验证迁移与旧 API 兼容**

```powershell
cd apps/client_flutter
flutter test test/legacy_character_importer_test.dart test/character_api_client_test.dart
```

预期：一次性、冲突复制和失败重试测试通过。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/characters/data apps/client_flutter/test/legacy_character_importer_test.dart apps/client_flutter/test/support/character_test_support.dart
git commit -m "feat(0.1): import legacy server characters safely"
```

### 任务 7：设置页同步控制和完整验证

**文件：**
- 创建：`apps/client_flutter/lib/src/features/vault/presentation/vault_sync_controller.dart`
- 创建：`apps/client_flutter/lib/src/features/vault/presentation/vault_settings_section.dart`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`
- 修改：`apps/client_flutter/test/widget_test.dart`
- 修改：`apps/client_flutter/test/support/vault_test_support.dart`
- 修改：`README.md`
- 修改：`docs/roadmap/current-execution-status.md`

- [x] **步骤 1：写同步控制失败测试**

```dart
testWidgets('shows pending vault operations and syncs on command', (tester) async {
  final controller = MemoryVaultSyncActions(
    pendingCount: 3,
    devices: const [
      VaultDeviceView(deviceId: 'device-1', name: '此设备', platform: 'windows'),
      VaultDeviceView(deviceId: 'device-2', name: 'Laptop', platform: 'web'),
    ],
  );
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: VaultSettingsSection(actions: controller)),
  ));
  expect(find.text('3 项等待同步'), findsOneWidget);
  expect(find.text('Laptop'), findsOneWidget);
  await tester.tap(find.text('立即同步'));
  await tester.pumpAndSettle();
  expect(controller.syncCalls, 1);
});
```

- [x] **步骤 2：运行并确认 Vault 设置缺失**

```powershell
cd apps/client_flutter
flutter test test/widget_test.dart --plain-name "shows pending vault operations and syncs on command"
```

预期：FAIL，Vault 设置组件不存在。

- [x] **步骤 3：实现设置状态**

定义可测试的窄接口：

```dart
abstract interface class VaultSyncActions {
  int get pendingCount;
  SyncPhase get phase;
  String? get lastError;
  bool get paused;
  List<VaultDeviceView> get devices;
  Future<void> syncNow();
  Future<void> setPaused(bool paused);
  Future<void> revokeDevice(String deviceId);
}
```

`VaultSyncController` 实现该接口并通过 `ChangeNotifier` 刷新 UI。`MemoryVaultSyncActions` 放在 `test/support/vault_test_support.dart`，保存 `pendingCount`、`devices`、`syncCalls`、`revokedDeviceIds` 和 pause 状态；`syncNow()` 只递增 `syncCalls`。设置页显示账户、pending 数、最近同步、错误、暂停开关、“立即同步”和设备列表；撤销其他设备前确认，当前设备不显示撤销动作。未登录时明确提示同步可选而不禁用本地功能。

登录后显示最后同步时间、待同步数量、立即同步、暂停后台同步和冲突入口；未登录时显示“登录后可跨设备同步”，但不禁用本地角色。错误信息使用可复制详情，不显示 Token 或实体全文。

- [x] **步骤 4：运行跨端门禁**

```powershell
npm run doctor
cd apps/client_flutter
flutter build web --release
```

预期：全量测试、lint、analyze、Compose config 和 Web build 通过。

- [x] **步骤 5：更新文档并提交**

README 说明 Vault 同步范围和基础资料正文不上传；执行状态记录本地角色迁移与缺包快照。提交：

```powershell
git add apps/client_flutter/lib/src/features/vault/presentation apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart apps/client_flutter/test/widget_test.dart apps/client_flutter/test/support/vault_test_support.dart README.md docs/roadmap/current-execution-status.md
git commit -m "feat(0.1): expose personal vault sync controls"
```

## 完成条件

- 未登录、未配置服务器时可创建、编辑和运行角色卡。
- 角色引用保存快照，删除本地资料包后仍可使用。
- Vault 用户隔离、operation 幂等、cursor、tombstone 和冲突有服务端测试。
- 角色、个人条目、收藏、笔记、书签和设置可跨设备同步。
- 本地基础资料正文与 assets 永不进入 Vault payload。
- 旧服务器角色安全导入且不覆盖本地角色。
- `npm run doctor` 与 Web release build 通过。
