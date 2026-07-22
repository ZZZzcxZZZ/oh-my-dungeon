# 0.1 设置可靠性与 Material 3 设置页实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复设置无法可靠保留的问题，集中在线能力，并提供符合 Material 3 的全局主题和自定义 seed color 设置。

**架构：** 保留 AppPreferences 与服务器/认证数据的现有边界，新增独立的 ClientModeStore。主题构建移入 AppTheme，设置页拆为小型 section widget，所有修改通过可失败、可回滚的 controller 操作落盘。

**技术栈：** Flutter、Material 3、shared_preferences、flutter_test。

---

## 文件结构

- 创建 `apps/client_flutter/lib/src/features/client_mode/data/client_mode_store.dart`：本机模式持久化接口及 SharedPreferences 实现。
- 修改 `apps/client_flutter/lib/src/features/client_mode/domain/client_mode.dart`：初始化、保存失败回滚和错误状态。
- 修改 `apps/client_flutter/lib/src/app/dnd_table_app.dart`：在显示 MainShell 前初始化持久化模式，并委托 AppTheme。
- 创建 `apps/client_flutter/lib/src/app/theme/app_theme.dart`：亮暗 ColorScheme 和组件主题唯一入口。
- 创建 `apps/client_flutter/lib/src/features/app_preferences/presentation/seed_color_dialog.dart`：自主选色与预览。
- 创建 `apps/client_flutter/lib/src/features/server_home/presentation/settings/settings_section.dart`：统一设置区块外观。
- 创建 `apps/client_flutter/lib/src/features/server_home/presentation/settings/online_services_section.dart`：服务器、账号和同步聚合。
- 创建 `apps/client_flutter/lib/src/features/server_home/presentation/settings/appearance_settings_section.dart`：主题设置。
- 修改 `apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`：新顺序、稳定 controller、删除重复卡片。
- 修改 `apps/client_flutter/lib/src/features/app_preferences/data/app_preferences_store.dart`：检查每次写入结果。
- 测试 `apps/client_flutter/test/client_mode_test.dart`、`app_preferences_test.dart`、`app_theme_test.dart`、`seed_color_dialog_test.dart`、`settings_tab_page_test.dart`、`widget_test.dart`。

### 任务 1：持久化 Player/DM 模式

- [ ] **步骤 1：编写失败测试**

在 `client_mode_test.dart` 中使用内存 store，切换到 DM 后创建新 controller 并初始化，断言恢复为 DM；再用失败 store 断言保存失败后 controller 回滚到旧模式并暴露错误。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/client_mode_test.dart`

预期：FAIL，当前 controller 没有 store、initialize 或 error。

- [ ] **步骤 3：实现 store 与 controller**

接口固定为：

```dart
abstract interface class ClientModeStore {
  Future<ClientMode> load();
  Future<void> save(ClientMode mode);
}
```

`setMode()` 先保存再发布新状态；异常时保留旧模式并设置 `lastError`。`DndTableApp` 仅为自有 controller 注入 SharedPreferences store，测试注入的 controller 不被覆盖。

- [ ] **步骤 4：验证并提交**

运行：`flutter test test/client_mode_test.dart test/widget_test.dart --plain-name "switches client mode"`

提交：`feat(v0.1): persist client mode preference`

### 任务 2：让偏好写入失败可见

- [ ] **步骤 1：编写失败测试**

在 `app_preferences_test.dart` 增加 `FailingAppPreferencesStore`，断言 controller 在 store 抛错时保持旧偏好并通知错误；保留真实 SharedPreferences 的保存后重建 controller 回归测试。

- [ ] **步骤 2：实现可靠写入**

为所有 `setString/setInt/setBool` 使用统一 `_requireWrite(Future<bool>)` 并在返回 false 时抛出 `AppPreferencesWriteException`；controller 保存前保留 previous，失败时恢复 previous、设置 `lastError` 并再次通知。

- [ ] **步骤 3：验证并提交**

运行：`flutter test test/app_preferences_test.dart`

提交：`fix(v0.1): make preference writes recoverable`

### 任务 3：建立 AppTheme

- [ ] **步骤 1：编写失败测试**

创建 `app_theme_test.dart`，断言指定 seed 的亮暗主题使用 Material 3，且 Card、Dialog、BottomSheet、InputDecoration、NavigationBar 和 NavigationRail 主题已配置；卡片圆角不超过 8px。

- [ ] **步骤 2：实现 AppTheme**

提供：

```dart
abstract final class AppTheme {
  static ThemeData light(AppPreferences preferences);
  static ThemeData dark(AppPreferences preferences);
}
```

内部继续调用 `ColorScheme.fromSeed()`，并集中设置组件主题。`DndTableApp` 删除本地 `_dynamicSchemeVariant()` 与裸 `ThemeData`。

- [ ] **步骤 3：验证并提交**

运行：`flutter test test/app_theme_test.dart test/widget_test.dart`

提交：`feat(v0.1): centralize material 3 theme`

### 任务 4：实现自主选色

- [ ] **步骤 1：编写失败 widget 测试**

创建 `seed_color_dialog_test.dart`，覆盖打开对话框、选择预设、调整 HSV、输入 `#006A60`、拒绝非法值、取消不保存和应用后仅保存一次。

- [ ] **步骤 2：实现对话框**

对话框内部维护 `HSVColor` 草稿。十六进制输入接受 `RRGGBB` 与 `#RRGGBB`，转换为 `0xFFRRGGBB`。预览使用当前草稿生成局部 ColorScheme，但不修改全局 controller，直到点击“应用”。

- [ ] **步骤 3：验证并提交**

运行：`flutter test test/seed_color_dialog_test.dart test/app_preferences_test.dart`

提交：`feat(v0.1): add material seed color editor`

### 任务 5：重排设置页并集中在线服务

- [ ] **步骤 1：编写失败 widget 测试**

创建 `settings_tab_page_test.dart`，断言区块顺序为在线服务、使用模式、外观、规则与角色、资料与本地数据；离线状态仍显示本地设置；登录、服务器和同步均只出现在在线服务区。

- [ ] **步骤 2：拆分 section widget**

把在线服务和外观移到独立文件。`SettingsTabPage` 自身只负责页面编排和导航。默认骰子的 controller 移到 State，在 `initState/didUpdateWidget/dispose` 中维护。

- [ ] **步骤 3：移除冗余视觉**

删除区块内嵌套 Card、硬编码 seed 色说明文案和分散的服务器/账号/同步区块。保留一个最大宽度为 760px 的设置内容列。

- [ ] **步骤 4：验证并提交**

运行：`flutter test test/settings_tab_page_test.dart test/widget_test.dart`

提交：`refactor(v0.1): rebuild settings information architecture`

### 任务 6：设置阶段验收

- [ ] **步骤 1：运行完整客户端门禁**

运行：`flutter analyze && flutter test`

预期：analyze 无问题，全部测试通过。

- [ ] **步骤 2：构建并检查目标宽度**

运行：`flutter build web --release`

在 360、390、600、900、1280px 检查设置页，无溢出、嵌套卡片和丢失状态。

- [ ] **步骤 3：提交文档状态**

更新 `docs/roadmap/current-execution-status.md`，提交：`docs(v0.1): close settings reliability phase`
