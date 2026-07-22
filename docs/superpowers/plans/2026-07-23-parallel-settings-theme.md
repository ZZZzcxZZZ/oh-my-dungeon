# 设置持久化与全局 Material 3 实现计划

> **面向 AI 代理的工作者：** 使用 test-driven-development 逐项执行。只修改本计划授权目录；每个行为先看到测试按预期失败。

**目标：** 让所有本地设置可靠持久化，并建立客户端唯一的 Material 3 主题入口。

**架构：** `AppPreferencesController` 与 `ClientModeController` 分别负责偏好和模式，store 负责持久化；`AppTheme` 只消费偏好生成 ThemeData。设置页只编排独立 section，不持有业务真相。

**技术栈：** Flutter、Material 3、shared_preferences、flutter_test。

## 文件所有权

- 创建 `apps/client_flutter/lib/src/app/theme/app_theme.dart`
- 创建 `apps/client_flutter/lib/src/features/client_mode/data/client_mode_store.dart`
- 创建 `apps/client_flutter/lib/src/features/server_home/presentation/settings/` 下的 section widget
- 修改 `apps/client_flutter/lib/src/app/dnd_table_app.dart`
- 修改 `apps/client_flutter/lib/src/features/app_preferences/**`
- 修改 `apps/client_flutter/lib/src/features/client_mode/**`
- 修改 `apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`
- 修改 `apps/client_flutter/test/widget_test.dart`
- 新建 `app_theme_test.dart`、`client_mode_test.dart`、`settings_tab_page_test.dart`

禁止修改 `features/content`、`features/characters`、`features/campaigns`。

### 任务 1：持久化与失败回滚

- [ ] 在 `client_mode_test.dart` 写失败测试：保存 DM 后重建 controller 仍为 DM；store 抛错时保持旧模式并暴露错误。
- [ ] 在 `app_preferences_test.dart` 写失败测试：每个新增/现有偏好重建 controller 后保持；写失败回滚。
- [ ] 运行 `flutter test test/client_mode_test.dart test/app_preferences_test.dart` 并确认因缺少 store/回滚失败。
- [ ] 实现 `ClientModeStore.load/save`，偏好和模式都采用“先持久化，成功后发布；失败则保留旧值”。
- [ ] 重跑测试并提交 `fix(v0.1): persist local settings reliably`。

### 任务 2：唯一 AppTheme

- [ ] 在 `app_theme_test.dart` 写失败测试：亮暗主题启用 Material 3；NavigationBar、NavigationRail、AppBar、Input、Dialog、BottomSheet、Chip、Card、Button 均有主题；卡片圆角不超过 8。
- [ ] 实现 `AppTheme.light(preferences)` 与 `AppTheme.dark(preferences)`，仅通过 `ColorScheme.fromSeed` 生成 tonal palette，禁止把 seed 色直接作为页面背景。
- [ ] 从 `dnd_table_app.dart` 删除散落主题生成函数，统一调用 `AppTheme`。
- [ ] 运行 `flutter test test/app_theme_test.dart test/widget_test.dart` 并提交 `feat(v0.1): centralize material theme`。

### 任务 3：设置页信息架构

- [ ] 在 `settings_tab_page_test.dart` 写失败测试，断言顺序为：外观与体验、资料与存储、服务器与账户、角色模式、关于。
- [ ] 断言服务器、登录、自动登录和同步只在“服务器与账户”出现一次；没有行为的展示型设置不出现。
- [ ] 拆出 section widget；页面最大内容宽度 760，禁止 section 外层 Card 和 Card 嵌套。
- [ ] 自定义取色使用 Dialog：预设色、HSV/颜色输入、局部预览、应用/取消；取消不得写 store。
- [ ] 运行 `flutter test test/settings_tab_page_test.dart test/widget_test.dart` 并提交 `refactor(v0.1): simplify settings experience`。

### 任务 4：验收

- [ ] 运行 `flutter analyze`。
- [ ] 运行 `flutter test test/app_preferences_test.dart test/client_mode_test.dart test/app_theme_test.dart test/settings_tab_page_test.dart test/widget_test.dart`。
- [ ] 运行 `flutter build web --release`。
- [ ] 在计划文件勾选完成项并记录实际通过数，不修改其他路线图。
- [x] 在 `client_mode_test.dart` 写失败测试：保存 DM 后重建 controller 仍为 DM；store 抛错时保持旧模式并暴露错误。
- [x] 在 `app_preferences_test.dart` 写失败测试：每个新增/现有偏好重建 controller 后保持；写失败回滚。
- [x] 运行 `flutter test test/client_mode_test.dart test/app_preferences_test.dart` 并确认因缺少 store/回滚失败。
- [x] 实现 `ClientModeStore.load/save`，偏好和模式都采用“先持久化，成功后发布；失败则保留旧值”。
- [x] 重跑测试并提交 `fix(v0.1): persist local settings reliably`。

