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
