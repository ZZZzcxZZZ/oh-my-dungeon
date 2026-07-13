# 离线基础设施实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 引入跨平台 Drift 本地数据库、同步 Outbox 和离线 Main Shell，使应用在没有服务器 Profile、账号或网络时正常启动并使用个人标签页。

**架构：** `AppDatabase` 是客户端持久化入口，DAO 通过 Repository 接口向应用层提供数据。服务器 Profile 成为可选本地配置；`DndTableApp` 始终进入本地 `MainShell`，联网 Controller 由可选 `ActiveServerSession` 延迟创建。同步基础设施只管理状态、Outbox 和 cursor，不在本计划实现具体业务同步。

**技术栈：** Flutter、Dart 3.11、Material 3、Drift、SQLite/WASM、flutter_test

---

## 文件与职责

- 创建 `apps/client_flutter/lib/src/core/database/app_database.dart`：Drift 数据库及 schema 版本。
- 创建 `apps/client_flutter/lib/src/core/database/database_connection.dart`：Native/Web 数据库连接。
- 创建 `apps/client_flutter/lib/src/core/database/tables/core_tables.dart`：Profile、Outbox、cursor 和迁移标记表。
- 创建 `apps/client_flutter/lib/src/core/sync/sync_models.dart`：同步状态、操作和 cursor 的纯 Dart 类型。
- 创建 `apps/client_flutter/lib/src/core/sync/sync_repository.dart`：Outbox/cursor 接口与 Drift 实现。
- 创建 `apps/client_flutter/lib/src/core/sync/sync_status_controller.dart`：面向 UI 的同步状态。
- 创建 `apps/client_flutter/lib/src/features/server_profiles/data/drift_server_profile_store.dart`：Profile 的 Drift Store。
- 创建 `apps/client_flutter/lib/src/features/server_profiles/data/server_profile_migrator.dart`：SharedPreferences 一次性迁移。
- 创建 `apps/client_flutter/lib/src/features/server_home/domain/active_server_session.dart`：可空的当前服务器会话。
- 修改 `apps/client_flutter/lib/src/app/dnd_table_app.dart`：本地优先依赖注入和无服务器启动。
- 修改 `apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart`：接受可选服务器会话。
- 修改 `apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`：服务器与同步状态入口。
- 测试 `apps/client_flutter/test/app_database_test.dart`。
- 测试 `apps/client_flutter/test/sync_repository_test.dart`。
- 测试 `apps/client_flutter/test/server_profile_migration_test.dart`。
- 测试 `apps/client_flutter/test/offline_shell_test.dart`。

### 任务 1：引入 Drift 并建立可测试数据库

**文件：**
- 修改：`apps/client_flutter/pubspec.yaml`
- 创建：`apps/client_flutter/lib/src/core/database/database_connection.dart`
- 创建：`apps/client_flutter/lib/src/core/database/tables/core_tables.dart`
- 创建：`apps/client_flutter/lib/src/core/database/app_database.dart`
- 创建：`apps/client_flutter/test/app_database_test.dart`

- [ ] **步骤 1：添加失败的空数据库测试**

```dart
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens an empty schema at version one', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    expect(database.schemaVersion, 1);
    expect(await database.select(database.serverProfiles).get(), isEmpty);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    await database.close();
  });
}
```

- [ ] **步骤 2：运行测试并确认缺少 `AppDatabase`**

运行：

```powershell
cd apps/client_flutter
flutter test test/app_database_test.dart
```

预期：FAIL，提示 `core/database/app_database.dart` 不存在。

- [ ] **步骤 3：加入依赖和最小 schema**

在 `pubspec.yaml` 加入：

```yaml
dependencies:
  drift: ^2.34.1
  drift_flutter: ^0.3.0
  sqlite3_flutter_libs: ^0.5.41
  path_provider: ^2.1.5
  path: ^1.9.1

dev_dependencies:
  build_runner: ^2.6.0
  drift_dev: ^2.34.1
```

`core_tables.dart` 定义：

