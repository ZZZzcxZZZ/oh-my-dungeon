# 本地完整资料库实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在默认空资料库的前提下，实现本地资料包导入、全文检索、实体链接、收藏、笔记和完整 Material 3 Wiki 浏览体验。

**架构：** `ContentRepository` 只读写 Drift，本地导入器负责 schema 校验和事务写入。UI 由资料库首页、检索列表、独立详情路由、类型渲染器和设置页包管理组成；当前远端 `ContentApiClient` 不再是个人资料库依赖。战役条目通过同一只读查询接口合并，但其同步实现留给第四份计划。

**技术栈：** Flutter、Drift、archive、crypto、file_picker、Material 3、flutter_test

---

## 前置条件

先完成 `docs/superpowers/plans/2026-07-14-offline-foundation.md`，并确认 `AppDatabase`、本地 Main Shell 和 Drift Web 构建存在。

## 文件与职责

- 创建 `apps/client_flutter/lib/src/features/content/domain/content_entry.dart`：统一 Wiki 条目。
- 创建 `apps/client_flutter/lib/src/features/content/domain/content_block.dart`：安全正文块联合类型。
- 创建 `apps/client_flutter/lib/src/features/content/domain/content_package_manifest.dart`：包 manifest。
- 创建 `apps/client_flutter/lib/src/features/content/domain/content_type_definition.dart`：可扩展类型注册。
- 创建 `apps/client_flutter/lib/src/features/content/data/local/content_tables.dart`：资料表。
- 创建 `apps/client_flutter/lib/src/features/content/data/local/content_repository.dart`：Repository 接口和 Drift 实现。
- 创建 `apps/client_flutter/lib/src/features/content/data/import/content_package_validator.dart`：schema 与链接校验。
- 创建 `apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart`：事务导入与升级。
- 创建 `apps/client_flutter/lib/src/features/content/presentation/content_library_controller.dart`：本地查询状态。
- 创建 `apps/client_flutter/lib/src/features/content/presentation/content_home_page.dart`：空状态和资料首页。
- 创建 `apps/client_flutter/lib/src/features/content/presentation/content_search_page.dart`：筛选检索。
- 创建 `apps/client_flutter/lib/src/features/content/presentation/content_detail_page.dart`：独立详情路由。
- 创建 `apps/client_flutter/lib/src/features/content/presentation/content_package_settings_page.dart`：设置页管理。
- 拆分 `apps/client_flutter/lib/src/features/content/presentation/widgets/`：块渲染、元数据、链接和类型视图。
- 删除 `apps/server_nest/prisma/srd-5.1-seed.json`。
- 修改 `apps/server_nest/prisma/seed.ts`：不再写入任何默认资料正文。

### 任务 1：定义资料包和安全内容块

**文件：**
- 修改：`apps/client_flutter/pubspec.yaml`
- 创建：`apps/client_flutter/lib/src/features/content/domain/content_package_manifest.dart`
- 创建：`apps/client_flutter/lib/src/features/content/domain/content_block.dart`
- 创建：`apps/client_flutter/lib/src/features/content/domain/content_entry.dart`
- 创建：`apps/client_flutter/test/content_package_model_test.dart`

- [x] **步骤 1：编写失败的解析测试**

```dart
test('parses a linked class feature without accepting html blocks', () {
  final entry = ContentEntry.fromJson({
    'id': 'example:class/fighter',
    'type': 'class',
    'slug': 'fighter',
    'name': '战士',
    'aliases': ['Fighter'],
    'summary': '武器大师',
    'body': [
      {'type': 'heading', 'level': 2, 'text': '职业特性'},
      {
        'type': 'entryLink',
        'targetId': 'example:feature/action-surge',
        'text': '动作如潮'
      }
    ],
    'structured': {'hitDie': 'd10'},
    'tags': ['class'],
    'source': {'label': '本地资料'},
    'revision': 1,
  });

  expect(entry.body, hasLength(2));
  expect(entry.body.last, isA<EntryLinkBlock>());
  expect(
    () => ContentBlock.fromJson({'type': 'html', 'html': '<script>x</script>'}),
    throwsFormatException,
  );
});
```

- [x] **步骤 2：运行并确认模型缺失**

