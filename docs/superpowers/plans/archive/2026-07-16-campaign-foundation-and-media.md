# 战役协作地基与身份实现计划

> **面向 AI 代理的工作者：** 必须使用 `executing-plans` 技能逐项执行本计划。

**目标：** 让服务端成为战役权限、成员绑定、发言身份和消息可见信息的唯一可信来源，为聊天优先的战役工作区提供稳定 API。

**架构：** 保留既有 `Campaign`、`CampaignMember`、`CampaignActor` 和 typed chat message 体系；扩展成员状态和角色生命周期，集中到 `CampaignPolicy` 做能力判定。消息创建始终由服务端解析当前成员身份并生成不可变展示快照，客户端只提交意图。媒体在此批次仅建立头像资产元数据与受控上传接口，文件实现沿用 Nest 的本地部署约定。

**技术栈：** NestJS 11、Prisma/PostgreSQL、Jest/Supertest、Flutter HTTP client。

## 边界

- 不实现地图、回合、遭遇或战斗规则引擎。
- 不把角色本地资料库、私有规则包或整张角色卡同步到服务端之外。
- 不以客户端的 DM/Player 外观设置作为任何授权依据。

### 任务 1：扩展战役协作数据模型

**文件：**
- 修改：`apps/server_nest/prisma/schema.prisma`
- 新建：`apps/server_nest/prisma/migrations/20260716160000_campaign_workspace_foundation/migration.sql`
- 修改：`apps/server_nest/test/campaigns.e2e-spec.ts`

1. 先在 e2e 测试新增断言：创建者成员角色为 `owner`；成员视图含 `boundActorId`、`activeSpeakerActorId`、`lastReadAt`（未设置时为 `null`）。
2. 运行 `npm run test:server -- campaigns.e2e-spec.ts`，确认因字段和输出缺失而红灯。
3. 为 `Campaign` 加 `avatarAssetId` 和关系，为 `User` 加 `avatarAssetId` 和关系；新增 `MediaAsset`，保存 owner、mime、size、storage key、width/height、创建时间，避免消息依赖可变 URL。
4. 为 `CampaignMember` 加 `boundActorId`、`activeSpeakerActorId`、`speakerMode`（默认 `boundActor`）、`lastReadAt`；建立与 `CampaignActor` 的命名关系。
5. 为 `CampaignActor` 加 `lifecycle`（persistent/temporary/archived）、`avatarAssetId`、`healthVisibility`，保留兼容的 `status`。
6. 为 `CampaignChatMessage` 加 `speakerMode`、`delegatedByUserId`、`speakerAvatarAssetId`、`publicHealthState` 和 `ooc`；保留旧 `avatarUrl` 至后续迁移完成，读模型优先新字段。
7. 生成 Prisma client，运行同一 e2e 测试确认绿灯。

### 任务 2：把角色、成员和活动身份收敛为能力模型

**文件：**
- 修改：`apps/server_nest/src/modules/campaigns/policies/campaign.policy.ts`
- 修改：`apps/server_nest/src/modules/campaign-sync/campaign-actors.service.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.types.ts`
- 修改：`apps/server_nest/test/campaign-actors.e2e-spec.ts`
- 修改：`apps/server_nest/src/modules/campaigns/policies/campaign.policy.spec.ts`

1. 新增失败用例：玩家不能创建 NPC、不能编辑其他玩家 actor；DM 可以管理任意 actor；归档 actor 不能作为发言身份；玩家只能拥有一条 bound actor。
2. 运行 `npm run test:server -- campaign.policy.spec.ts campaign-actors.e2e-spec.ts`，确认红灯来自未实现的能力限制。
3. 在 `CampaignPolicy` 增加 `capabilitiesFor`、`canBindActor`、`canSpeakAsActor`、`canManageMembershipBinding`，并把 owner 统一视为 `owner` 角色而非仅依赖 `Campaign.ownerId` 的特例。
4. 在 actor service 中提供最小 actor 摘要投影：身份、头像资产、公开生命状态、生命周期、是否可作为当前用户发言身份；禁止玩家读到其他角色的精确 HP/资源。
5. 在所有写路径使用新的 policy，不保留“前端传 actorId 就能冒充”的分支。
6. 运行上述两个测试文件至绿；再运行 `npm run lint:server`。

