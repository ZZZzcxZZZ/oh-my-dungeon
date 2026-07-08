# D&D Table Tool

开源、自托管优先的 D&D 跑团辅助工具。客户端使用 Flutter + Material 3，服务端使用 NestJS + PostgreSQL + Prisma。

## 当前状态

v0.2 账号、服务器、双模式里程碑已完成并打 tag `v0.2.0`。用户可以在自托管服务器注册、登录，客户端按服务器 profile 隔离账号状态。下一步进入 v0.3 战役与成员。

- Monorepo 基础结构
- Flutter 客户端骨架
- Material 3 服务端配置入口
- NestJS 服务端骨架
- `/health`
- `/.well-known/dnd-tool-server`
- Prisma schema（User / ServerAdmin / RefreshToken / ServerSetting）
- Docker Compose 配置
- GitHub Actions CI 配置
- 服务端与客户端基础测试
- 本地开发环境脚本与 VS Code 推荐配置
- 客户端服务器 profile 管理
- 客户端 Player/DM 模式切换
- 服务端 auth API：register / login / me / refresh / logout
- 服务端 server-settings API：注册开关管理
- 客户端按服务器隔离 token 存储
- 客户端登录/注册 UI 与当前用户状态
- room / dice 原型能力，后续将在 v0.3/v0.4 归并到 Campaign / Session / Table 模型

当前执行状态见 [当前执行状态与版本推进计划](docs/roadmap/current-execution-status.md)。

## 目录

```text
apps/
  client_flutter/      Flutter 客户端
  server_nest/         NestJS 服务端
packages/
  api_contracts/       未来 OpenAPI / DTO 契约边界
  dnd_rules/           未来共享 D&D 规则计算边界
infra/                 未来部署、反向代理、备份恢复样例
docs/                  产品、架构、部署、开发和 agent 执行文档
scripts/               本地 bootstrap、检查和启动脚本
.github/workflows/     CI 配置
```

## 快速开始

推荐使用 Node.js 22 LTS、Flutter stable 和 npm 10+。

```powershell
npm run bootstrap
npm run check
```

如果本机没有 Docker CLI，`npm run check` 会跳过 Compose 校验，并在输出中给出提示。

## 常用命令

```bash
npm run dev:server
npm run dev:client
npm run lint:server
npm run analyze:client
npm run test
npm run check
npm run docker:config
```

## 自托管部署草案

项目提供 Docker Compose 配置：

```bash
cp .env.example .env
docker compose up -d
```

安装 Docker Desktop 后可运行：

```bash
docker compose config
docker compose up -d
```

## 文档索引

- [总体产品规划](docs/product/overall-plan.md)
- [系统架构设计](docs/architecture/system-architecture.md)
- [领域模型设计](docs/architecture/domain-model.md)
- [API 与实时事件边界](docs/architecture/api-realtime-boundary.md)
- [工程规范](docs/engineering/engineering-standards.md)
- [本地开发环境](docs/development/local-setup.md)
- [自托管与部署规划](docs/deployment/self-hosting.md)
- [MVP 版本路线图](docs/roadmap/mvp-roadmap.md)
- [v0.1 工程骨架封版清单](docs/roadmap/v0.1-release-checklist.md)
- [Agent 执行指南](docs/agents/agent-execution-guide.md)
