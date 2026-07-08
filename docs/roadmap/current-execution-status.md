# 当前执行状态与版本推进计划

更新时间：2026-07-09

## 结论

项目按 `docs/roadmap/mvp-roadmap.md` 的版本闸门推进：

1. `v0.1 工程骨架` 已封版并打 tag `v0.1.0`。
2. `v0.2 账号、服务器、双模式` 已完成并打 tag `v0.2.0`。
3. 下一步进入 `v0.3 战役与成员`。
4. 已经提前实现的 `rooms` 和掷骰能力先视为原型资产，后续在 v0.3/v0.4 中重命名、归并或替换为正式的 Campaign/Session/Table 模型。

## 已完成代码状态

### 工程基础

- Monorepo 根结构已建立。
- Flutter 客户端已初始化，使用 Material 3。
- NestJS 服务端已初始化。
- PostgreSQL + Prisma 配置已存在。
- Docker Compose 与 `.env.example` 已存在。
- `/health` 已实现。
- `/.well-known/dnd-tool-server` 已实现。
- 根目录脚本已提供 bootstrap、check、dev server/client 等入口。
- CI 目录已存在。

### 客户端服务器配置

- 客户端可以保存服务器 profile。
- 客户端可以添加、编辑、删除服务器。
- 客户端可以读取 well-known metadata。
- 客户端支持 Player/DM 模式切换。

### 已提前实现的原型能力（冻结状态）

这些能力有价值，但版本归属超前，不能继续在现有 `rooms` 抽象上无限加功能。v0.3 已建立正式 Campaign 模型后，下列原型进入**冻结状态**：不再新增功能、不绑定到 Campaign，仅保留为可运行的演示资产，待 v0.4 引入 Session 与正式 DiceRoll 模型时整体替换。

- 服务端 `/api/rooms` 内存房间 API。
- 服务端 `/api/rooms/:roomId/rolls` 内存掷骰记录 API。
- 客户端房间列表和房间详情页。
- 客户端 D20 掷骰与骰子表达式掷骰。
- `dart_dice_parser` 已接入客户端领域层。

> 注意：`/api/rooms` 与 `/api/campaigns` 是两套独立抽象。Campaign 成员不自动获得 rooms 权限，rooms 也不读取 Campaign 数据。禁止在 rooms 原型上叠加 Campaign/Session 逻辑。

## 与路线图的差距

### v0.1 已封版

v0.1 工程骨架已封版并打 tag `v0.1.0`。工程基础、CI、Docker Compose、客户端服务器 profile 管理和 Player/DM 模式切换均已就位。`rooms` 和掷骰原型保留为资产，后续在 v0.3/v0.4 中归并到正式模型。

### v0.2 已完成

v0.2 账号、服务器、双模式里程碑已封版并打 tag `v0.2.0`。已完成内容：

- Prisma `User` / `ServerAdmin` / `RefreshToken` 数据模型。
- `PasswordHashService`（bcryptjs）。
- `AuthService` 注册逻辑，首次注册用户成为 ServerAdmin owner，注册开关关闭时拒绝。
- `POST /api/auth/register`。
- `POST /api/auth/login`，支持 username 或 email，返回 access token + refresh token。
- `GET /api/auth/me`，Bearer token 鉴权。
- `POST /api/auth/refresh`，按 refresh token hash 校验，签发新 access token。
- `POST /api/auth/logout`，revoke refresh token。
- `GET /api/server-settings` / `PATCH /api/server-settings`，admin 可切换注册开关。
- 客户端 `AuthTokenStore` 按 server profile id 隔离保存 token。
- 客户端 `AuthApiClient` 覆盖 register/login/me/refresh/logout。
- 客户端 `AuthPage` 登录/注册 UI，`AuthController` 管理会话状态。
- 客户端 `ServerHomePage` 集成账号区，未登录显示登录/注册入口，已登录显示用户名和退出登录。

### v0.3 尚未开始

当前 `rooms` 不是正式路线图里的 Campaign。v0.3 必须建立正式模型：

- Campaign。
- CampaignMember。
- CampaignInvite。
- 权限 policy。
- DM 创建战役。
- 玩家邀请码加入。
- Player/DM 战役列表。