### 任务 2：唯一 AppTheme

- [x] 在 `app_theme_test.dart` 写失败测试：亮暗主题启用 Material 3；NavigationBar、NavigationRail、AppBar、Input、Dialog、BottomSheet、Chip、Card、Button 均有主题；卡片圆角不超过 8。
- [x] 实现 `AppTheme.light(preferences)` 与 `AppTheme.dark(preferences)`，仅通过 `ColorScheme.fromSeed` 生成 tonal palette，禁止把 seed 色直接作为页面背景。
- [x] 从 `dnd_table_app.dart` 删除散落主题生成函数，统一调用 `AppTheme`。
- [x] 运行 `flutter test test/app_theme_test.dart test/widget_test.dart` 并提交 `feat(v0.1): centralize material theme`。

### 任务 3：设置页信息架构

- [x] 在 `settings_tab_page_test.dart` 写失败测试，断言顺序为：外观与体验、资料与存储、服务器与账户、角色模式、关于。
- [x] 断言服务器、登录、自动登录和同步只在“服务器与账户”出现一次；没有行为的展示型设置不出现。
- [x] 拆出 section widget；页面最大内容宽度 760，禁止 section 外层 Card 和 Card 嵌套。
- [x] 自定义取色使用 Dialog：预设色、HSV/颜色输入、局部预览、应用/取消；取消不得写 store。
- [x] 运行 `flutter test test/settings_tab_page_test.dart test/widget_test.dart` 并提交 `refactor(v0.1): simplify settings experience`。

### 任务 4：验收

- [x] 运行 `flutter analyze`。
- [x] 运行 `flutter test test/app_preferences_test.dart test/client_mode_test.dart test/app_theme_test.dart test/settings_tab_page_test.dart test/widget_test.dart`。
- [x] 运行 `flutter build web --release`。
- [x] 在计划文件勾选完成项并记录实际通过数，不修改其他路线图。

## 验收结果

- `flutter analyze`：No issues found!
- `flutter test`（5 个文件共 57 个测试全部通过）：
  - `app_preferences_test.dart`：6 通过
  - `client_mode_test.dart`：7 通过
  - `app_theme_test.dart`：8 通过
  - `settings_tab_page_test.dart`：7 通过
  - `widget_test.dart`：29 通过
- `flutter build web --release`：√ Built build\web

## 独立复核报告（2026-07-23）

主代理在子代理交付后重新核验，确认计划执行到位，并记录以下事项：

### 复核实测结果

- `flutter analyze`：No issues found!（4.0s，独立重跑）
- `flutter test`（5 个文件）：+57 -0: All tests passed!（独立重跑，数字与子代理报告一致）
- `flutter build web --release`：产物 `build/web/index.html` 存在
- 计划复选框：18 项全部 `[x]`
- commit 列表：`1c36149` / `cf46056` / `026ccda` / `44a27b6`

### 边界合规性确认

使用 merge-base `52bd6da`（feat 分支真实分叉点）做精确 diff，分支仅改动 19 个文件，全部在授权范围（`app/theme`、`app_preferences`、`client_mode`、设置页及其测试）。未触碰 `content`、`characters`、`campaigns` 或服务端代码。

### 发现的 issue

1. **基线偏移导致 diff 误读（非缺陷，合并前需处理）**
   - feat 分支基于 `52bd6da` 创建，而 `offline-first-0.1` 在并行开发期间已前进到 `bb5b490`（其他并行工作者提交）。
   - 直接运行 `git diff offline-first-0.1..HEAD` 会把其他工作者的改动反向显示为 feat 分支的改动，出现 campaigns、characters、content 甚至服务端 check-requests 模块的"违规"假象。
   - 用 `git diff 52bd6da..HEAD`（merge-base）做精确 diff 后，确认子代理只改了 19 个授权范围内的文件。
   - **处理建议**：合并到 `offline-first-0.1` 前需先 `git rebase offline-first-0.1` 消除基线偏移，再做合并。这是并行 worktree 工作流的正常现象，不属本任务缺陷。

### 未解决问题

无。所有 18 个计划子项均已完成并独立复核通过，实现为真实代码而非空壳。