```powershell
cd apps/client_flutter
flutter test test/content_package_model_test.dart
```

预期：FAIL，`ContentEntry` 和 `ContentBlock` 不存在。

- [x] **步骤 3：实现封闭内容块类型**

`ContentBlock.fromJson` 只允许 `heading`、`paragraph`、`list`、`table`、`quote`、`callout`、`image`、`statBlock`、`entryLink` 和 `diceExpression`。未知类型抛出包含 JSON 路径的 `FormatException`。`ContentEntry` 必填 `id/type/slug/name/body/revision`，其余字段使用空集合或空字符串。

在 `pubspec.yaml` 添加：

```yaml
dependencies:
  archive: ^4.0.7
  crypto: ^3.0.6
  file_picker: ^10.3.10
```

- [x] **步骤 4：验证模型测试**

```powershell
cd apps/client_flutter
flutter test test/content_package_model_test.dart
flutter analyze
```

预期：解析成功，HTML 被拒绝，analyzer 无问题。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/pubspec.yaml apps/client_flutter/pubspec.lock apps/client_flutter/lib/src/features/content/domain apps/client_flutter/test/content_package_model_test.dart
git commit -m "feat(0.1): define local compendium package schema"
```

### 任务 2：实现资料表和 Repository 查询

**文件：**
- 创建：`apps/client_flutter/lib/src/features/content/data/local/content_tables.dart`
- 创建：`apps/client_flutter/lib/src/features/content/data/local/content_repository.dart`
- 修改：`apps/client_flutter/lib/src/core/database/app_database.dart`
- 创建：`apps/client_flutter/test/content_repository_test.dart`
- 创建：`apps/client_flutter/test/support/content_test_support.dart`

- [ ] **步骤 1：编写失败的空库和检索测试**

```dart
test('starts empty and searches enabled packages only', () async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = DriftContentRepository(database);
  final fighterEntry = ContentEntry.fromJson({
    'id': 'example:class/fighter',
    'type': 'class',
    'slug': 'fighter',
    'name': '战士',
    'body': <Map<String, Object?>>[],
    'revision': 1,
  });
  expect(await repository.search(const ContentQuery()), isEmpty);

  await repository.replacePackage(
    manifest: const ContentPackageManifest(
      formatVersion: 1,
      id: 'example',
      name: 'Example',
      version: '1.0.0',
      locale: 'zh-CN',
      system: 'dnd5e-2024',
      entryCount: 1,
    ),
    entries: [fighterEntry],
    contentHash: 'hash-1',
  );
  expect(await repository.search(const ContentQuery(text: '战士')), [fighterEntry]);
  await repository.setPackageEnabled('example', false);
  expect(await repository.search(const ContentQuery(text: '战士')), isEmpty);
  await database.close();
});
```

- [ ] **步骤 2：运行并确认 Repository 缺失**

```powershell
cd apps/client_flutter
flutter test test/content_repository_test.dart
```

预期：FAIL，资料表和 `DriftContentRepository` 不存在。

- [ ] **步骤 3：实现本地表与接口**

接口固定为：

```dart
abstract interface class ContentRepository {
  Stream<List<ContentPackageManifest>> watchPackages();
  Future<List<ContentEntry>> search(ContentQuery query);
  Future<ContentEntry?> getByKey(String entryKey);
  Future<List<ContentLink>> outgoingLinks(String entryKey);
  Future<List<ContentLink>> incomingLinks(String entryKey);
  Future<Uint8List?> readAsset(String packageId, String relativePath);
  Future<void> replacePackage({
    required ContentPackageManifest manifest,
    required List<ContentEntry> entries,
    required String contentHash,
    Map<String, Uint8List> assets = const {},
  });
  Future<void> setPackageEnabled(String packageId, bool enabled);
  Future<ContentDeletionImpact> deletionImpact(String packageId);
  Future<void> deletePackage(String packageId);
  Future<void> setFavorite(String entryKey, bool favorite);
  Future<void> saveNote(String entryKey, String markdown);
}
```

表名使用规格中的 `LocalContentPackages`、`LocalContentEntries`、`LocalContentAssets`、`ContentLinks`、`ContentFavorites`、`ContentNotes` 和 `ContentReadHistory`。`LocalContentAssets` 以 `(packageId, relativePath)` 为主键，保存 bytes、mediaType 和 contentHash；路径必须是规范化的 `assets/` 相对路径。用 Drift custom statement 创建 FTS5 虚表 `local_content_search(entryKey UNINDEXED, packageId UNINDEXED, name, aliases, summary, body, tags, source)`；导入、升级和删除在同一事务维护索引，搜索覆盖全部文本列，再用普通 SQL 条件处理类型、包、语言、等级、环阶、学派和收藏筛选。将 `AppDatabase.schemaVersion` 增至 `2` 并编写 `onUpgrade` 创建新表和 FTS 表。

`content_repository_test.dart` 增加名称、别名、摘要、正文、标签与来源命中测试，验证 disabled package 不命中，并在 Web 使用的 sqlite3 WASM 连接测试中执行同一 FTS 查询，防止 Native 可用而 Web 空白。

同时在 `test/support/content_test_support.dart` 实现 `MemoryContentRepository`。它完整实现上述接口，构造函数接受 `initialEntries`，写操作更新内存集合并通过 broadcast stream 通知测试；同文件提供 `testFighterEntry()`，使用步骤 1 的稳定 ID 和字段。后续 Widget 测试只使用这些已声明的测试支撑类型。

- [ ] **步骤 4：生成代码并验证查询**

```powershell
cd apps/client_flutter
dart run build_runner build --delete-conflicting-outputs
flutter test test/content_repository_test.dart test/app_database_test.dart
```

预期：空库、启用过滤、名称搜索和 schema 升级均通过。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/core/database apps/client_flutter/lib/src/features/content/data/local apps/client_flutter/test/content_repository_test.dart apps/client_flutter/test/app_database_test.dart apps/client_flutter/test/support/content_test_support.dart
git commit -m "feat(0.1): store compendium entries locally"
```

