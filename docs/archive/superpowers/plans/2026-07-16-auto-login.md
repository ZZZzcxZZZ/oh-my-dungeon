# 正式自动登录实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 删除 Debug 凭据注入，使用 refresh token 和按服务器偏好实现正式自动登录。

**架构：** `AuthTokenStore` 保存 token 与自动登录偏好；`AuthController` 决定是否持久化会话，并在启动时执行 access token → refresh token → `/me` 恢复链路；`AuthPage` 只展示和修改开关。

**技术栈：** Flutter、ChangeNotifier、SharedPreferences、flutter_test

---

### 任务 1：锁定 token store 行为

**文件：**
- 修改：`apps/client_flutter/test/auth_token_store_test.dart`
- 修改：`apps/client_flutter/lib/src/features/auth/data/auth_token_store.dart`

- [x] 编写测试，验证自动登录默认开启、偏好按服务器隔离并可跨 store 实例保存。
- [x] 运行 `flutter test test/auth_token_store_test.dart`，确认接口缺失导致失败。
- [x] 在 `AuthTokenStore`、`InMemoryAuthTokenStore` 和 `SharedPreferencesAuthTokenStore` 实现 `getAutoLoginEnabled` 与 `setAutoLoginEnabled`。
- [x] 重跑目标测试并确认通过。

### 任务 2：实现会话恢复

**文件：**
- 修改：`apps/client_flutter/test/auth_page_test.dart`
- 修改：`apps/client_flutter/lib/src/features/auth/presentation/auth_controller.dart`

- [x] 编写测试，验证旧 access token 可直接恢复，401 时 refresh 后恢复，refresh 401 时清除 token。
- [x] 编写测试，验证关闭自动登录后清除持久 token但保留当前内存会话，后续登录不再持久化。
- [x] 运行目标测试并确认失败原因来自缺失行为。
- [x] 实现初始化恢复链路、偏好切换和条件持久化。
- [x] 重跑目标测试并确认通过。

### 任务 3：实现登录页开关

**文件：**
- 修改：`apps/client_flutter/test/auth_page_test.dart`
- 修改：`apps/client_flutter/lib/src/features/auth/presentation/auth_page.dart`

- [x] 编写 widget test，验证登录页显示默认开启的「自动登录」开关并可关闭。
- [x] 运行测试确认失败。
- [x] 使用 `SwitchListTile` 接入 `AuthController.setAutoLoginEnabled`。
- [x] 重跑 widget test。

### 任务 4：删除 Debug 登录

**文件：**
- 删除：`apps/client_flutter/lib/src/features/auth/domain/debug_login_config.dart`
- 删除：`scripts/debug-client.ps1`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart`
- 修改：`package.json`
- 修改：`README.md`
- 修改：`docs/roadmap/current-execution-status.md`
- 修改：`docs/superpowers/specs/2026-07-16-campaign-character-integration-design.md`

- [x] 删除 Debug 配置、启动脚本、编译参数和测试。
- [x] 更新文档为正式自动登录语义。
- [x] 搜索旧配置类、编译参数和启动命令，确认生产代码与常用文档中无残留引用。

### 任务 5：验证

**文件：**
- 验证整个仓库

- [x] 运行认证目标测试。
- [x] 运行 `flutter analyze`。
- [x] 运行 `npm run doctor`。
- [x] 运行 `flutter build web --release --pwa-strategy=none`。
- [x] 运行 `git diff --check`。
