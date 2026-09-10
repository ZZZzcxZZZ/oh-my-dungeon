# OhMyDungeon

[![CI](https://github.com/ZZZzcxZZZ/oh-my-dungeon/actions/workflows/ci.yml/badge.svg)](https://github.com/ZZZzcxZZZ/oh-my-dungeon/actions/workflows/ci.yml)

开源、离线优先、可自托管的 D&D 跑团辅助工具。Flutter 客户端（Material 3）+ NestJS
服务端（PostgreSQL / Prisma）。客户端在无服务器时仍可完整使用本地能力，服务器用于
账号、可选 Personal Vault 同步与多人战役协作。

- **版本**：`0.1`（开发线）
- **当前不包含**：战斗系统、AI Agent 运行时（底层契约已预留，不在 UI 暴露未完成入口）
- **设计系统**：[`DESIGN.md`](DESIGN.md)（token + 规范）与
  [设计审查报告](docs/design/design-audit.md)

## 产品模型

| 概念 | 说明 |
|---|---|
| **Character** | 统一领域名。玩家在本地创建，发布并绑定到战役 |
| **战役** | 类似群聊的长期跑团工作区：主聊、私聊、小群、角色、成员、档案、共享资料 |
| **私人工作区** | 每个服务器账号一份本地数据；未登录使用 `local` 工作区 |
| **资料库** | 本地内容包 + 战役私有条目，离线可读、可检索 |

`Room`、`Session`、`Actor` 已退出产品模型，只允许出现在兼容迁移与历史档案中。

## 仓库结构

```text
apps/
  client_flutter/        Flutter 客户端（离线优先，Material 3）
  server_nest/           NestJS 服务端（REST + Socket.IO，Prisma/PostgreSQL）
infra/linux-server/      自托管部署脚本（start.sh / stop.sh / README）
scripts/                 环境、验证、打包与私有资料工具
docs/                    当前规范 + 历史档案（从 docs/README.md 进入）
DESIGN.md                设计系统 token 与规范（客户端主题即其实现）
docker-compose.yml       生产编排（PostgreSQL + 服务端）
dist/                    本地构建产物（Git 忽略）
private-imports/         本地私有资料（Git 忽略）
```

## 环境要求

- Node.js 22 LTS、npm 10+
- Flutter stable（Dart 随 Flutter 提供）
- Docker Engine + Compose v2（本地数据库 / 自托管部署）
- Python 3（仅私有资料工具与脚本测试需要）

## 快速开始

```powershell
npm run bootstrap     # 安装服务端依赖 + flutter pub get
npm run check         # 服务端 lint/测试 + 客户端 analyze/测试（阶段门）
```

**纯客户端（无需服务器）**

```powershell
npm run dev:client
```

角色、资料库、设置与 Markdown 镜像均可用；未配置服务器时战役联机与 Vault 同步不可用。

**带服务端本地开发**

```powershell
npm run docker:up     # 启动 PostgreSQL
npm run dev:server    # 启动 NestJS
npm run dev:client    # 启动 Flutter
```

## 常用命令

| 命令 | 作用 |
|---|---|
| `npm run check` | 阶段门：服务端 lint/测试 + 客户端 analyze/测试 |
| `npm run test` | 服务端 + 客户端测试 |
| `npm run test:server` / `npm run test:client` | 分别运行 |
| `npm run lint:server` / `npm run analyze:client` | 静态检查 |
| `npm run lint:design` | 校验 `DESIGN.md`（token 引用、章节顺序、对比度） |
| `npm run test:scripts` | Python 脚本层单测（打包、预览服务、提取器） |
| `npm run dev:server` / `npm run dev:client` | 本地开发 |
| `npm run docker:up` / `docker:down` / `docker:logs` | 本地数据库 |
| `npm run preview:client` | 本地 Web 预览（含后端代理） |

## 自托管部署（Docker）

```powershell
# 1) 构建 Linux 部署包（需要 apps/server_nest/engines/，见下）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-linux-server-package.ps1
```

```bash
# 2) 在服务器上
tar xzf ohmydungeon-server-linux-0.1.0.tar.gz
cd ohmydungeon-server-linux-0.1.0
chmod +x start.sh stop.sh
./start.sh          # 自动生成 .env 密钥、探测 PUBLIC_BASE_URL、迁移并等待 /health
```

- 客户端通过 `/.well-known/dnd-tool-server` 获取 `apiBaseUrl` 与 `websocketUrl`。
- **公网访问**：除服务器防火墙（如 `ufw allow 3000/tcp`）外，云厂商安全组也必须放行
  **TCP 3000**——实例自身访问公网 IP 同样受安全组约束。
- 首次启动请将 `PUBLIC_BASE_URL` 设为客户端实际可达的地址（`http://<host>:3000`
  或反向代理的 HTTPS 域名）。

详见 [自托管](docs/deployment/self-hosting.md)、[数据库迁移](docs/deployment/database-migrations.md)、
[备份与恢复](docs/deployment/backup-restore.md)。

## 构建发行物

**公开构建**（不含商业规则正文）

```powershell
cd apps/client_flutter
flutter build apk --release
```

**私有资料构建**（本地自用，含 PHB/MM/DMG，可选内嵌默认服务器）

```powershell
pwsh -File scripts/build_private_client.ps1 -Target apk -BuildArgs @(
  '--release',
  '--dart-define=BUNDLED_DEFAULT_SERVER=true',
  '--dart-define=DEFAULT_SERVER_BASE_URL=http://<host>:3000'
)
```

脚本会临时注入 `bundled_content.json` 并在构建后恢复为 `{}`。完整流程（提取 → 校验
→ 打包 → 离线 Prisma 引擎 → 合规清单）见
[私有资料流水线](docs/development/private-content-pipeline.md)。

## 设计系统与回归保护

- [`DESIGN.md`](DESIGN.md)：颜色/排版/圆角/间距/组件 token 与八段规范；
  `npm run lint:design` 使用官方 `@google/design.md` 校验。
- [`docs/design/design-audit.md`](docs/design/design-audit.md)：全量 UI 审查（约 430 个
  元素）与逐项修复记录。
- 契约测试：`apps/client_flutter/test/app_theme_test.dart` 固化组件主题契约。
- Golden 基线：`apps/client_flutter/test/golden/`（默认跳过，见
  [dart_test.yaml](apps/client_flutter/dart_test.yaml) 说明）。

## 私有资料与合规

公开仓库、公开构建与公开分发**不包含**商业规则正文。私有测试资料存放于被
`.gitignore` 排除的 `private-imports/`，请勿提交或分发；分享任何构建产物前请确认其中
不含规则正文。

## 文档

从 [文档索引](docs/README.md) 开始。要点：

- [系统架构](docs/architecture/system-architecture.md) ·
  [领域模型](docs/architecture/domain-model.md) ·
  [离线数据与同步](docs/architecture/offline-data-and-sync.md)
- [当前执行状态](docs/roadmap/current-execution-status.md)
- [工程规范](docs/engineering/engineering-standards.md) ·
  [本地开发](docs/development/local-setup.md) ·
  [私有资料流水线](docs/development/private-content-pipeline.md)
- [Agent 执行指南](docs/agents/agent-execution-guide.md)

`docs/archive/` 仅用于追溯，不代表当前版本、架构或开发顺序。