### 任务 3：实现事务导入、升级和安全校验

**文件：**
- 创建：`apps/client_flutter/lib/src/features/content/data/import/content_package_validator.dart`
- 创建：`apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart`
- 创建：`apps/client_flutter/lib/src/features/content/domain/content_import_report.dart`
- 创建：`apps/client_flutter/test/content_package_importer_test.dart`

- [ ] **步骤 1：编写失败的 dry-run 与回滚测试**

```dart
test('validates links before replacing the installed package', () async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = DriftContentRepository(database);
  final importer = ContentPackageImporter(repository);

  final report = await importer.previewJson('''{
    "formatVersion":1,
    "id":"example",
    "name":"Example",
    "version":"1.0.0",
    "locale":"zh-CN",
    "system":"dnd5e-2024",
    "entryCount":1,
    "entries":[{
      "id":"example:class/fighter",
      "type":"class",
      "slug":"fighter",
      "name":"战士",
      "body":[{"type":"entryLink","targetId":"missing","text":"缺失"}],
      "revision":1
    }]
  }''');

  expect(report.valid, isFalse);
  expect(report.errors.single.path, r'$.entries[0].body[0].targetId');
  expect(await repository.watchPackages().first, isEmpty);
  await database.close();
});
```

- [ ] **步骤 2：运行并确认导入器缺失**

```powershell
cd apps/client_flutter
flutter test test/content_package_importer_test.dart
```

预期：FAIL，`ContentPackageImporter` 不存在。

- [ ] **步骤 3：实现预览与确认导入**

`previewJson` 接受单文件对象并验证 `entryCount`、ID、slug、块类型和包内链接。`previewDndPack(Uint8List bytes)` 只读取根目录 `manifest.json`、`entries.json` 和 `assets/`，限制压缩后 50 MB、解压后 200 MB、文件数 5000、单文件 20 MB，并拒绝绝对路径、`..`、符号链接和重复规范化路径。每个 image block 的相对路径必须存在于 assets，MIME 与文件签名不一致时拒绝。`importReport(report)` 只能接收 `valid == true` 且包含已解析条目和 assets 快照的报告，并在 Repository 单事务中替换同 ID 包。

- [ ] **步骤 4：覆盖升级与失败回滚**

向测试增加：先导入 `1.0.0`，再导入损坏的 `2.0.0`，断言 `1.0.0` 仍存在；导入有效 `2.0.0` 后收藏和笔记仍按稳定 ID 存在。再构造一个含 PNG 的 `.dndpack`，断言 `readAsset` 返回原 bytes；分别验证 zip-slip、超限、缺失 image asset 和伪造 MIME 被拒绝且旧包不变。

