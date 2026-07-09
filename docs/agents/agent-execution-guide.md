# Agent 执行指南

## 1. 阅读顺序

任何开发 agent 在开始实现前必须按顺序阅读：

1. `README.md`
2. `docs/product/overall-plan.md`
3. `docs/architecture/system-architecture.md`
4. `docs/architecture/domain-model.md`
5. `docs/architecture/api-realtime-boundary.md`
6. `docs/engineering/engineering-standards.md`
7. `docs/roadmap/mvp-roadmap.md`

如果任务涉及部署，还必须阅读：

8. `docs/deployment/self-hosting.md`

## 2. 当前阶段

当前项目已完成 v0.8 检定请求与快捷动作。后续开发必须先阅读 `docs/roadmap/current-execution-status.md`，再按 `docs/roadmap/mvp-roadmap.md` 的版本闸门推进。

v0.4 已用正式 `Session` / `DiceRoll` / `ChatMessage` / `JournalEntry` 模型替换了 `rooms` 原型。`/api/rooms` 与客户端 rooms 页面保留为冻结资产，待后续版本下线，不要再在其上扩展业务功能。v0.5 已新增 `Character` / `CharacterCampaignBinding`，并完成角色创建、编辑、战役绑定、DM 战役角色视图、HP 快捷调整和角色变更 JournalEntry。v0.6 已新增内容库模型与资料库入口，完成 JSON 内容包 dry-run 校验、导入、战役启用/禁用和玩家可用内容查询。v0.7 已新增 NPC、Encounter、EncounterParticipant 与 DM 桌面控场入口，完成遭遇创建、参战者管理、开始/推进/结束、HP 快捷调整和 JournalEntry 记录。v0.8 已新增 CheckRequest / CheckResponse 与场次检定请求入口，完成 DM 发起、玩家响应、目标过滤、关闭请求，以及结果写入 ChatMessage / DiceRoll / JournalEntry。下一步进入 v1.0 自托管公测版。

## 3. 实施原则

### 3.1 小步提交

每个任务应产生一个清晰、可验证的变化。推荐提交粒度：

- 初始化服务端。
- 初始化客户端。
- 添加 Docker Compose。
- 添加 Prisma。
- 添加 health endpoint。
- 添加服务器配置页面。
- 添加 CI。

### 3.2 先测试核心逻辑

以下逻辑需要优先有测试：

- 服务器元信息解析。
- 客户端服务器配置存储。
- 权限 policy。
- 骰子表达式解析。
- 内容包 schema 校验。
- 角色计算。

### 3.3 不提前实现非 MVP 功能

不要在 v0.1-v0.3 中实现：

- 地图战棋。
- AI。
- 插件市场。
- 完整规则自动化。
- 语音视频。
- 复杂模组编辑器。

这些模块只保留目录和边界，不写未使用的大量抽象。

## 4. v0.1 实施任务建议

### 任务 1：创建 monorepo 根结构

创建：

```text
apps/
  client_flutter/
  server_nest/
packages/
  api_contracts/
  dnd_rules/
docs/
infra/
scripts/
```

根目录添加：

```text
README.md
.gitignore
.editorconfig
```

### 任务 2：初始化 NestJS 服务端

在 `apps/server_nest` 初始化 NestJS。

服务端第一批模块：

```text
health
server-info
config
```

必须提供：

```text
GET /health
GET /.well-known/dnd-tool-server
```

### 任务 3：初始化 PostgreSQL 与 Prisma

添加：

```text
prisma/schema.prisma
DATABASE_URL
PrismaService
```

v0.1 不需要完整领域模型迁移，但需要能连接 PostgreSQL 并通过服务端健康检查确认数据库可用。

### 任务 4：添加 Docker Compose

添加：

```text
docker-compose.yml
docker-compose.dev.yml
.env.example
```

容器：

```text
server
postgres
```

### 任务 5：初始化 Flutter 客户端

在 `apps/client_flutter` 初始化 Flutter App。

必须包含：

```text
MaterialApp.router
ThemeData(useMaterial3: true)
server_profiles feature
settings feature
```

### 任务 6：客户端添加服务器

实现：

```text
服务器列表页
添加服务器表单
测试连接
读取 /.well-known/dnd-tool-server
保存 server profile
切换当前服务器
```

本地保存字段：

```text
id
name
baseUrl
apiBaseUrl
websocketUrl
lastCheckedAt
lastKnownVersion
```

### 任务 7：CI

添加 GitHub Actions：

```text
server lint
server test
flutter analyze
flutter test
docker build
```

## 5. v0.2 实施任务建议

v0.2 开始实现账号、服务器隔离和模式切换。

任务：

1. Auth 数据模型。
2. 注册登录 API。
3. JWT。
4. 首次注册用户成为 ServerAdmin。
5. 客户端按 serverProfile 保存 token。
6. Player/DM 模式切换。
7. 服务器注册开关。

## 6. v0.3 实施任务建议

v0.3 实现战役与成员。

任务：

1. Campaign 模型。
2. CampaignMember 模型。
3. CampaignInvite 模型。
4. DM 创建战役。
5. 玩家邀请码加入。
6. Player 战役列表。
7. DM 战役列表。
8. 权限 policy 测试。

## 7. 约束清单

开发 agent 必须遵守：

- 客户端不绑定中心服务器。
- 账号和 token 按服务器隔离。
- Player Mode 和 DM Mode 是客户端工作台，不是权限来源。
- 服务端权限以 CampaignMember 和 ServerAdmin 为准。
- DM 修改基础内容必须通过 ContentOverride。
- 关键业务事件必须写 JournalEntry。
- WebSocket 不能作为唯一持久化来源。
- Material 3 官方组件优先。
- 不在 MVP 中实现地图战棋。

## 8. 完成定义

每个版本完成时必须满足：

1. 对应路线图的验收标准。
2. 相关测试通过。
3. 文档更新。
4. Docker Compose 路径可用。
5. Flutter 至少能在一个目标平台运行。