```dart
import 'package:drift/drift.dart';

class ServerProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get apiBaseUrl => text()();
  TextColumn get websocketUrl => text()();
  TextColumn get lastKnownVersion => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get baseRevision => integer()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncCursors extends Table {
  TextColumn get scope => text()();
  TextColumn get remoteId => text()();
  TextColumn get cursor => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {scope, remoteId};
}

class MigrationMarkers extends Table {
  TextColumn get key => text()();
  DateTimeColumn get completedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}
```

`app_database.dart` 使用 `@DriftDatabase` 注册四张表，提供 `AppDatabase.defaults()` 与 `AppDatabase.forTesting(QueryExecutor executor)`，`schemaVersion` 返回 `1`。

- [ ] **步骤 4：生成代码并验证测试通过**

```powershell
cd apps/client_flutter
dart run build_runner build --delete-conflicting-outputs
flutter test test/app_database_test.dart
```

预期：PASS，1 个测试通过。

- [ ] **步骤 5：配置 Web worker 并验证 Web 构建**

创建 `apps/client_flutter/web/drift_worker.dart`：

```dart
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
```

运行：

```powershell
cd apps/client_flutter
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.dart.js
Invoke-WebRequest -Uri https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm -OutFile web/sqlite3.wasm
flutter build web --release
```

预期：`build/web/index.html`、`build/web/sqlite3.wasm` 和 worker 均存在。

- [ ] **步骤 6：提交**

```powershell
git add apps/client_flutter/pubspec.yaml apps/client_flutter/pubspec.lock apps/client_flutter/lib/src/core/database apps/client_flutter/test/app_database_test.dart apps/client_flutter/web
git commit -m "feat(0.1): add cross-platform local database"
```

### 任务 2：实现 Outbox、cursor 与同步状态

**文件：**
- 创建：`apps/client_flutter/lib/src/core/sync/sync_models.dart`
- 创建：`apps/client_flutter/lib/src/core/sync/sync_repository.dart`
- 创建：`apps/client_flutter/lib/src/core/sync/sync_status_controller.dart`
- 创建：`apps/client_flutter/test/sync_repository_test.dart`

- [ ] **步骤 1：编写失败的幂等 Outbox 测试**

```dart
test('queues an operation once and advances a cursor', () async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = DriftSyncRepository(database);
  const operation = SyncOperation(
    id: 'op-1',
    scope: 'vault',
    entityType: 'character',
    entityId: 'character-1',
    baseRevision: 3,
    payloadJson: '{"name":"Arannis"}',
  );

  await repository.enqueue(operation);
  await repository.enqueue(operation);
  expect(await repository.pending(scope: 'vault'), [operation]);

  await repository.saveCursor(
    scope: 'vault',
    remoteId: 'user-1',
    cursor: '42',
  );
  expect(await repository.readCursor('vault', 'user-1'), '42');
  await database.close();
});
```

- [ ] **步骤 2：运行测试并确认类型缺失**

```powershell
cd apps/client_flutter
flutter test test/sync_repository_test.dart
```

预期：FAIL，`SyncOperation` 与 `DriftSyncRepository` 未定义。

- [ ] **步骤 3：实现明确接口**

```dart
enum SyncPhase { offline, idle, syncing, conflict, error }

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.baseRevision,
    required this.payloadJson,
  });
  final String id;
  final String scope;
  final String entityType;
  final String entityId;
  final int baseRevision;
  final String payloadJson;
}

abstract interface class SyncRepository {
  Future<void> enqueue(SyncOperation operation);
  Future<List<SyncOperation>> pending({required String scope});
  Future<void> markCompleted(String operationId);
  Future<void> markAttemptFailed(String operationId);
  Future<String?> readCursor(String scope, String remoteId);
  Future<void> saveCursor({
    required String scope,
    required String remoteId,
    required String cursor,
  });
}
```

`DriftSyncRepository.enqueue` 使用 `insertOnConflictDoNothing`；`saveCursor` 使用 upsert。`SyncStatusController` 暴露 `phase`、`pendingCount`、`lastError` 和 `refresh()`。

- [ ] **步骤 4：验证 Repository 和 analyzer**

```powershell
cd apps/client_flutter
dart run build_runner build --delete-conflicting-outputs
flutter test test/sync_repository_test.dart
flutter analyze
```