### 任务 3：实现绑定、发言身份与聊天室上下文 API

**文件：**
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.controller.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.service.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.types.ts`
- 修改：`apps/server_nest/test/campaigns.e2e-spec.ts`

1. 为以下行为先写 e2e 红灯测试：
   - 玩家能绑定自己发布的一个 actor，第二次绑定被拒绝。
   - DM 能为任意成员绑定或清空角色；普通玩家不能改别人绑定。
   - 玩家没有绑定时只能发 `ooc`，`say`/`action` 被拒绝。
   - 当前 speaker 跨请求保存，DM 可选 narrator/NPC/临时 actor，玩家只能选 bound actor 或 OOC。
   - `GET /campaigns/:id/context` 返回 viewer、capabilities、members、actors、当前 membership 和 unread 计数。
2. 运行 `npm run test:server -- campaigns.e2e-spec.ts`，确认红灯。
3. 实现 `PUT /campaigns/:id/members/:userId/binding`、`PUT /campaigns/:id/speaker`、`POST /campaigns/:id/read` 和 `GET /campaigns/:id/context`；控制器仅做 DTO 手工校验，业务规则在 service/policy。
4. 当 DM 以“快速临时身份”发送第一条消息时，在 transaction 内创建临时 actor、写入 active speaker、写消息；失败时三者都不落库。
5. 消息读模型返回 immutable speaker snapshot 和 health projection，绝不直接下发其他玩家完整 sheet。
6. 运行 e2e 测试至绿，随后运行 `npm run test:server -- campaigns.e2e-spec.ts campaign-actors.e2e-spec.ts`。

### 任务 4：升级消息权限、事件格式与未读摘要

**文件：**
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.service.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.types.ts`
- 修改：`apps/server_nest/src/modules/realtime/campaigns.gateway.ts`
- 修改：`apps/server_nest/test/campaigns.e2e-spec.ts`
- 修改：`apps/server_nest/test/campaigns.gateway.spec.ts`

1. 先写失败测试：`say` 与 `action` 由 speaker mode 生成正确样式数据，`system` 仅 DM，DM 代管消息有 `delegatedByUserId`，消息回推和 REST 字段一致。
2. 运行对应 Jest 测试，确认红灯。
3. 将旧的 message kind 归一为 `say`、`action`、`roll`、`system`、`checkRequest`、`archivePublished`、`ooc`；用 `eventData` 承载结构化检定/系统数据，服务端控制 kind 允许范围。
4. 在 campaign list 计算最后一条消息、每个成员的未读数和在线预览；已读接口只单调向前更新 `lastReadAt`。
5. gateway 只广播经过 viewer projection 的消息，不将 actor 私有 sheet 投给 socket 房间。
6. 运行 `npm run test:server -- campaigns.e2e-spec.ts campaigns.gateway.spec.ts` 至绿。

### 任务 5：建立头像媒体资产接口

**文件：**
- 新建：`apps/server_nest/src/modules/media/media.module.ts`
- 新建：`apps/server_nest/src/modules/media/media.controller.ts`
- 新建：`apps/server_nest/src/modules/media/media.service.ts`
- 修改：`apps/server_nest/src/app.module.ts`
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.controller.ts`
- 修改：`apps/server_nest/test/media.e2e-spec.ts`

1. 先写 e2e 红灯：认证用户只能读取自己或已获授权的 campaign media；PNG/JPEG/WebP 在服务器限制内可上传；超限或不支持 MIME 返回 400。
2. 运行 `npm run test:server -- media.e2e-spec.ts`，确认红灯。
3. 实现媒体 asset 创建与受控读取；存储路径按 asset id，不把原始文件名作为 URL；上传大小读取 `ServerSetting.maxUploadSizeMb`。
4. 提供“附着头像”的 service 方法，分别用于用户、campaign、campaign actor；只接受同一 campaign 中授权的 actor。
5. 运行 media e2e 至绿，并回归 campaign e2e。

### 任务 6：服务端收口验证

**文件：**
- 修改：`docs/roadmap/current-execution-status.md`

1. 运行 `npm run lint:server`。
2. 运行 `npm run test:server`。
3. 更新当前执行状态，列出已完成的服务端合同与尚未实现的客户端战役中心。
4. 提交本批次，提交信息：`feat: establish campaign workspace authority`。
