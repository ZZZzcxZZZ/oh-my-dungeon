# D&D Table Tool

开源、自托管优先的 D&D 跑团辅助工具。客户端使用 Flutter + Material 3，服务端使用 NestJS + PostgreSQL + Prisma。

## 当前状态

当前统一为 `0.1` 开发线。此前文档中出现的 `v0.2`、`v0.8`、`v1.0`、`v2.x` 均视为内部迭代记录，不代表项目已经达到可用 MVP 或正式发布。现在的目标是把已有原型收束为一个真正可用的 `0.1`：战役应像 QQ 群聊一样作为跑团主入口，角色卡、资料库、掷骰、检定和 DM 工具都围绕战役聊天室展开。

当前已有可复用基础能力：服务器 profile、账号、战役、Session/聊天原型、掷骰、角色卡、资料库、DM 控场、检定请求、日志、内容包导入导出、部署与备份恢复文档。它们正在重新整合到 `0.1` 的产品主线里：顶层「桌面」入口已收束到战役聊天室的 `+` 工具菜单，不能继续以“多层新建场次”的临时体验作为完成标准。

客户端采用离线优先架构：基于 Drift 的本地数据库作为唯一事实来源，应用无需配置服务器即可启动并使用首页、角色、资料库和设置；服务器是可选协作设施，用于跨设备同步和战役联机。服务器 Profile 迁入 Drift 持久化，旧 SharedPreferences 数据一次性迁移。资料库默认为空，项目不内置任何 SRD/PHB/官方规则正文；用户通过本地导入 JSON 或 `.dndpack` 包添加自己的资料。

登录后可启用 Personal Vault 跨设备同步：个人角色、收藏、笔记和偏好作为通用实体写入 Vault，客户端先推送本地 Outbox 再拉取远端变化，按 cursor 增量合并并处理 409 冲突。本地基础资料包正文与 assets 永不进入 Vault payload，只同步包的 manifest（`id/version/locale/system/contentHash`），商业规则正文不会被上传。未登录时所有本地功能照常可用，同步为可选能力。

战役联机遵循「战役只同步 DM 创建的独立 JSON 条目」原则：DM 在战役作用域内新增的 `CampaignContentEntry`、`CampaignActor`、聊天消息和实时状态通过 cursor 增量同步到成员客户端；玩家本地角色发布后形成完整的 `CampaignActor`，owner/DM 都拥有完整编辑权，所有修改记录在 `CampaignActorAudit`，冲突可见、可回滚。WebSocket 仅广播最新 cursor 与实体类型，完整实体通过 HTTP changes 拉取，避免信任客户端 displayName。

本地数据可在「设置 → 数据管理」导出为 `.dndtable-backup` ZIP（含 `manifest.json`、`database.json` 和 `assets/`），SHA-256 校验后才能恢复；恢复是单事务原子替换，不会触碰 token、战役缓存和同步游标。战役缓存可单独清理，资料索引可重建。

- Monorepo 基础结构
- Flutter 客户端骨架（Material 3 + 首页 / 战役 / 角色 / 资料库 / 设置导航）
- NestJS 服务端骨架
- `/health`
- `/.well-known/dnd-tool-server`
- Prisma schema（User / ServerAdmin / RefreshToken / ServerSetting / VaultEntity / VaultChange / VaultOperation / VaultDevice / Campaign / CampaignSyncState / CampaignActor / CampaignActorAudit / CampaignContentEntry / CampaignChange / CampaignMember / CampaignInvite / CampaignChatMessage / Session / SessionMember / ChatMessage / DiceRoll / JournalEntry / Character / CharacterCampaignBinding / Npc / Encounter / EncounterParticipant / CheckRequest / CheckResponse）
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
- 服务端 campaign API：创建 / 列表 / 详情 / 邀请码 / 加入
- 客户端战役列表与详情页
- 服务端 session API：创建 / 列表 / 详情 / 开始 / 结束 / 聊天 / 掷骰 / 日志
- WebSocket Gateway 实时广播（消息、掷骰、会话更新、战役 cursor 推送）
- 客户端 Session 能力：聊天时间线、掷骰输入、在线成员和 socket.io 实时连接，作为战役聊天室工具继续迁入
- 服务端角色 API：创建 / 编辑 / 自有角色列表 / 角色绑定战役 / 战役角色列表 / 战役角色 HP 调整
- 客户端角色入口：Material 3 底部导航“角色”页、基础创建/编辑、战役绑定和 HP 快捷调整；Player 模式只管理本地角色，DM 模式管理所选战役的 Actor
- 服务端战役协作 API：CampaignActor CRUD 与审计、CampaignContentEntry CRUD（DM 独立 JSON 条目）、CampaignChange cursor 增量推送、CampaignSyncState 游标管理
- 客户端战役缓存：5 张本地 Drift 表缓存当前战役的 Actor / ContentEntry / Backlinks / SyncCursors / SyncConflicts，离线可读，联网时按 cursor 增量更新
- Wiki 同时检索本地资料包和当前战役缓存，同名条目不覆盖，来源 chip 标注「本地」/「战役」
- 战役聊天身份绑定 CampaignActor：消息持久化 `campaignActorId`，不信任客户端 displayName；支持说/做两种格式、头像角色卡、资料引用快照
- 服务端 Personal Vault API：push / changes / devices，按用户隔离、operation ID 幂等、cursor 单调分页、设备撤销与 tombstone
- 客户端 Vault 同步：push → pull → apply → save cursor 固定顺序，409 转为冲突态，网络异常保留 Outbox 并重试
- 客户端本地备份与恢复：`.dndtable-backup` ZIP、SHA-256 校验、单事务原子替换、战役缓存清理、资料索引重建
- 服务端 DM 控场 API：NPC、Encounter、EncounterParticipant、开始/推进/结束遭遇、HP/状态/可见性更新与 JournalEntry 记录
- 客户端战役工具入口：战役聊天室 `+` 菜单提供桌面工具和 DM 控场入口
- 服务端检定请求 API：DM 发起检定请求、玩家响应、重复响应保护、目标可见性过滤、关闭请求、结果写入 ChatMessage / DiceRoll / JournalEntry
- 客户端场次检定入口：Session 详情页显示检定请求、DM 发起、玩家输入修正值响应、DM 查看提交数并关闭请求
- Session Journal 支持按类型和关键词检索
- 自托管部署、升级、备份与恢复文档

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
- [离线数据与同步边界](docs/architecture/offline-data-and-sync.md)
- [工程规范](docs/engineering/engineering-standards.md)
- [本地开发环境](docs/development/local-setup.md)
- [自托管与部署规划](docs/deployment/self-hosting.md)
- [备份与恢复](docs/deployment/backup-restore.md)
- [MVP 版本路线图](docs/roadmap/mvp-roadmap.md)
- [v0.1 工程骨架封版清单](docs/roadmap/v0.1-release-checklist.md)
- [Agent 执行指南](docs/agents/agent-execution-guide.md)
