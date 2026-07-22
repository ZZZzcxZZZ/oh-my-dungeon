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

- [ ] 写失败测试：主页、搜索结果和详情 reader 中不存在“编辑条目”“添加笔记”“复制为新条目”；资料包管理入口不在资料库页面。
- [ ] 删除对应展示入口但保留 importer/package settings 实现，避免破坏设置页导入。
- [ ] 运行 `flutter test test/content_read_only_test.dart test/content_detail_page_test.dart`。
- [ ] 提交 `refactor(v0.1): make content library read only`。

### 任务 2：补齐类型与职业关联

- [ ] 写失败测试：`subclass`、`classFeature` 可独立搜索；职业 reader 按等级显示特性，并显示 `subclassOf` 指向该职业的子职业。
- [ ] 扩展 `content_type_registry.dart` 的可检索类型；在 controller/repository 使用结构化关系查询，禁止解析正文字符串推断关系。
- [ ] 职业特性和子职业点击后压入同一个 reader 浮层导航栈，返回时恢复原职业滚动位置。
- [ ] 运行 `flutter test test/content_class_navigation_test.dart test/content_class_feature_list_test.dart test/content_entry_reader_test.dart`。
- [ ] 提交 `feat(v0.1): connect class content navigation`。

### 任务 3：紧凑筛选系统

- [ ] 写失败测试：手机首屏只显示 SearchBar、“筛选”按钮和一行已启用 FilterChip；不显示巨大下拉框。
- [ ] 为 spell 提供环位、职业、学派；class/subclass 提供所属职业；equipment/item 提供类别；feat 提供等级/前置条件；monster 提供 CR/类型；无字段的 facet 不显示。
- [ ] 使用底部筛选面板，应用后把选择转换为 controller 的结构化 filter；清除按钮一次清空。
- [ ] 运行 `flutter test test/content_library_filters_test.dart test/content_wiki_page_test.dart`。
- [ ] 提交 `feat(v0.1): add compact content facets`。

### 任务 4：验收

- [ ] 运行所有 `test/content_*_test.dart` 与 `test/content_repository_test.dart`。
- [ ] 运行 `flutter analyze` 和 `flutter build web --release`。
- [ ] 验证 360、390、900、1280 宽度无 overflow，记录测试结果。
