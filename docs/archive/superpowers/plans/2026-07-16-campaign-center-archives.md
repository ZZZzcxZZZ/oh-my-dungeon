# 战役中心、档案与记录实现计划

> **面向 AI 代理的工作者：** 必须使用 `executing-plans` 技能逐项执行本计划。

**目标：** 在聊天之外提供一个轻量、可扩展的战役中心，将队伍、地点、线索、资料和记录组织为可协作页面，并为未来战斗模块预留 character/event 基础。

**架构：** 以一个统一 `CampaignArchiveEntry` 代替分别实现地点、线索和群文件；条目使用 `kind` 和 JSON payload 扩展。聊天仍是时间线事实来源，统计和检索从消息及 audit 派生，不引入第二套事件日志。客户端以四个稳定区域呈现：概览、队伍、档案、记录；宽屏用 NavigationRail，窄屏用 NavigationBar。

**技术栈：** NestJS/Prisma、Flutter Material 3、PostgreSQL JSON、Jest、flutter_test。

## 任务 1：定义并实现统一战役档案合同

**文件：**
- 修改：`apps/server_nest/prisma/schema.prisma`
- 新建：`apps/server_nest/prisma/migrations/20260716170000_campaign_archive_entries/migration.sql`
- 新建：`apps/server_nest/src/modules/campaigns/campaign-archives.service.ts`
- 新建：`apps/server_nest/src/modules/campaigns/campaign-archives.controller.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.module.ts`
- 新建：`apps/server_nest/test/campaign-archives.e2e-spec.ts`

1. 先写 e2e 红灯：所有成员可查看已发布档案；DM 可以创建/编辑/归档；玩家只能在被允许的评论/线索入口写入；发布会生成 `archivePublished` 聊天消息。
2. 运行 `npm run test:server -- campaign-archives.e2e-spec.ts`，确认红灯。
3. 新增 `CampaignArchiveEntry`：campaign、kind（document/location/clue/file）、title、summary、payload、visibility、pinned、created/updated/deleted、createdBy/updatedBy、可选 media asset。
4. 提供列表（kind、query、pinned、cursor）和详情 API，所有权限通过 `CampaignPolicy`；写入和聊天发布在 transaction 中完成。
5. 运行档案 e2e 至绿。

## 任务 2：实现战役中心四区与自适应导航

**文件：**
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_center_page.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_overview_panel.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_team_panel.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_archive_panel.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_records_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 新建：`apps/client_flutter/test/campaign_center_page_test.dart`

1. 写失败测试：窄屏 `NavigationBar`、宽屏 `NavigationRail`，四区内容可切换，DM 管理按钮只按 server capability 显示。
2. 运行 `flutter test test/campaign_center_page_test.dart`，确认红灯。
3. 将聊天右上角入口接到 center；聊天保持默认首屏，campaign center 不改写用户当前发言身份。
4. 概览放置置顶公告、快速动作、近期记录；队伍按 character lifecycle 分类并集成 DM 管理；档案用 filter chips；记录提供检索和统计入口。
5. 测试至绿。

## 任务 3：完成队伍、临时角色和档案工作流

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_directory_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_team_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_archive_panel.dart`
- 新建：`apps/client_flutter/lib/src/features/campaigns/presentation/archives/campaign_archive_editor.dart`
- 新建：`apps/client_flutter/test/campaign_archive_panel_test.dart`

1. 写失败测试：DM 可以在队伍页创建、置顶、归档、恢复或升级临时角色；玩家仅能查看允许内容；档案发布后出现在聊天时间线。
2. 运行相关 Flutter 测试确认红灯。
3. 把既有 character directory 作为队伍页实现基础，去除重复入口；临时 character 无消息前可删除，有消息后只能归档。
4. 档案编辑采用 Material 3 dialog/bottom sheet 和明确字段，不暴露 JSON 编辑器给普通用户。
5. 测试至绿。

## 任务 4：聊天记录、搜索和战役统计

**文件：**
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.controller.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.service.ts`
- 修改：`apps/server_nest/test/campaigns.e2e-spec.ts`
- 修改：`apps/client_flutter/lib/src/features/campaigns/data/campaign_api_client.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_records_panel.dart`
- 新建：`apps/client_flutter/test/campaign_records_panel_test.dart`

1. 先写 server/client 红灯：按文字、kind、character、日期搜索；统计返回消息/检定/活跃成员/档案数，不泄露私有角色数值。
2. 实现分页查询与服务器端过滤，客户端列表支持定位到聊天消息。
3. 统计从 chat message、archive entry、character lifecycle 计算，不创建重复 event 表。
4. 运行 server、Flutter 对应测试至绿。

## 任务 5：全量收口

**文件：**
- 修改：`README.md`
- 修改：`docs/roadmap/current-execution-status.md`

1. 运行 `npm run check`。
2. 运行客户端 web build：`cd apps/client_flutter; flutter build web --release`。
3. 在本地启动 client/server，人工验证 player 与 DM 两个账户的可见性、绑定、说/做、头像、档案发布和搜索。
4. 更新文档并提交：`feat: add campaign center archives and records`。
