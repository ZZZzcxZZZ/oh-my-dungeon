# 战役工作区规范合规整改计划

## 状态

本计划于 2026-07-17 启动，目标是把客户端逐步对齐 `2026-07-16-campaign-workspace-refactor-design.md` 的逐字要求。

所有改动严格遵循 TDD：先写失败测试 → 实现 → 验证 → 提交。提交前必须 `flutter analyze` 通过。

## 现状诊断（与规范对照）

| # | 用户反馈 | 规范原文 | 当前实现 | 偏差类型 |
|---|---------|---------|---------|---------|
| 1 | 头像选择应在角色创建/编辑，而非发布时 | §头像来源：本地角色头像离线保存在客户端；战役角色头像在本地角色绑定战役后自动上传 | `CharacterEditorPage`（quick/standard/fullSheet 三种流程）均无头像字段；`CharacterSheet.copyWith` 不暴露 avatarUrl；`CharacterDetailPage` 头部只用首字母不显示头像；只有 `PublishCharacterSheet` 有 AvatarPicker | 偏差 |
| 2 | 输入栏加号与左侧头像应合二为一 | §输入栏：当前身份头像取代原有独立 `+` 按钮，点击后打开底部快捷面板（含 11 项工具） | `_buildInputBar` 同时存在 `campaign-chat-identity`（头像）和独立的 `+` 按钮（`_showMoreActions`），二者分离 | 偏差 |
| 3 | DM 点击头像不应要求绑定角色 | §发言身份 DM：DM 可使用旁白/DM、账号场外身份、NPC、怪物、同伴、临时身份；§未绑定状态只针对 player | `_showIdentitySheet` 在 DM 下也走"绑定角色"路径，未给 DM 提供"旁白/场外/已有 NPC/临时身份"切换 | 偏差 |
| 4 | 右上角暴露计划外旧 UI/旧接口 | §全局设置：右上角更多菜单只有战役名称/封面/简介、所有权转移、战役归档、离开战役 | chat 页 AppBar 暴露了 `战役中心` + `战役资料` + `成员` 三个 IconButton，没有"更多菜单"；旧 `_showMembers`、`_openCampaignContent` 等入口散落 | 偏差 |
| 5 | 找不到分享邀请码入口 | §队伍：邀请和管理成员在 `战役中心 → 队伍`，DM 就地操作 | 邀请码入口藏在 `CampaignDetailPage` 正文区块（仅 owner 可见），不在队伍面板 | 偏差 |
| 6 | 主持人可随意以玩家身份进入，玩家也可变主持人 | §客户端工作模式：服务端返回成员身份和能力集，客户端模式不能授予战役权限 | 服务端 campaigns 模块本身严格按 `CampaignMember.role` 授权（已合规）；但客户端 `CampaignChatPage` 的 `isDm` 入参来自应用偏好而非服务端 capabilities，导致 UI 层显示错位（普通玩家切 DM 模式仍看见 DM 工具） | 客户端偏差 |
| 7 | 档案条目 UI 混乱 | §档案：页面内筛选切换全部/资料/地点/线索/文件；条目可从聊天跳转查看 | `CampaignArchivePanel` 已有筛选 chip + 列表 + 点击浮窗，但新建按钮（FAB）只在 DM 时显示且无类型区分；详情浮窗信息过于简陋（只有 title/kind/summary），缺正文/来源消息/关联；记录面板条目点击无行为 | 部分偏差 |
| 8 | 创建角色失败 | — | 待复现错误日志后定位。最可能原因：① DM 走 `/actors/publish` 接口尝试创建 NPC（被服务端 400 拒）；② 重复 publish 同一 sourceCharacterId 时 baseRevision 冲突 409；③ sheetJson 含 null/数组导致 400 | 待定位 |
| 9 | DM 模式下角色创建只能创建临时角色 | §DM 角色生命周期：常驻（NPC/怪物/同伴）、临时、已归档；DM 可在队伍页面完整管理 | `CharactersTabPage` DM 模式直接显示 `CampaignActorDirectoryPage` 而非本地角色创建入口；DM 创建常驻 NPC 的入口缺失；只有 chat 页的"快速临时身份"路径可创建临时角色 | 偏差 |

## 整改任务（按依赖顺序）

### Phase 1：权限与身份隔离（最高优先级，解决 #6 #3 #8）

#### Task 1.1：客户端统一以服务端 capabilities 为权威来源

