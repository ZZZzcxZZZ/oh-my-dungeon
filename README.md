# D&D Table Tool

开源、自托管优先的 D&D 跑团辅助工具。客户端使用 Flutter + Material 3，服务端使用 NestJS + PostgreSQL + Prisma。

## 当前状态

当前统一为 `0.1` 开发线。此前文档中出现的 `v0.2`、`v0.8`、`v1.0`、`v2.x` 均视为内部迭代记录，不代表项目已经达到可用 MVP 或正式发布。现在的目标是把已有原型收束为一个真正可用的 `0.1`：战役应像 QQ 群聊一样作为跑团主入口，角色卡、资料库、掷骰、检定和 DM 工具都围绕战役聊天室展开。

当前已有可复用基础能力：服务器 profile、账号、战役聊天室、掷骰、角色卡、资料库、DM 控场、战役日志、内容包导入导出、部署与备份恢复。`Session` 和 `Rooms` 已退出 `0.1` 产品路径：战役本身就是长期群聊与跑团工作区，不再要求逐层创建场次。

项目正在补齐 AI Ready 底座，但当前不包含 AI Agent。角色状态已经结构化为 HP、死亡豁免、资源、状态和物品实例；高频修改通过统一业务接口完成并追加不可变事件。未来 AI 与现有 Flutter UI 将调用同一组查询/操作接口，无需解析界面或聊天文本，也不能绕过权限直接写数据库。

客户端采用离线优先架构：基于 Drift 的本地数据库作为唯一事实来源，应用无需配置服务器即可启动并使用首页、角色、资料库和设置；服务器是可选协作设施，用于跨设备同步和战役联机。服务器 Profile 迁入 Drift 持久化，旧 SharedPreferences 数据一次性迁移。资料库默认为空，项目不内置任何 SRD/PHB/官方规则正文；用户通过本地导入 JSON 或 `.dndpack` 包添加自己的资料。

登录后可启用 Personal Vault 跨设备同步：个人角色、收藏、笔记和偏好作为通用实体写入 Vault，客户端先推送本地 Outbox 再拉取远端变化，按 cursor 增量合并并处理 409 冲突。本地基础资料包正文与 assets 永不进入 Vault payload，只同步包的 manifest（`id/version/locale/system/contentHash`），商业规则正文不会被上传。未登录时所有本地功能照常可用，同步为可选能力。

战役联机遵循「战役只同步 DM 创建的独立 JSON 条目」原则：DM 在战役作用域内新增的 `CampaignContentEntry`、`CampaignActor`、聊天消息和实时状态通过 cursor 增量同步到成员客户端；玩家本地角色发布后形成完整的 `CampaignActor`，owner/DM 都拥有完整编辑权，所有修改记录在 `CampaignActorAudit`，冲突可见、可回滚。WebSocket 仅广播最新 cursor 与实体类型，完整实体通过 HTTP changes 拉取，避免信任客户端 displayName。

本地数据可在「设置 → 数据管理」导出为 `.dndtable-backup` ZIP（含 `manifest.json`、`database.json` 和 `assets/`），SHA-256 校验后才能恢复；恢复是单事务原子替换，不会触碰 token、战役缓存和同步游标。战役缓存可单独清理，资料索引可重建。

