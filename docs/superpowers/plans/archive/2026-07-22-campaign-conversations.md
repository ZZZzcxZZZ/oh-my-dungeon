# 0.1 战役可展开会话卡片实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为战役增加安全的主聊、私聊和小群会话，并在主页使用一个可展开战役卡片统一承载入口。

**架构：** 服务端新增 CampaignConversation 聚合和成员 policy，消息继续归属 Campaign 但必须指定 conversationId。客户端增加会话 controller/cache，战役卡片展示摘要，现有 CampaignChatPage 通过会话参数复用。

**技术栈：** NestJS、Prisma/PostgreSQL、Socket.IO、Flutter Material 3、Jest、flutter_test。

---

## 文件结构

- 修改 `apps/server_nest/prisma/schema.prisma`：Conversation、ConversationMember、message relation。
- 创建 `apps/server_nest/src/modules/campaigns/conversations/campaign-conversations.service.ts`：会话用例。
- 创建 `apps/server_nest/src/modules/campaigns/conversations/campaign-conversations.controller.ts`：REST。
- 创建 `apps/server_nest/src/modules/campaigns/policies/campaign-conversation.policy.ts`：会话授权。
- 修改 `apps/server_nest/src/modules/realtime/campaigns.gateway.ts`：conversation room。
- 修改 `apps/server_nest/src/modules/campaigns/campaigns.service.ts`：创建战役时创建 main conversation。
- 修改 `apps/client_flutter/lib/src/features/campaigns/domain/campaign.dart`：Conversation 模型与摘要。
- 修改 `apps/client_flutter/lib/src/features/campaigns/data/campaign_api_client.dart`：会话 API。
- 创建 `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_conversation_controller.dart`：会话状态。
- 创建 `apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_expandable_card.dart`：展开卡片。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/campaigns_tab_page.dart`：列表组装与路由。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`：按 conversation 加载/发送。
- 删除 `apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_list_tile.dart` 和私有 `_CampaignChatListItem` 的重复实现，统一为新组件。

### 任务 1：Conversation 数据模型与迁移

- [ ] **步骤 1：编写失败的 Prisma/服务测试**

在 `campaigns.e2e-spec.ts` 增加断言：创建战役后恰好有一个 main conversation；重复创建 main 被唯一约束拒绝；旧消息迁移后 conversationId 非空。

- [ ] **步骤 2：修改 Prisma schema**

新增两个 model，并给 Campaign 增加 `conversations`，给 CampaignChatMessage 增加 `conversationId` 和 relation。使用 `@@unique([campaignId, kind])` 不能满足多个 group，因此增加 nullable `mainKey`，main 写固定值 `main` 并用 `@@unique([campaignId, mainKey])` 保证唯一；nullable `directKey` 使用 `@@unique([campaignId, directKey])` 防止重复私聊，其余会话对应键为 null。

- [ ] **步骤 3：创建可回滚迁移**

迁移顺序固定为：新增 nullable conversationId；为每个 campaign 插入 main；回填消息；设置非空和外键；增加索引 `[conversationId, createdAt]`。不得使用 `db push --force-reset`。

- [ ] **步骤 4：验证并提交**

运行：`npm --prefix apps/server_nest test -- campaigns.e2e-spec.ts`

提交：`feat(v0.1): add campaign conversation model`

### 任务 2：会话 policy 与 REST API

- [ ] **步骤 1：编写失败 e2e 测试**

覆盖主聊列表、direct 幂等创建、group 创建/改名、非成员 403、私聊第三方 403、离开战役后 403、主聊不可归档。

- [ ] **步骤 2：实现 policy**

Policy 提供 `assertCanRead`、`assertCanWrite`、`assertCanManage`。所有方法先校验活动 CampaignMember，再按 kind 校验 ConversationMember。

- [ ] **步骤 3：实现 service/controller**

direct 创建在事务中规范化两个 userId，并使用唯一 `directKey`（排序后 userId 拼接的 SHA-256）避免重复。group 创建要求 2 至 20 名活动成员且自动包含创建者。

- [ ] **步骤 4：验证并提交**

运行：`npm --prefix apps/server_nest test -- campaign-conversations.e2e-spec.ts`

提交：`feat(v0.1): add campaign conversation api`

### 任务 3：消息 API 与 Socket 隔离

- [ ] **步骤 1：编写失败测试**

REST 测试断言历史和发送必须携带 conversationId；Gateway 测试断言消息只广播到 conversation room，非成员 join 被拒绝。

- [ ] **步骤 2：修改消息查询和发送**