**目标**：消除客户端 `isDm` 应用偏好对战役 UI 的影响。所有战役页面的 DM 能力显示一律来自 `workspaceContext.capabilities.canManageCampaign`。

**改动**：
- `CampaignChatPage`：移除 `isDm` 入参，改用 `campaignController.workspaceContext?.capabilities.canManageCampaign`。
- `CharactersTabPage`：DM 模式下不应直接替换为 `CampaignActorDirectoryPage`；本地角色创建入口对所有人可用，战役角色管理按 capabilities 显示。
- `MainShell`：调用方移除对 `isDm` 的传参。
- 测试：普通玩家切 DM 模式后仍不出现战役 DM 功能（规范测试矩阵第 3 项）。

**TDD**：
- 红：写测试 "普通玩家切换全局 DM 模式后，战役聊天不显示 DM 工具" → 失败。
- 绿：改 `CampaignChatPage` 用 capabilities；删除 isDm 依赖。
- 验证：`flutter test test/campaign_chat_actor_test.dart` 全绿。

#### Task 1.2：DM 身份切换面板按规范重组

**目标**：点击输入栏头像后弹出的快捷面板按规范 §发言身份 DM 重组：
- 旁白 / DM
- 账号场外身份
- 常驻 NPC、怪物、同伴（从 workspace.actors 列表）
- 临时角色（草稿）
- 明确开启的玩家角色临时代管（DM 可代管玩家角色，标记 "DM 代管"）

DM 路径**不要求绑定角色**。普通玩家路径：未绑定时只显示"绑定角色"入口和 OOC；已绑定时显示绑定角色 + OOC。

**TDD**：
- 红：测试 "DM 打开头像面板时看到旁白、场外、NPC 列表、临时身份、代管入口；不出现'绑定角色'"。
- 红：测试 "未绑定玩家打开头像面板只看到'绑定角色'和 OOC"。
- 绿：重写 `_showIdentitySheet`，按角色拆分。

#### Task 1.3：修复角色发布/创建失败的错误路径

**目标**：定位并修复用户反馈的"创建角色失败"。

**步骤**：
1. 在 `PublishCharacterSheet` 与 `CampaignActorController` 的 catch 块里把服务端错误体（`error.message`）显示在 SnackBar，让用户看到具体原因。
2. 在 `CharactersTabPage._showPublishSheet` 接收 `onPickImage` 后的 publish 失败时，区分 400/403/409 给出规范错误串：
   - 400 → "角色数据不完整，请检查后重试。"
   - 403 → "没有权限执行此操作。"
   - 409 → "该角色已由 DM 更新，请刷新后重试。"（规范 §错误处理）
3. 修复 `CharacterSheet.copyWith` 暴露 `avatarUrl` 参数，避免发布时只能通过 `sheetOverride` 绕路。
4. 修复重复 publish 时 baseRevision 处理：在 `CampaignActorController` 自动重读最新 revision 后重试一次。

**TDD**：
- 红：测试 "publish 返回 409 时显示规范错误串"。
- 红：测试 "copyWith 支持 avatarUrl 字段"。
- 绿：实现修复。

### Phase 2：输入栏与头像合二为一（#2）

#### Task 2.1：合并 `+` 按钮到当前身份头像

**目标**：`_buildInputBar` 移除独立的 `+` IconButton，点击当前身份头像弹出统一快捷面板（规范 §输入栏 11 项工具）。

**新面板项**（按规范顺序）：
1. 当前身份精确信息（头像 + 名字 + HP/状态）
2. 打开角色卡
3. 掷骰
4. 技能检定
5. HP 与状态
6. 资料条目
7. 记录线索
8. 分享地点
9. 群文件
10. DM 身份切换（仅 DM）
11. 快速临时身份（仅 DM）

工具按成员能力和当前上下文动态出现，不显示不可用项。

**TDD**：
- 红：测试 "输入栏只有一个身份头像按钮，不存在独立 +"。
- 红：测试 "点击头像弹出包含 11 项工具的面板（DM 视图）"。
- 红：测试 "玩家视图只看到自己可用的工具"。
- 绿：合并 `_showMoreActions` 与 `_showIdentitySheet` 为统一面板。

### Phase 3：头像上传迁移到角色创建/编辑（#1）

#### Task 3.1：CharacterSheet.copyWith 暴露 avatarUrl

