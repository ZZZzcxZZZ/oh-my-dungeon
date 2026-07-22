# 聊天优先战役客户端实现计划

> **面向 AI 代理的工作者：** 必须使用 `executing-plans` 技能逐项执行本计划。

**目标：** 用 Material 3 重构战役列表和聊天，让玩家像使用群聊一样进入战役，同时将发言身份、角色入口、生命环和权限提示放到恰当的位置。

**架构：** Flutter 继续以本地角色卡和内容资料库为离线事实来源；campaign API 只提供在线协作状态。新增轻量 `CampaignContextController` 和可复用的 `CampaignAvatar`，把 1600 行 chat page 分拆为 header、timeline、composer、identity sheet 和 message bubble，避免一个页面承担网络、权限与视觉全部职责。

**技术栈：** Flutter、Material 3、现有 http/socket.io、shared_preferences、flutter_test。

## 任务 1：扩展客户端战役合同与上下文控制器

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/domain/campaign.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/domain/campaign_actor.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/data/campaign_api_client.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_context_controller.dart`
- 修改：`apps/client_flutter/test/campaign_api_client_test.dart`
- 新建：`apps/client_flutter/test/campaign_context_controller_test.dart`

1. 先为 context、capabilities、health projection、speaker state 和 binding API 写解析/请求测试，确认新 API 目前不存在。
2. 运行 `flutter test test/campaign_api_client_test.dart test/campaign_context_controller_test.dart`，确认红灯。
3. 实现强类型 domain model 和 API client；context controller 只负责加载、刷新、切换 speaker、绑定、标记已读和暴露 busy/error 状态。
4. 所有客户端权限可见性只读取 server `capabilities`；本地 client mode 不被用作授权判断。
5. 运行两份测试至绿。

## 任务 2：实现可复用生命环头像与详情入口

**文件：**
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_avatar.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_actor_quick_sheet.dart`
- 新建：`apps/client_flutter/test/campaign_avatar_test.dart`

1. 先写 widget 红灯测试：unknown 为中性环、healthy/injured/critical/down 各有确定语义、无头像显示首字母、点击会调用详情回调。
2. 运行 `flutter test test/campaign_avatar_test.dart`。
3. 用 `CircleAvatar`、`CustomPainter`/`CircularProgressIndicator` 的受限尺寸实现生命环，禁止名字旁重复 HP 文本；自己的/DM 的 quick sheet 才显示精确数值，其他成员显示状态词。
4. quick sheet 用 ModalBottomSheet 呈现，玩家自己打开本地/战役角色详情，DM 可进入 campaign actor sheet。
5. 运行 widget 测试至绿。

## 任务 3：重构战役列表与创建引导

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaigns_tab_page.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_list_tile.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/create_campaign_flow.dart`
- 修改：`apps/client_flutter/test/campaign_controller_test.dart`
- 新建：`apps/client_flutter/test/campaigns_tab_page_test.dart`

1. 先写失败测试：列表显示最近消息、未读 badge、成员头像栈；只在 server 有 `createCampaign` capability 且本地 DM 工作区启用时显示创建；创建流程分 3 步并写入 owner 身份。
2. 运行相应 Flutter 测试确认红灯。
3. 实现紧凑 QQ 式列表和 Material 3 `Stepper`/bottom-sheet 创建流；不再把空白“加入”按钮固化进底栏。
4. 运行测试至绿。

## 任务 4：拆分聊天页面并接入身份、说/做和工具入口

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_chat_header.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_message_bubble.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_composer.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_identity_sheet.dart`
- 修改：`apps/client_flutter/test/campaign_chat_actor_test.dart`

1. 先写 widget 红灯：顶部只保留返回、标题、搜索、战役中心；没有绑定的玩家仅能 OOC；说/做为紧凑的 segmented control；avatar tools 打开 identity sheet；DM 才看到临时/NPC/代管身份。
2. 运行 `flutter test test/campaign_chat_actor_test.dart`，确认失败。
3. 分离页面状态和 widgets，使用 context controller 发送消息和标记已读；消息按 say/action/system/roll/ooc 展示，系统信息使用粗体，action 使用斜体且带身份来源。
4. 将原加号能力收进头像工具 sheet：角色、检定、状态、档案发布、DM 身份。普通玩家不显示 DM 操作。
5. 每条消息头像能打开 quick sheet；消息从 server snapshot 渲染，历史消息不因头像更新失真。
6. 运行聊天测试和 `flutter analyze` 至绿。

## 任务 5：添加客户端头像选择与战役绑定 UX

**文件：**
- 新建：`apps/client_flutter/lib/src/features/campaigns/data/campaign_media_api_client.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/avatar_picker.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/actors/publish_character_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 新建：`apps/client_flutter/test/avatar_picker_test.dart`

1. 写失败测试：选择图片后仅上传到 campaign server，失败可重试，未绑定角色时引导选择本地角色而不是开放普通发言。
2. 运行 avatar/binding 相关测试确认红灯。
3. 使用 `file_picker` 做图片选择，web 与桌面共用受控 bytes 上传；裁剪是后续增强，当前保证正方形预览和大小限制提示。
4. 发布/绑定成功后刷新 campaign context，并让当前 identity 自动切到 bound actor。
5. 运行测试至绿并提交：`feat: rebuild campaign chat workspace`。