预期：测试通过，analyzer 无问题。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/core/sync apps/client_flutter/lib/src/core/database apps/client_flutter/test/sync_repository_test.dart
git commit -m "feat(0.1): add offline sync outbox"
```

### 任务 3：把服务器 Profile 迁入 Drift

**文件：**
- 创建：`apps/client_flutter/lib/src/features/server_profiles/data/drift_server_profile_store.dart`
- 创建：`apps/client_flutter/lib/src/features/server_profiles/data/server_profile_migrator.dart`
- 修改：`apps/client_flutter/lib/src/features/server_profiles/data/server_profile_store.dart`
- 创建：`apps/client_flutter/test/server_profile_migration_test.dart`

- [ ] **步骤 1：编写迁移失败测试**

```dart
test('migrates shared-preferences profiles only once', () async {
  SharedPreferences.setMockInitialValues({
    'server_profiles': [
      '{"id":"local","name":"Local","baseUrl":"http://localhost:3000","apiBaseUrl":"http://localhost:3000/api","websocketUrl":"ws://localhost:3000/ws"}'
    ],
    'default_server_profile_id': 'local',
  });
  final preferences = await SharedPreferences.getInstance();
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final migrator = ServerProfileMigrator(database, preferences);

  await migrator.run();
  await migrator.run();

  final store = DriftServerProfileStore(database);
  expect(await store.listProfiles(), hasLength(1));
  expect(await store.getDefaultProfileId(), 'local');
  await database.close();
});
```

- [ ] **步骤 2：运行并确认迁移器缺失**

```powershell
cd apps/client_flutter
flutter test test/server_profile_migration_test.dart
```

预期：FAIL，迁移器和 Drift Store 未定义。

- [ ] **步骤 3：实现 Store 和一次性迁移**

`DriftServerProfileStore` 完整实现现有 `ServerProfileStore` 接口。`ServerProfileMigrator.run()` 在事务中检查 `MigrationMarkers.key == 'server-profiles-v1'`，读取旧 Store，写入全部 Profile 和默认标志，再写 marker。迁移成功后保留 SharedPreferences 原值一个版本，不主动删除。

- [ ] **步骤 4：运行迁移与旧 Store 契约测试**

```powershell
cd apps/client_flutter
flutter test test/server_profile_migration_test.dart test/widget_test.dart --plain-name "marks a saved server profile as default"
```

预期：新迁移测试和既有 Profile 行为均通过。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/server_profiles apps/client_flutter/test/server_profile_migration_test.dart
git commit -m "feat(0.1): persist server profiles in drift"
```

### 任务 4：解除服务器启动门禁

**文件：**
- 创建：`apps/client_flutter/lib/src/features/server_home/domain/active_server_session.dart`
- 修改：`apps/client_flutter/lib/src/app/dnd_table_app.dart`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart`
- 创建：`apps/client_flutter/test/offline_shell_test.dart`

- [ ] **步骤 1：写无服务器启动失败测试**

```dart
testWidgets('opens the local shell without a server profile', (tester) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(DndTableApp(database: database));
  await tester.pumpAndSettle();

  expect(find.text('首页'), findsWidgets);
  expect(find.text('战役'), findsWidgets);
  expect(find.text('角色'), findsWidgets);
  expect(find.text('资料库'), findsWidgets);
  expect(find.text('设置'), findsWidgets);
  expect(find.text('连接你的跑团服务器'), findsNothing);
  await database.close();
});
```

- [ ] **步骤 2：运行并确认仍进入服务器引导**

```powershell
cd apps/client_flutter
flutter test test/offline_shell_test.dart
```

预期：FAIL，当前首页仍是 `ServerProfilesPage` 或 `database` 参数不存在。

- [ ] **步骤 3：实现可选会话**

```dart
class ActiveServerSession extends ChangeNotifier {
  ServerProfile? _profile;
  ServerProfile? get profile => _profile;
  bool get isConfigured => _profile != null;

