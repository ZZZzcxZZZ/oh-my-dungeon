# D&D Table Tool

开源、自托管优先的 D&D 跑团辅助工具。客户端使用 Flutter + Material 3，服务端使用 NestJS + PostgreSQL + Prisma。

## 当前状态

当前已完成 v0.1 工程骨架的第一批落地：

- Monorepo 基础结构
- Flutter 客户端骨架
- Material 3 服务端配置入口
- NestJS 服务端骨架
- `/health`
- `/.well-known/dnd-tool-server`
- Prisma schema 初始文件
- Docker Compose 配置
- GitHub Actions CI 配置
- 服务端与客户端基础测试
- 本地开发环境脚本与 VS Code 推荐配置

## 目录

```text
apps/
  client_flutter/      Flutter 客户端
  server_nest/         NestJS 服务端
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
- [Agent 执行指南](docs/agents/agent-execution-guide.md)