- Monorepo 基础结构
- Flutter 客户端骨架（Material 3 + 首页 / 战役 / 角色 / 资料库 / 设置导航）
- NestJS 服务端骨架
- `/health`
- `/.well-known/dnd-tool-server`
- Prisma schema（User / Auth / Vault / Campaign / CampaignActor / CampaignContentEntry / CampaignChange / CampaignChatMessage / JournalEntry / Archive / Encounter 等；Session/CheckRequest 旧表仅作预发布数据兼容）
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
- WebSocket Gateway 实时广播（战役消息和 Actor/资料 cursor 变更）
- 服务端角色 API：创建 / 编辑 / 自有角色列表 / 角色绑定战役 / 战役角色列表 / 战役角色 HP 调整
- 客户端角色入口：Material 3 底部导航“角色”页管理本地角色；战役 Actor 的完整管理入口位于战役中心和聊天统一角色卡，DM 可编辑全部 Actor
- 服务端战役协作 API：CampaignActor CRUD 与审计、CampaignContentEntry CRUD（DM 独立 JSON 条目）、CampaignChange cursor 增量推送、CampaignSyncState 游标管理
- 客户端战役缓存：5 张本地 Drift 表缓存当前战役的 Actor / ContentEntry / Backlinks / SyncCursors / SyncConflicts，离线可读，联网时按 cursor 增量更新
- Wiki 同时检索本地资料包和当前战役缓存，同名条目不覆盖，来源 chip 标注「本地」/「战役」
- 资料包 v2 规则内核与分步角色创建：稳定条目 ID、等级授予、递归选择、类型 / 标签 / 环阶资格、推荐值、装备方案、桌面步骤导航和窄屏进度导航
- 角色卡规则联动：响应式总览、资料库 / 自定义快速编辑、人物资料自动保存、自动规则与手动覆盖分层；法术按环位分组，装备、法术和特性可直接打开本地资料详情，货币优先显示
- 角色资源可由玩家新增、编辑或删除，并为每项设置短休恢复、长休恢复或不自动恢复；角色列表默认紧凑，点小三角展开战斗摘要，点角色主体进入完整角色卡
- DM 模式只可在设置中切换；玩家模式只显示本地角色，DM 模式只显示当前战役的 Actor 管理页与主持人专属工具
- 战役聊天身份绑定 CampaignActor：消息持久化 `campaignActorId`，不信任客户端 displayName；支持说/做两种格式、头像角色卡、资料引用快照
- 战役聊天升级为双页工作区：默认聊天，右滑进入战役信息；owner 可查看和完整编辑玩家 Actor、发起属性 / 豁免 / 技能检定，目标玩家可直接回应并发送关联骰点
- 战役权限以 owner / membership 为准，不读取客户端全局 DM / Player 显示模式；公开邀请码只能加入为玩家，任何已登录用户均可创建自己的战役
- 创建战役提供三步 Material 3 引导；账号支持按服务器独立设置的正式自动登录，access token 失效时使用 refresh token 恢复会话
- 内容包 v2 支持 `subclassOf` 等稳定关系，子职业按所属职业和等级自动进入创建、升级及角色卡投影
- 角色规则动作可从战役聊天 `+` 菜单直接发送；服务端根据 Actor 校验稳定动作 ID，并保存条目来源、公式和 Actor 修订号快照
- DM 战役角色页显示 Actor 运行时状态、规则授予来源账本和服务端编辑审计历史，保留修订冲突对比与重新加载
- 服务端 Personal Vault API：push / changes / devices，按用户隔离、operation ID 幂等、cursor 单调分页、设备撤销与 tombstone
- 客户端 Vault 同步：push → pull → apply → save cursor 固定顺序，409 转为冲突态，网络异常保留 Outbox 并重试
- 客户端本地备份与恢复：`.dndtable-backup` ZIP、SHA-256 校验、单事务原子替换、战役缓存清理、资料索引重建
- 版本化角色状态与事件审计：本地/战役状态隔离、revision 冲突、requestId 幂等、角色/战役事件查询与轻量摘要
- 可读角色 Markdown 交换：中文表格和列表、稳定条目引用、扩展字段，导入时可预览并选择新建、覆盖或合并
- 服务端 DM 控场 API：NPC、Encounter、EncounterParticipant、开始/推进/结束遭遇、HP/状态/可见性更新与 JournalEntry 记录
- 客户端战役工具入口：战役聊天室 `+` 菜单提供桌面工具和 DM 控场入口
- 战役消息支持结构化检定与响应历史、重复响应保护和目标 Actor 校验；DM 快捷检定可直接代掷并写入 roll 消息
- Campaign Journal 支持按类型和关键词检索
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
npm run validate:phb-private
npm run docker:config
```

登录页和已登录账号页均提供「自动登录」开关，按服务器 profile 独立保存且默认开启。开启后客户端保存会话 token，并在 access token 失效时使用 refresh token 自动恢复；关闭会删除持久 token，但不会结束当前运行中的会话。客户端不会保存用户名或密码。

本地存在 `private-imports/phb-2024-v2-bundle.json` 时，可运行 `npm run validate:phb-private`。该命令先执行 Python schema / 引用 / 规则完整性校验，再由 Flutter 的真实 `ContentPackageImporter.previewJson()` 验证客户端可导入性。`private-imports/` 被 `.gitignore` 排除，资料正文不会进入仓库或客户端构建产物。

## 自托管部署草案

### Linux 一键部署（推荐）

```bash
git clone <repo-url> dnd-table-tool
cd dnd-table-tool
./infra/linux-server/start.sh
```

`start.sh` 会自动：复制 `.env.example` 为 `.env`、生成随机 `POSTGRES_PASSWORD` 与 `JWT_SECRET`、探测公网 IP 写入 `PUBLIC_BASE_URL`、构建并启动 Docker 容器、轮询 `/health` 直到就绪。

### 本机开发直连

```bash
cp .env.example .env   # 按需修改 DATABASE_URL 主机名为 localhost
docker compose up -d    # 或 docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

> **安全提示**：直接 `docker compose up` 会保留 `.env.example` 中的 `change-me` 占位密码与密钥，仅适合本机开发；公网部署请走 `start.sh`。

### Docker 配置校验

```bash
docker compose config
```

## 文档索引

- [总体产品规划](docs/product/overall-plan.md)
- [系统架构设计](docs/architecture/system-architecture.md)
- [领域模型设计](docs/architecture/domain-model.md)
- [API 与实时事件边界](docs/architecture/api-realtime-boundary.md)
- [AI Agent 数据与工具接口规范](docs/architecture/ai-agent-data-and-tool-contract.md)
- [AI Ready 基础层验收清单](docs/acceptance/ai-ready-foundation-acceptance.md)
- [离线数据与同步边界](docs/architecture/offline-data-and-sync.md)
- [工程规范](docs/engineering/engineering-standards.md)
- [本地开发环境](docs/development/local-setup.md)
- [自托管与部署规划](docs/deployment/self-hosting.md)
- [备份与恢复](docs/deployment/backup-restore.md)
- [MVP 版本路线图](docs/roadmap/mvp-roadmap.md)
- [v0.1 工程骨架封版清单](docs/roadmap/v0.1-release-checklist.md)
- [Agent 执行指南](docs/agents/agent-execution-guide.md)