所有读写在查询前调用 conversation policy。保存消息时同时写入 campaignId 和 conversationId，并验证两者一致。

- [ ] **步骤 3：修改 Gateway**

房间名固定为 `campaign:{campaignId}:conversation:{conversationId}`。客户端切换会话时 leave 旧房间再 join 新房间。

- [ ] **步骤 4：验证并提交**

运行：`npm --prefix apps/server_nest test -- campaigns.e2e-spec.ts campaigns.gateway.spec.ts`

提交：`feat(v0.1): isolate campaign conversation realtime`

### 任务 4：Flutter 会话 domain、API 与 controller

- [ ] **步骤 1：编写失败单元测试**

在 `campaign_api_client_test.dart` 覆盖会话解析、direct/group 请求和 conversation 路径；新增 controller 测试覆盖按 campaign 缓存、展开时加载、创建后排序和错误保留。

- [ ] **步骤 2：实现 domain/API/controller**

定义 `CampaignConversationSummary`，字段与 API 一致。Controller 使用 `Map<String, List<CampaignConversationSummary>>` 按 campaign 缓存，不把私聊内容写入离线公共 cache。

- [ ] **步骤 3：验证并提交**

运行：`flutter test test/campaign_api_client_test.dart test/campaign_conversation_controller_test.dart`

提交：`feat(v0.1): add campaign conversation client state`

### 任务 5：可展开战役卡片

- [ ] **步骤 1：编写失败 widget 测试**

创建 `campaign_expandable_card_test.dart`，覆盖折叠摘要、主体进入主聊、箭头只展开、主聊置顶、私聊/小群排序、未读 badge、窄屏无溢出和无嵌套 Card。

- [ ] **步骤 2：实现组件**

使用一个 `Card` 加 `InkWell`/`IconButton`，展开内容用 `AnimatedSize` 和普通 `ListTile`。主聊行始终第一，操作使用 `person_add_outlined` 与 `group_add_outlined` 图标并提供 Tooltip。

- [ ] **步骤 3：替换重复列表实现**

`CampaignsTabPage` 改为渲染 `CampaignExpandableCard`。删除未使用的 `CampaignListTile` 和 `_CampaignChatListItem`，保留 `_formatListTime` 等通用逻辑到新组件。

- [ ] **步骤 4：验证并提交**

运行：`flutter test test/campaign_expandable_card_test.dart test/campaigns_tab_page_test.dart`

提交：`feat(v0.1): add expandable campaign conversation card`

### 任务 6：私聊与小群创建流程

- [ ] **步骤 1：编写失败 widget 测试**

覆盖从展开卡片选择一名成员创建私聊、选择多名成员并命名小群、取消不请求、API 错误保留输入、成功后直接打开新会话。

- [ ] **步骤 2：实现 Material 3 流程**

手机使用可滚动 `AlertDialog`，宽屏使用同一表单并限制 560px。成员使用 CheckboxListTile；私聊只能选一人，小群至少选择一名其他成员。

- [ ] **步骤 3：验证并提交**

运行：`flutter test test/campaign_conversation_dialog_test.dart test/campaigns_tab_page_test.dart`

提交：`feat(v0.1): add campaign private and group chat flows`

### 任务 7：按会话复用聊天页

- [ ] **步骤 1：编写失败测试**

更新聊天页测试，断言标题来自 conversation、历史/发送带 conversationId、切换页面连接正确 Socket room、战役中心仍使用 campaignId。

- [ ] **步骤 2：修改 CampaignChatPage/Controller**

页面构造函数要求 `CampaignConversationSummary conversation`。Controller 的 messages 按 conversationId 隔离，离开页面只断开当前会话订阅。

- [ ] **步骤 3：验证并提交**

运行：`flutter test test/campaign_chat_actor_test.dart test/campaign_controller_test.dart test/campaigns_tab_page_test.dart`

提交：`refactor(v0.1): scope campaign chat by conversation`

### 任务 8：全栈验收

- [ ] **步骤 1：运行服务端与客户端门禁**

运行：`npm run doctor`

预期：服务端 lint、Flutter analyze、全部测试和 Docker config 通过。

- [ ] **步骤 2：迁移副本数据验证**

在数据库副本执行迁移，记录迁移前后 CampaignChatMessage 数量，断言完全一致且所有 conversationId 非空。

- [ ] **步骤 3：Web 构建与响应式检查**

运行：`flutter build web --release`

在 360、390、600、900、1280px 检查折叠/展开卡片、私聊和小群流程。

- [ ] **步骤 4：更新执行状态**

更新 `docs/roadmap/current-execution-status.md`，提交：`docs(v0.1): close campaign conversations phase`