运行：

```powershell
cd apps/client_flutter
flutter test test/content_package_importer_test.dart test/content_repository_test.dart
```

预期：全部通过。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/content/data/import apps/client_flutter/lib/src/features/content/domain/content_import_report.dart apps/client_flutter/test/content_package_importer_test.dart
git commit -m "feat(0.1): import local compendium packages transactionally"
```

### 任务 4：建立类型注册和 Wiki 详情渲染器

**文件：**
- 创建：`apps/client_flutter/lib/src/features/content/domain/content_type_definition.dart`
- 创建：`apps/client_flutter/lib/src/features/content/presentation/content_type_registry.dart`
- 创建：`apps/client_flutter/lib/src/features/content/presentation/widgets/content_block_view.dart`
- 创建：`apps/client_flutter/lib/src/features/content/presentation/widgets/content_metadata_view.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/widgets/content_class_feature_list.dart`
- 创建：`apps/client_flutter/test/content_type_registry_test.dart`
- 创建：`apps/client_flutter/test/content_block_view_test.dart`

- [ ] **步骤 1：写注册和安全渲染失败测试**

```dart
test('registers every v1 content type', () {
  final registry = ContentTypeRegistry.defaults();
  for (final type in const [
    'class', 'subclass', 'classFeature', 'species', 'background',
    'feat', 'spell', 'equipment', 'item', 'condition', 'rule',
    'monster', 'custom'
  ]) {
    expect(registry.definitionFor(type).type, type);
  }
});

testWidgets('renders entry links as navigable material list tiles', (tester) async {
  String? opened;
  await tester.pumpWidget(MaterialApp(
    home: ContentBlockView(
      blocks: const [EntryLinkBlock(targetId: 'example:spell/fireball', text: '火球术')],
      onOpenEntry: (id) => opened = id,
    ),
  ));
  await tester.tap(find.text('火球术'));
  expect(opened, 'example:spell/fireball');
});
```

- [ ] **步骤 2：运行并确认注册器缺失**

```powershell
cd apps/client_flutter
flutter test test/content_type_registry_test.dart test/content_block_view_test.dart
```

预期：FAIL，注册器和块视图不存在。

- [ ] **步骤 3：实现定义接口和默认类型**

```dart
abstract interface class ContentTypeDefinition {
  String get type;
  String get label;
  IconData get icon;
  List<ContentFieldDefinition> get searchableFields;
  Widget buildSummary(BuildContext context, ContentEntry entry);
  Widget buildMetadata(BuildContext context, ContentEntry entry);
}
```

默认注册器为每个 v1 类型提供定义。职业元数据显示生命骰、主要属性和熟练，法术元数据显示环阶、学派、施法时间、距离、成分和持续时间。未知类型使用 `custom` 定义，不抛出 UI 异常。

- [ ] **步骤 4：验证所有块和职业等级分组**

```powershell
cd apps/client_flutter
flutter test test/content_type_registry_test.dart test/content_block_view_test.dart test/content_class_feature_list_test.dart
flutter analyze
```

预期：注册、链接导航、内容块和按等级职业特性均通过。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/content/domain/content_type_definition.dart apps/client_flutter/lib/src/features/content/presentation apps/client_flutter/test/content_type_registry_test.dart apps/client_flutter/test/content_block_view_test.dart apps/client_flutter/test/content_class_feature_list_test.dart
git commit -m "feat(0.1): render extensible wiki entry types"
```

### 任务 5：重建资料库页面为独立 Wiki 路由

**文件：**
- 创建：`apps/client_flutter/lib/src/features/content/presentation/content_library_controller.dart`
- 创建：`apps/client_flutter/lib/src/features/content/presentation/content_home_page.dart`
- 创建：`apps/client_flutter/lib/src/features/content/presentation/content_search_page.dart`
- 创建：`apps/client_flutter/lib/src/features/content/presentation/content_detail_page.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_library_page.dart`
- 修改：`apps/client_flutter/test/widget_test.dart`
- 创建：`apps/client_flutter/test/content_wiki_page_test.dart`

