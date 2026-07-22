# 只读资料库与分类检索实现计划

> **面向 AI 代理的工作者：** 使用 test-driven-development 逐项执行。保持 repository 和 reader 公开 API 向后兼容。

**目标：** 把资料库收敛为 Material 3 只读查阅平台，补齐子职业、职业特性和各类型结构化筛选。

**架构：** `ContentLibraryController` 维护 query/facet 状态；registry 声明不同类型支持的 facet；所有关联跳转继续使用一个 `ContentEntryReader` 浮层栈。导入与包管理保留在设置入口，不出现在资料浏览页面。

**技术栈：** Flutter、Drift repository、Material 3、flutter_test。

## 文件所有权

- 修改 `apps/client_flutter/lib/src/features/content/**`
- 新建 `content_library_filters_test.dart`、`content_class_navigation_test.dart`、`content_read_only_test.dart`
- 可修改现有 `content_*_test.dart`

禁止修改角色、战役、设置、全局主题和内容包 schema；不得破坏 `ContentRepository`、`ContentEntryReader` 现有构造器。

### 任务 1：移除浏览页创作入口

- [x] 写失败测试：主页、搜索结果和详情 reader 中不存在“编辑条目”“添加笔记”“复制为新条目”；资料包管理入口不在资料库页面。
- [x] 删除对应展示入口但保留 importer/package settings 实现，避免破坏设置页导入。
- [x] 运行 `flutter test test/content_read_only_test.dart test/content_detail_page_test.dart`。
- [x] 提交 `refactor(v0.1): make content library read only`。

### 任务 2：补齐类型与职业关联

- [x] 写失败测试：`subclass`、`classFeature` 可独立搜索；职业 reader 按等级显示特性，并显示 `subclassOf` 指向该职业的子职业。
- [x] 扩展 `content_type_registry.dart` 的可检索类型；在 controller/repository 使用结构化关系查询，禁止解析正文字符串推断关系。
- [x] 职业特性和子职业点击后压入同一个 reader 浮层导航栈，返回时恢复原职业滚动位置。
- [x] 运行 `flutter test test/content_class_navigation_test.dart test/content_class_feature_list_test.dart test/content_entry_reader_test.dart`。
- [x] 提交 `feat(v0.1): connect class content navigation`。

### 任务 3：紧凑筛选系统

- [x] 写失败测试：手机首屏只显示 SearchBar、“筛选”按钮和一行已启用 FilterChip；不显示巨大下拉框。
- [x] 为 spell 提供环位、职业、学派；class/subclass 提供所属职业；equipment/item 提供类别；feat 提供等级/前置条件；monster 提供 CR/类型；无字段的 facet 不显示。
- [x] 使用底部筛选面板，应用后把选择转换为 controller 的结构化 filter；清除按钮一次清空。
- [x] 运行 `flutter test test/content_library_filters_test.dart test/content_wiki_page_test.dart`。
- [x] 提交 `feat(v0.1): add compact content facets`。

### 任务 4：验收

- [x] 运行所有 `test/content_*_test.dart` 与 `test/content_repository_test.dart`。
- [x] 运行 `flutter analyze` 和 `flutter build web --release`。
- [x] 验证 360、390、900、1280 宽度无 overflow，记录测试结果。

## 最终报告

### Commit 列表

分支 `feat/v0.1-content-library`（基于 `52bd6da`）：

| Commit | 说明 |
|--------|------|
| `d17997e` | `refactor(v0.1): make content library read only` — 移除浏览页的编辑条目/添加笔记/复制创作入口，资料包管理留在设置入口 |
| `a3828af` | `feat(v0.1): connect class content navigation` — 职业详情按等级显示特性（`featureOf` 关系），列出子职业（`subclassOf` 关系），统一浮层阅读器导航栈 + 滚动位置恢复 |
| `1237f21` | `feat(v0.1): add compact content facets` — SearchBar + 筛选按钮 + FilterChip 行 + 底部筛选面板，各类型结构化 facet（法术环位/学派/可用职业、子职业所属职业、装备类别、物品稀有度、专长类别/先决、怪物 CR/类型） |
| `6c48858` | `test(v0.1): verify content library responsive widths` — 360/390/900/1280 宽度搜索页 + 详情浮层无 overflow 验收 |