### v0.4 只做了极小原型

掷骰表达式和房间掷骰记录属于 v0.4/v0.8 的一部分能力，但当前缺少正式前置：

- 没有 Session。
- 没有 ChatMessage。
- 没有 JournalEntry。
- 没有 WebSocket 实时广播。
- 没有真实权限过滤和可见性。

## 后续开发规则

### 版本闸门

每个版本开始前必须创建或更新一个版本执行计划，包含：

- 版本目标。
- 验收标准。
- 任务列表。
- 数据模型变更。
- API 契约。
- Flutter 页面/状态流。
- 测试策略。
- 不做事项。

每个版本结束前必须满足：

- 路线图验收标准逐项满足。
- 文档同步更新。
- 目标测试通过。
- 版本闸门检查通过。
- 必要时打 tag，例如 `v0.1.0`。

### 提交粒度

仍然允许小步提交，但提交必须服务于当前版本计划。提交信息建议带版本前缀：

```text
feat(v0.2): add user auth schema
feat(v0.2): add register endpoint
feat(v0.2): persist server token per profile
docs(v0.2): update account setup guide
```

### 验证策略

全量 `npm run doctor` 不是日常每个小改动的默认动作。后续采用分层验证：

- 单个领域逻辑改动：运行对应单元测试。
- 单个 Flutter 页面改动：运行对应 widget test + 必要时 `flutter analyze`。
- 单个服务端 API 改动：运行对应 e2e 或 service test + 必要时 server lint。
- 跨端契约改动：运行服务端相关测试 + 客户端 API 测试。
- 版本闸门、合并前、依赖升级、Docker/CI/脚本改动：运行 `npm run doctor`。

`doctor` 只证明当前工作区健康，不证明需求设计正确。版本计划和验收清单必须先行。

## 下一版本执行顺序

### 封版 v0.1

目标：让工程骨架真实可复现，文档与代码一致。

任务：

1. 更新 README 当前状态。
2. 更新 Agent 执行指南当前阶段。
3. 检查 CI workflow 是否覆盖 server lint/test、Flutter analyze/test、Docker config/build。
4. 检查 Docker Compose 一键启动路径。
5. 记录 v0.1 缺口和不进入 v0.1 的超前原型。
6. 通过 v0.1 验收后打 `v0.1.0` tag。

### v0.2 账号、服务器、双模式

目标：完成账号体系和服务器隔离，模式切换从本地偏好升级为登录后的用户偏好。

任务组：

1. 服务端 auth 数据模型：User、ServerAdmin、RefreshToken 或 Session。
2. 服务端 auth API：register、login、refresh、logout、me。
3. Server settings API：注册开关、服务器名称等。
4. 客户端 auth 存储：按 server profile 隔离 token。
5. 客户端登录/注册 UI。
6. 客户端当前用户状态与退出登录。
7. v0.2 文档与验收。

### v0.3 战役与成员

目标：替代当前 `rooms` 原型，用正式 Campaign 模型承载跑团组织。

任务组：

1. Campaign / CampaignMember / CampaignInvite Prisma 模型。
2. Campaign 权限 policy。
3. DM 创建战役。
4. 邀请码生成与加入。
5. Player/DM 战役列表。
6. 成员管理基础版。
7. ~~迁移或废弃 `rooms` 原型。~~ → 调整：`rooms` 原型在 v0.3 保持冻结（见上文「已提前实现的原型能力（冻结状态）」），不在 v0.3 迁移或删除。正式替换推迟到 v0.4，届时以 Session + DiceRoll 模型承接，并下线 `/api/rooms`。

### v0.4 跑团桌面基础版

目标：在 Campaign 下创建 Session，并提供聊天、公开骰、日志和实时同步。

任务组：

1. Session 模型和 API。
2. DiceRoll 正式模型，替换当前 room roll。
3. JournalEntry。
4. ChatMessage。
5. WebSocket gateway。
6. 客户端 table 页面。
7. 掷骰结果实时广播和持久化。

## 立即行动

v0.2 已封版。下一步启动 v0.3 战役与成员，按 `docs/roadmap/v0.3-execution-plan.md` 推进。