  void activate(ServerProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void deactivate() {
    _profile = null;
    notifyListeners();
  }
}
```

`DndTableApp` 新增可注入 `AppDatabase? database`，初始化 Drift Store 和迁移器后始终构建 `MainShell`。删除 `_buildHome` 中 `profile == null` 返回 `ServerProfilesPage` 的分支。`MainShell.profile` 改为 `ActiveServerSession`，个人页面不再读取 Profile；战役页在未配置时显示连接入口。

- [ ] **步骤 4：验证离线 Shell 和原服务器流程**

```powershell
cd apps/client_flutter
flutter test test/offline_shell_test.dart test/widget_test.dart
flutter analyze
```

预期：离线 Shell 测试通过；既有服务器添加、登录和导航测试保持通过。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/app apps/client_flutter/lib/src/features/server_home apps/client_flutter/test/offline_shell_test.dart apps/client_flutter/test/widget_test.dart
git commit -m "refactor(0.1): make the main shell offline-first"
```

### 任务 5：在设置中管理可选服务器与同步状态

**文件：**
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/server_profiles/presentation/server_profiles_page.dart`
- 创建：`apps/client_flutter/lib/src/core/sync/sync_status_tile.dart`
- 修改：`apps/client_flutter/test/widget_test.dart`

- [ ] **步骤 1：写设置页失败测试**

```dart
testWidgets('offline settings exposes servers and sync status', (tester) async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(DndTableApp(database: database));
  await tester.pumpAndSettle();
  await tester.tap(find.text('设置').last);
  await tester.pumpAndSettle();

  expect(find.text('服务器'), findsOneWidget);
  expect(find.text('尚未连接服务器'), findsOneWidget);
  expect(find.text('同步'), findsOneWidget);
  expect(find.text('仅保存在此设备'), findsOneWidget);
  await database.close();
});
```

- [ ] **步骤 2：运行并确认入口缺失**

```powershell
cd apps/client_flutter
flutter test test/widget_test.dart --plain-name "offline settings exposes servers and sync status"
```

预期：FAIL，设置页尚未显示离线服务器和同步分组。

- [ ] **步骤 3：实现 Material 3 设置分组**

使用 `ListTile` 显示当前服务器，`FilledButton.tonalIcon` 打开现有 Profile 管理页；`SyncStatusTile` 根据 `SyncPhase` 显示离线、等待、同步、冲突或错误。未登录时同步副标题固定为“仅保存在此设备”。不得在设置页嵌套 Card。

- [ ] **步骤 4：运行设置与全客户端测试**

```powershell
cd apps/client_flutter
flutter test test/widget_test.dart
flutter analyze
```

预期：测试通过，Material 3 analyzer 无问题。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/core/sync apps/client_flutter/lib/src/features/server_home apps/client_flutter/lib/src/features/server_profiles apps/client_flutter/test/widget_test.dart
git commit -m "feat(0.1): manage optional servers from settings"
```

### 任务 6：建立离线基础验收门禁

**文件：**
- 修改：`scripts/check.ps1`
- 修改：`README.md`
- 修改：`docs/roadmap/current-execution-status.md`

- [ ] **步骤 1：给门禁增加生成代码检查**

在 `scripts/check.ps1` 的客户端 analyze 前执行：

```powershell
Push-Location (Join-Path $root "apps/client_flutter")
try {
  dart run build_runner build --delete-conflicting-outputs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}
```

- [ ] **步骤 2：运行完整门禁**

```powershell
npm run doctor
cd apps/client_flutter
flutter build web --release
```

预期：服务端 lint、Flutter analyze、246 个以上服务端测试、182 个以上客户端测试、Docker Compose config 和 Web build 全部通过。

- [ ] **步骤 3：更新文档中的启动边界**

README 明确写出“无服务器可直接启动”；执行状态记录 Drift、Outbox 和 Profile 迁移完成；删除“默认 Profile 才能进入主界面”的描述。

- [ ] **步骤 4：检查工作树**

```powershell
git diff --check
git status --short
```

预期：无空白错误；只有本任务文档改动未提交。

- [ ] **步骤 5：提交**

```powershell
git add scripts/check.ps1 README.md docs/roadmap/current-execution-status.md
git commit -m "docs(0.1): document offline application foundation"
```

## 完成条件

- 全新安装且没有 Profile 时进入 Main Shell，而不是服务器引导页。
- 首页、角色、资料库和设置不依赖 Token 或 URL。
- Profile 已迁入 Drift，旧 SharedPreferences 数据只迁移一次。
- Outbox 与 cursor 有幂等数据库测试。
- Native 与 Web 数据库均可构建。
- `npm run doctor` 与 Flutter Web release build 通过。
