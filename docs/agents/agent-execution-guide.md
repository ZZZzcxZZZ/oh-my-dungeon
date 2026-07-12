# Agent 执行指南

## 1. 阅读顺序

任何开发 agent 在开始实现前必须按顺序阅读：

1. `README.md`
2. `docs/product/overall-plan.md`
3. `docs/architecture/system-architecture.md`
4. `docs/architecture/domain-model.md`
5. `docs/architecture/api-realtime-boundary.md`
6. `docs/engineering/engineering-standards.md`
7. `docs/roadmap/current-execution-status.md`
8. `docs/roadmap/v0.1-unified-mvp-plan.md`
9. `docs/content/private-phb-import-policy.md`
10. `docs/content/phb-2024-private-import-notes.md`

如果任务涉及部署，还必须阅读：

11. `docs/deployment/self-hosting.md`

## 2. 当前阶段

当前项目统一回到 `0.1` 开发线，尚未达到用户认可的可用 MVP。此前 `v0.2`、`v0.8`、`v1.0`、`v2.x` 均视为内部迭代日志，不代表对外版本或完成状态。后续开发必须围绕 `docs/roadmap/v0.1-unified-mvp-plan.md` 推进。

当前首要方向是：战役像 QQ 群聊一样成为主入口；用户点击战役即可聊天、说话、做动作、掷骰和打开更多跑团工具；角色卡、DM 控场、检定请求和资料库都应从战役聊天室上下文进入。`Session` / `DiceRoll` / `ChatMessage` / `JournalEntry` 等既有模型可以复用，但不能继续把“先新建场次、再开始”作为默认体验。`/api/rooms` 与客户端 rooms 页面仍是冻结资产，不再扩展。

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

不要在当前 `0.1` MVP 中实现：

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