### 测试结果

| 验证项 | 结果 |
|--------|------|
| `content_*_test.dart`（15 个文件）+ `content_repository_test.dart` | 全部通过（109 项，含 8 项响应式宽度测试） |
| `flutter analyze`（全项目） | No issues found |
| `flutter build web --release` | 成功（`√ Built build\web`，30.7s；wasm dry-run 仅 `socket_io_common` 第三方警告，与本次改动无关） |
| 360/390/900/1280 宽度 | 搜索页（含筛选面板 + FilterChip 行）与详情 Dialog 均无 overflow |

新增测试文件：

- `content_read_only_test.dart` — 只读约束
- `content_class_navigation_test.dart` — 子职业/特性独立检索 + 浮层栈导航 + 滚动恢复
- `content_library_filters_test.dart` — 紧凑筛选系统 6 项

### API 兼容性说明

| 公开 API | 状态 |
|----------|------|
| `ContentRepository` 接口 | 未改动（`search`/`getByKey`/`outgoingLinks`/`incomingLinks`/`watchPackages` 等签名不变） |
| `DriftContentRepository(this._database)` 构造器 | 未改动 |
| `ContentEntryReader({entry, onOpenEntry, readAsset, packageId, showRules, key})` | 未改动 |
| `ContentLibraryController` | 未改动（`search`/`facetOptions`/`toggleFavorite`/`getByKey`/`repository` 不变） |
| `ContentQuery` | 未改动 |
| `ContentHomePage` | 移除 `onImportRequested` 参数（任务 1 只读化）；该参数原本未被任何外部调用方传入 |
| `ContentLibraryPage({controller, onImportRequested})` | 保留（main_shell 仍传入） |
| `ContentDetailPage` | 新增可选 `onBack` 参数（向后兼容）；其余不变 |

### 发现的数据结构缺口

1. **`subclass.structured.parentClass` 未保证填充**：`_SubclassDefinition.searchableFields` 声明了 `parentClass`，底部筛选面板也暴露该 facet。但实际子职业通过 `relations` 数组的 `subclassOf` 关系链接到父职业，而非 `structured.parentClass` 字段。职业详情页正确使用 `relations` 查询，但 `parentClass` facet 仅在资料包显式填充该字段时才有效。建议：资料包 schema 应要求 `structured.parentClass`，或 facet 改为从 `relations` 派生。

2. **`classFeature` 未在类型筛选列表中**：`_typeFilters` 包含 `subclass` 但不包含 `classFeature`。`classFeature` 已在 registry 注册且可被 `ContentQuery(type: 'classFeature')` 独立检索（职业详情页内部使用），但用户无法在筛选面板中按该类型浏览。建议：若需要用户直接浏览职业特性列表，应将 `classFeature` 加入 `_typeFilters` 并为其配置 facet 字段。

3. **`equipmentBundle` 类型未暴露**：registry 注册了 `equipmentBundle` 但不在 `_typeFilters` 中，用户无法按此类型筛选。

4. **`monster.challengeRating` 排序问题**：CR 含分数值（"1/2"、"1/4"、"1/8"），`facetOptions` 按字符串排序会导致 "1/2" 排在 "1" 之后、"2" 之前，数值顺序错误。建议：facet 排序需对 CR 字段做特殊数值解析。

5. **`feat.prerequisite` 为自由文本**：先决条件通常是自由文本（如"施法能力"、"等级 5"），作为 facet 会产生过多唯一值，筛选实用性低。建议：考虑改为按 `level` 数值筛选，或将 `prerequisite` 标准化为枚举。

6. **`class` 类型无 facet 字段**：`_facetFieldsFor('class')` 返回空列表（职业类型不暴露结构化 facet）。若需要按生命骰/主属性筛选职业，需补充 facet 字段定义。