**目标**：让上层能通过 copyWith 修改头像字段。

**TDD**：
- 红：测试 `copyWith(avatarUrl: 'x')` 后 `avatarUrl == 'x'`。
- 绿：在 `copyWith` 签名加 `String? avatarUrl` 参数，使用 `??` 透传。

#### Task 3.2：CharacterEditorPage 加头像选择步骤

**目标**：在 `_StandardBuildPage` 的"详情"步骤和 `_CreationFlow.fullSheet` 的基础区，新增 `AvatarPicker` 控件；编辑模式同样可改头像。

**改动**：
- `_DetailsStep`：增加 AvatarPicker，绑定到 `_DetailsState.avatarUrl`。
- `_fullSheet` 基础区：增加 AvatarPicker。
- 提交时把 avatarUrl 写入 `CharacterEditDraft`。
- 头像以本地文件路径保存（离线优先），发布到战役时再转 base64 上传。

**TDD**：
- 红：测试 "标准创建'详情'步骤能选头像并随角色保存"。
- 红：测试 "编辑现有角色能修改头像"。
- 绿：实现 AvatarPicker 集成。

#### Task 3.3：CharacterDetailPage 头部展示头像

**目标**：`_CharacterHeader` 的 CircleAvatar 优先用 `character.avatarUrl`，无头像时退回首字母。

**TDD**：
- 红：测试 "角色有 avatarUrl 时头部 CircleAvatar 使用 Image.network/File"。
- 绿：修改 `_CharacterHeader`。

#### Task 3.4：CharactersTabPage 列表卡片显示头像

**目标**：`_CharacterCard.leading` 优先用 `character.avatarUrl`。

**TDD**：
- 红：测试 "角色卡 leading 显示头像图片而非首字母（当 avatarUrl 非空）"。
- 绿：修改 `_CharacterCard`。

#### Task 3.5：PublishCharacterSheet 移除头像选择，改为自动上传

**目标**：发布对话框不再让用户选头像，而是直接读取 `character.avatarUrl` 上传到服务端媒体服务。

**改动**：
- 移除 `AvatarPicker` 嵌入。
- 发布时若 `character.avatarUrl` 是本地路径，调用媒体上传接口得到 assetId，写入 actor sheet。
- `onPickImage` 参数移除。

**TDD**：
- 红：测试 "PublishCharacterSheet 不再显示 AvatarPicker"。
- 红：测试 "发布时 character.avatarUrl 非空则自动上传"。
- 绿：实现自动上传。

### Phase 4：右上角入口收敛（#4 #5）

#### Task 4.1：聊天页 AppBar 只保留必要入口

**目标**：按规范 §顶部，聊天顶部只显示：返回、战役名称+在线状态、搜索、战役中心。

**改动**：
- `CampaignChatPage` AppBar actions 只保留：
  - 搜索 IconButton（新增）
  - 战役中心 IconButton（`Icons.dashboard_outlined`）
- 移除 `战役资料` 和 `成员` 这两个直接 IconButton。
- "更多菜单"（三点）按规范 §全局设置：战役名称/封面/简介、所有权转移、战役归档、离开战役。

**TDD**：
- 红：测试 "AppBar actions 不含战役资料、成员按钮"。
- 红：测试 "三点菜单只包含 4 项全局设置"。
- 绿：重构 AppBar。

#### Task 4.2：邀请码入口迁移到队伍面板

**目标**：按规范 §队伍，邀请和管理成员在 `战役中心 → 队伍`，DM 就地操作。

**改动**：
- `CampaignTeamPanel` 顶部加"邀请成员"按钮（仅 `canManageCampaign`），点击调 `controller.createInvite` 并显示 `InviteShare` 组件。
- 已有邀请码列表在队伍面板内显示。
- `CampaignDetailPage` 的邀请码区块移除（或降级为只读摘要）。

**TDD**：
- 红：测试 "队伍面板 DM 能看到邀请按钮"。
- 红：测试 "普通玩家在队伍面板看不到邀请按钮"。
- 绿：迁移邀请入口。

#### Task 4.3：战役资料入口迁移到输入栏头像面板

**目标**：按规范 §输入栏，资料条目是头像快捷面板的第 6 项工具，不在 AppBar 单独入口。

**改动**：
- 移除 `_openCampaignContent` 从 AppBar。
- 在 Phase 2 的统一头像面板中加"资料条目"项，点击进入 `CampaignContentPage`。

