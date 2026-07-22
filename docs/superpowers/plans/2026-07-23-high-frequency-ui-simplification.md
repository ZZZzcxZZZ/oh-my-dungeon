# 高频界面减负实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 删除无效首页、恢复清晰的紧凑聊天模式按钮，并让战役归档角色默认折叠。

**架构：** 主壳继续用 `IndexedStack` 保持四个一级页面状态；聊天模式控件保留现有枚举和回调；消息分组偏好持久化到客户端设置；聊天头像从当前 `CampaignActor` 投影生命值，角色写入成功后控制器立即刷新内存状态。

**技术栈：** Flutter、Material 3、flutter_test

---

## 执行状态（2026-07-23）

- [x] 主壳收敛为战役、角色、资料库、设置四个入口。
- [x] 说/做切换恢复为两个紧凑图标按钮，保留 `68×48` 交互层和独立语义。
- [x] 归档角色默认折叠。
- [x] 生命环改为真实 HP 圆弧，并在只有公开分级时显示代表性弧度。
- [x] Composer 改为头像、统一输入表面、发送键三段布局，模式按钮嵌入输入表面。
- [x] 连续消息头像合并可在设置中关闭并持久化。
- [x] 历史消息固定使用发送时健康快照；输入栏快捷面板与身份切换读取角色当前 HP。
- [ ] 战役中心区块间距与层级将在总路线图 P0 收尾批次完成。

## 文件职责

- `apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart`：四入口应用外壳及默认战役页。
- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_mode_picker.dart`：说/做紧凑图标按钮。
- `apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_characters_panel.dart`：战役角色分区与归档折叠状态。
- `apps/client_flutter/test/offline_shell_test.dart`：离线主壳入口与默认页行为。
- `apps/client_flutter/test/widget_test.dart`：联网/桌面主壳导航回归。
- `apps/client_flutter/test/campaign_chat_composer_test.dart`：模式控件尺寸、语义与动画。
- `apps/client_flutter/test/campaign_characters_panel_test.dart`：归档区默认折叠与展开。

### 任务 1：主壳收敛为四个入口

- [ ] **步骤 1：编写失败测试**

修改 `offline_shell_test.dart`：断言没有“首页”，存在战役、角色、资料库、设置，并且离线启动默认显示战役离线提示。

- [ ] **步骤 2：验证测试失败**

运行：

```powershell
flutter test test/offline_shell_test.dart
```

预期：因仍显示首页且默认页不是战役而失败。

- [ ] **步骤 3：最小实现**

从 `main_shell.dart` 移除 `HomeDashboardPage` import、页面和两个导航目的地；保持 `_currentIndex = 0`，使战役自然成为默认页。同步修正只断言旧首页的主壳测试。

- [ ] **步骤 4：验证通过**

运行：

```powershell
flutter test test/offline_shell_test.dart test/widget_test.dart
```

预期：全部通过。

### 任务 2：说/做切换恢复为紧凑双按钮

- [ ] **步骤 1：编写失败测试**

在 `campaign_chat_composer_test.dart` 断言不存在滑块轨道和滑块，两个图标按钮能独立切换选中状态，并保留“说”“做”语义。

- [ ] **步骤 2：验证测试失败**

运行：

```powershell
flutter test test/campaign_chat_composer_test.dart
```

预期：旧滑块实现仍存在，双按钮断言失败。

- [ ] **步骤 3：最小实现**

恢复 `chat_mode_picker.dart` 的两个 `ChatModeHalf`：选中项使用 `secondaryContainer`，未选中项保持透明；保留 Tooltip、Semantics、固定高度和宽度，避免切换导致输入栏位移。

- [ ] **步骤 4：验证通过**

运行：

```powershell
flutter test test/campaign_chat_composer_test.dart test/campaign_chat_actor_test.dart
```

预期：全部通过，无 overflow。

### 任务 3：归档角色默认折叠

- [ ] **步骤 1：编写失败测试**

修改 `campaign_characters_panel_test.dart`：初始能看到“已归档 1”分区但看不到归档角色；点击分区后显示归档角色；再次点击后隐藏。

- [ ] **步骤 2：验证测试失败**

运行：

```powershell
flutter test test/campaign_characters_panel_test.dart
```

预期：旧实现初始显示归档角色。

- [ ] **步骤 3：最小实现**

在 `CampaignCharactersPanel` state 增加 `_archivedExpanded`。普通分区保持现有列表，归档分区使用可点击标题和旋转展开图标，仅展开时构建归档角色行。

- [ ] **步骤 4：验证通过**

运行：

```powershell
flutter test test/campaign_characters_panel_test.dart
```

预期：全部通过。

### 任务 4：整体验证

- [ ] **步骤 1：格式化**

```powershell
dart format lib/src/features/server_home/presentation/main_shell.dart lib/src/features/campaigns/presentation/chat/chat_mode_picker.dart lib/src/features/campaigns/presentation/center/campaign_characters_panel.dart test/offline_shell_test.dart test/widget_test.dart test/campaign_chat_composer_test.dart test/campaign_characters_panel_test.dart
```

- [ ] **步骤 2：运行相关测试和静态分析**

```powershell
flutter test test/offline_shell_test.dart test/widget_test.dart test/campaign_chat_composer_test.dart test/campaign_chat_actor_test.dart test/campaign_characters_panel_test.dart
flutter analyze
```

预期：测试 0 失败，analyze 0 issues。

- [ ] **步骤 3：构建 Web 测试版**

```powershell
flutter build web --release
```

预期：退出码 0，生成 `build/web`。
