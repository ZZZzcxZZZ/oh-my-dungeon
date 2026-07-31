# 战役、角色与 Material 3 收敛实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不重写现有模块的前提下，统一战役权限、角色生命周期、聊天身份、资料操作、增量同步与高频 Material 3 控件。

**架构：** 服务端策略继续作为权限最终裁决者，Flutter 端通过共享能力层和共享组件调用现有 API。页面只负责展示和收集输入；角色、资料和会话变化由资源级失效信号驱动局部刷新。

**技术栈：** Flutter Material 3、Drift、NestJS、Prisma、Socket.IO、Jest、flutter_test。

---

## 文件职责

- `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_mode_guard.dart`：统一战役入口模式判断与提示。
- `apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_actions.dart`：统一发布、绑定、归档、可见性和打开角色卡。
- `apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_directory.dart`：DM 角色页与战役中心共享目录。
- `apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_picker_sheet.dart`：快捷操作和身份切换共享角色选择器。
- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_composer.dart`：身份感知的输入栏。
- `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_refresh_coordinator.dart`：资源级失效合并与增量刷新。
- `apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_list_tile.dart`：QQ 式战役会话折叠卡片。
- `apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_archive_panel.dart`：资料作者权限与浮动阅读器。
- `apps/client_flutter/lib/src/core/widgets/`：搜索、筛选、数字输入、空状态、错误和分节标题等共享控件。
- `apps/client_flutter/lib/src/features/content/presentation/widgets/content_block_view.dart`：响应式内容块和表格。
- `apps/client_flutter/lib/src/features/characters/data/character_markdown_codec.dart`：结构化角色与人类可读 Markdown 的无损转换。
- `apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`：精简后的设置一级信息架构。
- `apps/client_flutter/lib/src/features/server_home/presentation/settings/server_and_account_page.dart`：服务器、账号、自动登录与同步二级页。
- `apps/server_nest/src/modules/campaigns/policies/campaign.policy.ts`：成员、资料作者和角色管理权限。
- `apps/server_nest/src/modules/campaign-sync/campaign-characters.service.ts`：发布、绑定、归档和 NPC 可见性事务。

### 任务 1：设置页与身份输入规则

**文件：**
- 修改：`apps/client_flutter/test/settings_tab_page_test.dart`
- 修改：`apps/client_flutter/test/campaign_chat_composer_test.dart`
- 创建：`apps/client_flutter/lib/src/features/server_home/presentation/settings/server_and_account_page.dart`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/settings/server_and_account_section.dart`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_composer_identity.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_composer.dart`

- [x] **步骤 1：写失败测试**

测试断言设置页首项为紧凑“服务器与账号”入口，详情只在二级页展示；`speakerMode` 为 `narrator` 或 `ooc` 时找不到 `ChatModePicker`，角色与临时身份仍显示。

- [x] **步骤 2：验证红灯**

运行：

```powershell
flutter test test/settings_tab_page_test.dart test/campaign_chat_composer_test.dart
```

预期：设置顺序和旁白模式用例失败。

- [x] **步骤 3：最小实现**

为 `CampaignComposerIdentity` 增加：

```dart
bool get supportsSayAction => speakerMode != 'narrator' && speakerMode != 'ooc';
```

输入栏仅在 `supportsSayAction` 时渲染模式按钮。`ServerAndAccountSection` 收敛为一个 `ListTile` 摘要，点击进入 `ServerAndAccountPage`，详情页复用现有服务器、账号和同步组件。

- [x] **步骤 4：验证绿灯**

运行相同测试并执行：

```powershell
flutter analyze
```

### 任务 2：战役入口模式与玩家绑定

**文件：**
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_mode_guard.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaigns_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/characters/publish_character_sheet.dart`
- 修改：`apps/client_flutter/test/campaigns_tab_page_test.dart`
- 修改：`apps/client_flutter/test/characters_tab_page_test.dart`
- 修改：`apps/server_nest/src/modules/campaigns/policies/campaign.policy.spec.ts`

- [x] **步骤 1：写失败测试**

覆盖创建者仅 DM 模式进入、普通成员仅玩家模式进入、玩家无发布按钮、未绑定玩家进入战役后一次完成发布与绑定。

- [x] **步骤 2：验证红灯**

运行客户端两个定向测试和服务端 policy 测试，确认失败来自守卫或绑定流程缺失。

- [x] **步骤 3：实现共享守卫与单一绑定操作**

`CampaignModeGuard.evaluate` 返回 `allowed`、`requiredMode` 和提示文案。玩家绑定操作在客户端只暴露 `bindLocalCharacter(campaignId, characterId)`，内部顺序调用发布和绑定并在任一步失败时保留可重试状态。

- [x] **步骤 4：验证绿灯**

定向测试全部通过，随后运行 campaign policy 全套测试。

### 任务 3：统一 DM 角色目录和操作

