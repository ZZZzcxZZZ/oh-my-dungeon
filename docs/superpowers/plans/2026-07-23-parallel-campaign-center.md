# 战役中心与档案 Wiki 实现计划

> **面向 AI 代理的工作者：** 使用 test-driven-development。严格避开聊天、会话和通用 campaigns service/controller。

**目标：** 重排战役中心概览与角色区，并把档案升级为可阅读、可编辑、可搜索的战役 Wiki。

**架构：** `CampaignCenterPage` 只组织概览、角色、档案三个目的地；概览显示成员与邀请等摘要；角色区管理当前/临时/归档 actor；档案由独立 archive service/controller 提供 CRUD。详情使用宽屏 Dialog、窄屏全高 BottomSheet。

**技术栈：** Flutter Material 3、NestJS、Prisma 现有 Journal/Archive 模型、flutter_test、Jest e2e。

## 文件所有权

- 修改客户端 `campaign_center_page.dart` 与 `presentation/center/**`
- 修改客户端 archive domain model，以及 `campaign_api_client.dart`、`campaign_controller.dart` 中仅 archive 专属的方法签名和映射
- 修改服务端 `campaign-archives.controller.ts`、`campaign-archives.service.ts` 及其专用 types/test
- 新建专用 Flutter/Nest 测试

禁止修改 `campaign_chat_page.dart`、聊天组件、`campaigns.service.ts`、`campaigns.controller.ts` 和会话协议。`campaign_api_client.dart` 与 `campaign_controller.dart` 只能修改 archive 专属代码段，禁止触碰 message、speaker、workspace 与 conversation 方法。

### 任务 1：战役中心信息架构

- [x] 写失败测试：一级只显示概览、角色、档案；"成员"合入概览；"队伍"改名角色；邀请代码、复制/分享动作和当前成员摘要可见。
- [x] 概览使用全宽 section 与清晰间距，不使用嵌套 Card；DM 工具和战役设置分区，不与成员列表粘连。
- [x] 运行 `flutter test test/campaign_center_page_test.dart test/campaign_overview_panel_test.dart`。
- [x] 提交 `refactor(v0.1): reorganize campaign center`。

### 任务 2：角色区管理

- [ ] 写失败测试：玩家角色、常驻 NPC、临时角色、归档角色分区；归档默认折叠；每个角色点击打开统一完整角色卡。
- [ ] DM 显示管理动作，玩家只显示自己可用动作；权限只读已有 capabilities，不根据客户端模式猜测。
- [ ] 运行 `flutter test test/campaign_characters_panel_test.dart test/campaign_actor_pages_test.dart`。
- [ ] 提交 `refactor(v0.1): complete campaign actor panel`。

### 任务 3：档案正文与权限

- [ ] 写 Nest 失败测试：创建/更新档案支持 `bodyBlocks`、tags、links、attachmentRefs；创建者和 manager 可编辑，其他成员只读；搜索匹配标题、摘要、正文和标签。
- [ ] 只在独立 archive service/controller 中实现 DTO 校验和权限；保持已有路径兼容。
- [ ] 写 Flutter 失败测试：档案列表采用资料条目式行；详情可完整滚动；创建/编辑表单可编辑正文，不再只有名称和说明。
- [ ] 窄屏详情使用接近全高的 BottomSheet，宽屏使用最大宽度 760 的 Dialog；禁止局促小卡片。
- [ ] 分别运行 Nest archive e2e 与 `flutter test test/campaign_archive_panel_test.dart`。
- [ ] 提交 `feat(v0.1): turn campaign archives into wiki`。

### 任务 4：验收

- [ ] 运行 campaign center/overview/characters/archive Flutter 测试。
- [ ] 运行服务端 archive 单元/e2e、`npm run lint:server`。
- [ ] 运行 `flutter analyze` 和 `flutter build web --release`。
- [ ] 在报告中列出仍需聊天/事件协议支持的能力，交给第二波整合，不得越界实现。