**TDD**：
- 红：测试 "AppBar 不含资料入口"。
- 红：测试 "头像面板含'资料条目'项"。
- 绿：迁移入口。

### Phase 5：档案条目 UI 整改（#7）

#### Task 5.1：档案详情改为卡片浮窗式显示

**目标**：点击档案条目后用更丰富的 Dialog/BottomSheet 展示完整信息：标题、类型、正文、来源消息、关联角色、关联地点、相关条目。

**TDD**：
- 红：测试 "点击档案条目弹出浮窗含正文 bodyJson 渲染"。
- 绿：扩展 `_showArchiveDetail`。

#### Task 5.2：新建条目按钮按类型区分

**目标**：FAB 不只是"新建条目"，而是提供菜单选择"新建资料/地点/线索/文件"。规范 §档案：DM 在相同页面创建、编辑、发布、隐藏和归档。

**TDD**：
- 红：测试 "FAB 点击后弹出类型选择菜单"。
- 绿：实现类型选择。

#### Task 5.3：记录面板条目可点击

**目标**：`CampaignRecordsPanel` 的 ListTile 加 onTap，点击跳转到对应聊天消息位置或事件详情。

**TDD**：
- 红：测试 "记录面板条目点击后有响应"。
- 绿：实现跳转。

### Phase 6：DM 角色创建入口（#9）

#### Task 6.1：DM 在队伍面板创建常驻 NPC

**目标**：按规范 §DM 角色生命周期完整管理，DM 可在 `战役中心 → 队伍` 创建常驻 NPC/怪物/同伴（actorType: npc/unclaimed/companion，lifecycle: persistent）。

**改动**：
- `CampaignTeamPanel` DM 区加"创建常驻角色"按钮。
- 弹出表单：名称、actorType 选择（npc/unclaimed/companion）、头像、初始 HP、生命周期（默认 persistent）。
- 调用 `POST /campaigns/:id/actors` 接口（`campaignActorController.create`）。

**TDD**：
- 红：测试 "DM 在队伍面板看到'创建常驻角色'按钮"。
- 红：测试 "DM 创建 NPC 调用正确的 API"。
- 绿：实现创建表单。

#### Task 6.2：CharactersTabPage DM 模式恢复本地角色创建入口

**目标**：DM 模式下"角色"tab 仍可创建本地角色（用于 DM 自己的玩家角色或备选角色），不应被 CampaignActorDirectoryPage 完全替代。

**改动**：
- `CharactersTabPage` DM 模式下仍显示本地角色 FAB 和列表。
- 战役角色目录作为独立入口（在战役中心队伍面板里）。

**TDD**：
- 红：测试 "DM 模式下角色 tab 仍有'新角色' FAB"。
- 绿：调整 CharactersTabPage。

## 验收清单

整改完成后必须满足：

- [ ] 普通玩家切换全局 DM 模式后，战役聊天不显示 DM 工具。
- [ ] DM 打开头像面板看到旁白、场外、NPC、临时身份、代管入口，不出现"绑定角色"。
- [ ] 输入栏只有一个身份头像按钮，不存在独立 +。
- [ ] 头像快捷面板按规范 11 项工具动态出现。
- [ ] 聊天 AppBar 只含搜索 + 战役中心；其他入口转入头像面板或三点菜单。
- [ ] 三点菜单只含战役名称/封面/简介、所有权转移、战役归档、离开战役。
- [ ] 邀请码入口在 `战役中心 → 队伍` 面板，DM 可见。
- [ ] 角色创建引导和编辑能选头像，本地保存。
- [ ] 角色卡头部和列表卡片显示头像。
- [ ] 发布到战役对话框不再选头像，自动上传本地头像。
- [ ] 档案条目点击后浮窗显示完整信息（含正文、来源、关联）。
- [ ] 档案新建按钮按类型区分。
- [ ] DM 可在队伍面板创建常驻 NPC/怪物/同伴。
- [ ] DM 模式下角色 tab 仍有本地角色创建入口。
- [ ] 创建角色失败时显示规范错误串。
- [ ] `flutter analyze` 无告警。
- [ ] 所有现有测试 + 新测试通过。

## 执行节奏

每个 Task 独立提交，提交信息格式：

```
fix(v0.1): <task 描述>
```

不跨 Phase 批量提交，保证可回滚。每个 Phase 完成后跑 `flutter test` 全量回归。
