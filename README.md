# OhMyDungeon

开源、离线优先、可自托管的 D&D 跑团辅助工具。客户端使用 Flutter 与 Material 3，服务端
使用 NestJS、PostgreSQL 和 Prisma。

## 当前状态

项目统一处于 `0.1` 开发线。客户端离线优先：角色、资料库、设置和 Markdown 镜像
无需服务器即可使用；服务器用于账号、可选 Personal Vault 同步和多人战役协作。

战役是类似群聊的长期跑团工作区，包含主聊、私聊、小群、角色、成员、档案和共享
资料。玩家将本地 Character 发布并绑定到战役，DM 可以管理战役中的全部 Character。
Room、Session 和 Actor 已退出当前产品模型，仅可能出现在兼容迁移或历史档案中。

当前已经完成：

- 每个服务器账号独立的本地私人工作区，未登录用户使用 local 工作区；
- 服务器稳定实例身份、用户备注、自动登录和断网账号恢复；
- 本地 Character、战役发布/绑定、DM 管理和结构化事件审计；
- 战役主聊、私聊、小群、未读刷新、档案和增量同步；
- 本地内容包、战役私有条目、Wiki 阅读和规则驱动角色创建；
- Character Markdown v2 导入导出、原生自动镜像和外部变更确认；
- 结构化怪物模板、物品、状态、资源及未来 Agent 查询/操作契约；
- 自托管部署、数据库迁移、备份和恢复。

当前不包含战斗系统或 AI Agent 运行时。相关底层数据和业务接口为未来接入预留，但
不会在 UI 中暴露未完成入口。

完整状态见 [当前执行状态](docs/roadmap/current-execution-status.md)。

## 仓库结构

```text
apps/
  client_flutter/      Flutter 多端客户端
  server_nest/         NestJS 服务端
infra/                 自托管部署资源
scripts/               环境、验证和私人构建脚本
docs/                  当前规范与历史档案
private-imports/        本地私人资料，Git 忽略
```

## 环境

- Node.js 22 LTS
- npm 10+
- Flutter stable
- Docker Compose（服务端本地开发和部署）

初始化并验证：

```powershell
npm run bootstrap
npm run check
```

常用命令：

```powershell
npm run dev:server
npm run dev:client
npm run lint:server
npm run analyze:client
npm run test
npm run check
npm run docker:config
```

## 本地运行

启动 PostgreSQL：

```powershell
npm run docker:up
```

启动服务端和客户端：

```powershell
npm run dev:server
npm run dev:client
```

客户端也可完全离线启动；未配置服务器时，战役联机和 Vault 同步不可用，其余本地
能力保持可用。

## 私人测试资料

公开仓库和公开构建不包含商业规则正文。私人测试资料保存在被 `.gitignore` 排除的
`private-imports/`，不得提交或分发。

验证 PHB 私有包：

```powershell
npm run validate:phb-private
```

构建包含 PHB、MM 和 DMG 私人资料的本地 Web 测试版：

```powershell
pwsh -File scripts/build_private_client.ps1 -Target web -BuildArgs --release
```

脚本会临时注入资料，构建结束后恢复公开占位文件。

## Linux 自托管

```bash
git clone <repo-url> ohmydungeon
cd ohmydungeon
./infra/linux-server/start.sh
```

详细步骤见：

- [自托管](docs/deployment/self-hosting.md)
- [数据库迁移](docs/deployment/database-migrations.md)
- [备份与恢复](docs/deployment/backup-restore.md)

## 文档

从 [文档索引](docs/README.md) 开始。`docs/archive/` 中的文件只用于追溯，不代表
当前版本、架构或开发顺序。