- [ ] **步骤 1：写空状态和详情路由失败测试**

```dart
Widget buildContentTestApp({required List<ContentEntry> entries}) {
  final repository = MemoryContentRepository(initialEntries: entries);
  return MaterialApp(
    home: ContentLibraryPage(
      controller: ContentLibraryController(repository: repository),
      onImportRequested: () {},
    ),
  );
}

testWidgets('shows an import action when the local library is empty', (tester) async {
  await tester.pumpWidget(buildContentTestApp(entries: const []));
  await tester.pumpAndSettle();
  expect(find.text('资料库还是空的'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, '导入资料包'), findsOneWidget);
});

testWidgets('opens a narrow-screen entry on a full page', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(buildContentTestApp(entries: [testFighterEntry()]));
  await tester.tap(find.text('战士'));
  await tester.pumpAndSettle();
  expect(find.byType(ContentDetailPage), findsOneWidget);
  expect(find.byType(AlertDialog), findsNothing);
});
```

- [ ] **步骤 2：运行并确认当前弹窗行为失败**

```powershell
cd apps/client_flutter
flutter test test/content_wiki_page_test.dart
```

预期：FAIL，空状态文案或独立详情路由不存在。

- [ ] **步骤 3：实现页面职责拆分**

`ContentLibraryPage` 只负责响应式容器。宽度 `>= 1000` 时左侧 `ContentSearchPage`、右侧 `ContentDetailPage`；窄屏点击使用 `MaterialPageRoute`。`ContentHomePage` 展示分类、包、收藏和最近阅读。筛选使用 `SearchBar`、`FilterChip`、`DropdownMenu`；条目列表使用 `ListTile` 和 `Divider`，不使用嵌套 Card。

- [ ] **步骤 4：验证响应式 Wiki**

```powershell
cd apps/client_flutter
flutter test test/content_wiki_page_test.dart test/widget_test.dart
flutter analyze
```

预期：空状态、窄屏路由、宽屏双栏、收藏与搜索测试通过。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/content/presentation apps/client_flutter/test/content_wiki_page_test.dart apps/client_flutter/test/widget_test.dart
git commit -m "feat(0.1): rebuild the local library as a material wiki"
```

### 任务 6：在设置中管理本地资料包

**文件：**
- 创建：`apps/client_flutter/lib/src/features/content/presentation/content_package_settings_page.dart`
- 创建：`apps/client_flutter/lib/src/features/content/presentation/content_import_preview_dialog.dart`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`
- 创建：`apps/client_flutter/test/content_package_settings_test.dart`

- [ ] **步骤 1：写设置导入失败测试**

```dart
testWidgets('previews and imports a local package from settings', (tester) async {
  final bytes = utf8.encode(jsonEncode({
    'formatVersion': 1,
    'id': 'example',
    'name': 'Example',
    'version': '1.0.0',
    'locale': 'zh-CN',
    'system': 'dnd5e-2024',
    'entryCount': 1,
    'entries': [testFighterEntry().toJson()],
  }));
  final picker = MemoryContentFilePicker(
    result: PickedContentFile(name: 'example.json', bytes: bytes),
  );
  final repository = MemoryContentRepository();
  await tester.pumpWidget(MaterialApp(
    home: ContentPackageSettingsPage(
      repository: repository,
      importer: ContentPackageImporter(repository),
      filePicker: picker,
    ),
  ));
  await tester.tap(find.text('从文件导入'));
  await tester.pumpAndSettle();
  expect(find.text('1 个条目'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
  await tester.pumpAndSettle();
  expect(await repository.search(const ContentQuery()), hasLength(1));
});
```

- [ ] **步骤 2：运行并确认设置页缺失**

```powershell
cd apps/client_flutter
flutter test test/content_package_settings_test.dart
```

预期：FAIL，设置页和可注入文件选择器不存在。

- [ ] **步骤 3：实现文件选择与管理命令**

定义 `ContentFilePicker.pick()` 返回文件名与 bytes，生产实现使用 `file_picker`，测试使用 fake。包列表每项提供启用开关、升级、导出、删除菜单。删除前调用 `deletionImpact` 并显示受影响角色、收藏和笔记数量；确认后才删除。