**文件：**
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_actions.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_directory.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_picker_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_characters_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_identity_sheet.dart`
- 修改：`apps/client_flutter/test/campaign_characters_panel_test.dart`
- 修改：`apps/client_flutter/test/characters_tab_page_test.dart`

- [x] **步骤 1：写失败测试**

两个入口必须渲染同一种 tile 和菜单；战役中心创建 NPC 不询问用途；DM 角色页仅询问本地或目标战役；NPC 默认不可见且首次发言后可见。

- [x] **步骤 2：验证红灯**

运行三个角色相关测试文件，保存正确的失败信息。

- [x] **步骤 3：提取共享能力和控件**

页面不再直接拼装 API 调用。角色 picker 支持头像、搜索、玩家角色和 NPC；临时身份仅返回消息草稿数据，不写角色仓库。

- [x] **步骤 4：验证绿灯并删除重复实现**

运行角色与聊天定向测试；仅删除已经没有引用的旧 picker/menu。

### 任务 4：聊天身份条、快捷操作和局部刷新

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_tool_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_identity_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_refresh_coordinator.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/conversation_controller.dart`
- 修改：`apps/client_flutter/test/campaign_chat_character_test.dart`
- 修改：`apps/client_flutter/test/campaign_refresh_coordinator_test.dart`

- [x] **步骤 1：写失败测试**

信息条主体打开角色卡，右端图标切换身份；旁白快捷操作复用角色 picker；消息、角色、资料、会话失效只刷新对应资源并保留草稿与滚动位置。

- [x] **步骤 2：验证红灯**

运行聊天角色和刷新协调器测试。

- [x] **步骤 3：实现资源级失效**

按 `messages`、`characters`、`archives`、`conversations` 合并刷新；同资源进行中请求不重复启动，完成后若游标推进则补一次。

- [x] **步骤 4：验证绿灯**

运行全部 campaign 客户端测试。

### 任务 5：战役卡片、资料和投骰器

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_list_tile.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_archive_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/content/campaign_content_editor.dart`
- 修改：`apps/client_flutter/lib/src/core/dice/dice_tray_dialog.dart`
- 修改：`apps/client_flutter/test/campaign_list_tile_test.dart`
- 修改：`apps/client_flutter/test/campaign_archive_panel_test.dart`
- 修改：`apps/client_flutter/test/core/dice/dice_tray_dialog_test.dart`
- 修改：`apps/server_nest/src/modules/campaigns/campaign-archives.service.ts`
- 修改：`apps/server_nest/test/campaign-archives.e2e-spec.ts`

- [x] **步骤 1：写失败测试**

覆盖主聊天室卡片点击、折叠小群和私聊、玩家创建并只编辑自己的资料、DM 编辑全部资料、组合骰表达式和角色目标。

- [x] **步骤 2：验证红灯**

分别运行 Flutter 三个定向测试和服务端 archive e2e。

- [x] **步骤 3：实现最小交互**

移除置顶标签和手动刷新按钮；资料详情复用浮动阅读器；骰子数量、加值和 DC 使用数字输入，骰面使用单选图标。

- [x] **步骤 4：验证绿灯**

运行战役列表、资料、投骰与服务端 archive 测试。

### 任务 6：内容库、怪物 Markdown 与响应式控件

**文件：**
- 创建：`apps/client_flutter/lib/src/core/widgets/app_search_bar.dart`
- 创建：`apps/client_flutter/lib/src/core/widgets/numeric_input_field.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_search_page.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/widgets/content_block_view.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/data/character_markdown_codec.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/monster_template_factory.dart`
- 修改：`scripts/extract_monster_manual_private.py`
- 修改：`apps/client_flutter/test/content_block_view_test.dart`
- 修改：`apps/client_flutter/test/character_markdown_codec_test.dart`
- 修改：`apps/client_flutter/test/monster_template_factory_test.dart`
- 修改：`scripts/test_private_rulebook_extractors.py`

- [x] **步骤 1：写失败测试**

窄屏长文本不溢出；职业表不重复详细特性；怪物 trait、action、bonus action、reaction、legendary action 和 spellcasting 分组无损往返 Markdown。

- [x] **步骤 2：验证红灯**

运行三个 Flutter 定向测试和提取器测试。

- [x] **步骤 3：规范化渲染和 codec**

未知或粘连内容进入人工复核报告，不静默塞入标题或单个动作字段。怪物类型只保留标准大类，细分值进入标签。

- [x] **步骤 4：验证绿灯**

运行内容、角色 Markdown 和私有资料包校验测试。

### 任务 7：全量回归和死代码收敛

**文件：**
- 修改：仅限前六个任务确认无引用的重复控件与旧接口。

- [x] **步骤 1：引用审计**

使用 `rg` 检查旧 picker、旧角色菜单、手动刷新入口和页面内 API 拼装，逐项确认替代者后删除。

- [x] **步骤 2：格式与静态检查**

```powershell
dart format apps/client_flutter/lib apps/client_flutter/test
npm run lint:server
flutter analyze
```

- [x] **步骤 3：全量验证**

```powershell
npm run test:server
npm run test:client
npm run build:private:web
```

预期：服务端和客户端测试全绿，私有 Web 构建成功，无新增 analyzer 或 lint 问题。

- [x] **步骤 4：人工验收**

在手机宽度和桌面宽度依次验证：战役入口模式、玩家绑定、DM NPC 管理、聊天身份、资料创建编辑、局部刷新、内容换行、投骰和设置二级页。

验收结果（2026-07-30）：服务端 27 套件 / 356 测试、客户端 865 测试通过（2 个按设计跳过），
Flutter analyze 与服务端 lint 清洁；私有 Web 构建内嵌 PHB、MM、DMG 共 1880 条。移动宽度由
320px 战役卡片、移动角色向导、窄屏资料详情和响应式内容测试覆盖；桌面 release 构建已实际检查
战役离线态、资料库列表与浮动详情、设置一级摘要及服务器与账号二级页。