在 `test/support/content_test_support.dart` 增加 `MemoryContentFilePicker implements ContentFilePicker`，构造参数为 `PickedContentFile? result`，`pick()` 原样返回该值。`PickedContentFile` 只包含 `name` 和 `Uint8List bytes`，不泄露平台文件对象到业务层。

- [ ] **步骤 4：验证设置与空库跳转**

```powershell
cd apps/client_flutter
flutter test test/content_package_settings_test.dart test/content_wiki_page_test.dart
flutter analyze
```

预期：导入、启停、升级预览和删除确认测试通过。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/content/presentation apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart apps/client_flutter/test/content_package_settings_test.dart apps/client_flutter/test/support/content_test_support.dart
git commit -m "feat(0.1): manage local content packs from settings"
```

### 任务 7：移除默认内容和远端个人资料库依赖

**文件：**
- 删除：`apps/server_nest/prisma/srd-5.1-seed.json`
- 修改：`apps/server_nest/prisma/seed.ts`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_controller.dart`
- 修改：`README.md`
- 修改：`docs/roadmap/current-execution-status.md`
- 创建：`docs/content/content-package-format-v1.md`
- 删除：`docs/content/phb-2024-private-import-notes.md`
- 删除：`docs/content/phb-private-index-import.md`
- 删除：`docs/content/private-phb-import-policy.md`
- 修改：`apps/server_nest/test/content.e2e-spec.ts`

- [ ] **步骤 1：写服务端 seed 边界测试**

在 `content.e2e-spec.ts` 增加断言：全新 mock 数据下 `GET /content/packages` 不会隐式返回 system/SRD 包；删除依赖 `srd-5.1-seed.json` 的测试夹具。

- [ ] **步骤 2：删除 seed 文件并简化 seed.ts**

`seed.ts` 只初始化服务器设置，不创建 `ContentPackage` 或 `ContentItem`。公开仓库搜索必须不再命中该文件：

```powershell
rg -n -i "srd-5.1-seed|SRD 5.1 Seed|玩家手册 2024 内置资料" apps/client_flutter/lib apps/server_nest/prisma/seed.ts apps/server_nest/src --glob '!**/*.spec.ts'
```

预期：生产客户端、seed 和服务端源码无默认规则包命中；测试与历史迁移说明可保留边界断言，但不得包含正文。

- [ ] **步骤 3：替换 MainShell 的个人资料依赖**

MainShell 注入 `ContentRepository` 和 `ContentLibraryController`。旧 `ContentController` 只保留临时战役兼容适配，并标记 `@Deprecated('Use ContentRepository and campaign sync')`。资料库页、角色创建和设置不得再持有 `ContentApiClient`。

- [ ] **步骤 4：运行完整验证**

```powershell
npm run doctor
cd apps/client_flutter
flutter build web --release
```

预期：全量测试、lint、analyze、Compose config 和 Web build 通过；资料库测试明确覆盖默认空库。

- [ ] **步骤 5：更新文档并提交**

README 写明“项目不内置规则正文”；执行状态列出本地导入格式和空库验收。`docs/content/content-package-format-v1.md` 完整定义 JSON 与 `.dndpack` 目录、manifest 字段、稳定 ID、所有安全内容块、结构化字段扩展原则、assets 路径/MIME/大小限制、链接解析、升级原子性、示例空包和兼容策略。删除针对特定商业书籍或私有 PDF 提取的旧文档，公开文档只描述来源中立的用户自备 JSON/ZIP 导入。提交：

```powershell
git add apps/server_nest/prisma apps/server_nest/test/content.e2e-spec.ts apps/client_flutter/lib/src/features/content apps/client_flutter/lib/src/features/server_home README.md docs/roadmap/current-execution-status.md docs/content
git commit -m "refactor(0.1): make the compendium local and empty by default"
```

## 完成条件

- 全新客户端资料库为空且可从设置导入。
- JSON 和 `.dndpack` 导入有事务、大小和路径安全测试。
- 资料库拥有检索、筛选、独立详情、链接、反向链接、收藏、笔记和职业等级视图。
- 资料库页面不读取 Token、服务器 URL 或远端个人 Content API。
- 公开仓库不存在任何默认 SRD/官方正文 seed。
- Native 与 Web 离线查阅测试和 release build 通过。
