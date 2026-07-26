# 当前执行状态与版本推进计划

## 0.1 AI Ready 结构化底座（2026-07-26）

- 角色运行状态升级为版本化 `CharacterDocument v2`，HP、死亡豁免、资源、状态、物品实例和 namespaced extensions 均为可解析字段；旧 `hp` 字符串和旧 runtime 数据继续兼容读取。
- 服务端新增按本地/战役作用域隔离的 `CharacterState`，以及不可变 `GameEvent`。事件记录操作者、目标、原因、变更前后、requestId 与时间，可按角色或战役分页查询。
- HP、状态、资源和物品高频写操作统一进入 `CharacterOperationsService`，在同一事务内完成权限校验、revision 冲突检查、状态更新和事件追加；UI 与未来 AI 将复用同一业务接口。
- 新增角色完整视图与精简摘要查询。摘要只返回上下文所需的等级、职业、HP、状态和主要装备，不要求未来 AI 扫描整张角色卡或聊天文本。
- Flutter 快捷 HP、状态、资源和物品操作已接入统一 Controller：战役在线操作调用审计 API 并以服务端回包覆盖缓存；个人/离线操作写本地事实源并进入现有 Vault outbox。完整角色编辑器继续保留。
- 角色页支持可读 Markdown 导入导出：中文表格与列表、稳定 HTML 条目引用、YAML 文件身份及扩展字段；导入先展示差异，再选择新建、覆盖或合并。Markdown 是交换格式，不作为数据库。
- 私聊、小群广播按参与者隔离；会话拥有独立阅读游标，归档会话默认隐藏并拒绝继续写入。
- 媒体上传改为严格 Base64 校验与可配置请求体上限；容器使用本地固定版本 Prisma CLI，Compose 不再提供弱数据库/JWT 默认密钥。

验证基线：服务端 27 suites / 348 tests 通过；Flutter 788 tests 通过，2 项需要显式私有资料路径的测试按设计跳过；服务端 lint、Flutter analyze、Nest build、Prisma schema validation 和 `git diff --check` 通过。生产依赖 `npm audit --omit=dev` 为 0；开发依赖仍有 27 个 high 级传递漏洞，未执行破坏性 `audit fix --force`。本机 Docker Desktop Linux daemon 未运行，因此本轮未完成空容器迁移和镜像启动验证。

设计与实施记录见：

- `docs/superpowers/specs/2026-07-26-ai-ready-foundation-design.md`
- `docs/superpowers/plans/2026-07-26-ai-ready-foundation.md`

## 0.1 用户反馈整合与产品加固归档（2026-07-23）

### 本轮归档执行

- **部署验证**：47.115.78.115 部署最新 server（commit `0f1a506`），`/health` 与 `/.well-known/dnd-tool-server` 通过，9 migrations No pending，seed 完成。
- **用户反馈收集**：本轮测试发现 10 项 issue，覆盖内容库、设置页、聊天 composer、临时角色、战役中心、FAB 一致性、档案 wiki、掷骰、角色卡联动、战役卡片展开与旧接口清理。
- **Worktree 归档**：删除 6 个 git worktree（campaign-center / character-experience / content-library / content-wiki / offline-first-plans / settings-theme）；campaign-center worktree 最后一个文档修复 commit `043f7a5` 已 cherry-pick 为 `90ce611`。
- **分支清理**：删除 6 个已合并本地分支，剩余 `main` 与 `offline-first-0.1`，无残留 worktree。
- **Plans 归档**：所有 plans 已归档到 `docs/superpowers/plans/archive/`，活动 plans 目录为空。
- **新计划落地**：[2026-07-23-user-feedback-integration-hardening](../superpowers/plans/2026-07-23-user-feedback-integration-hardening.md) 作为新一轮计划起点，按 Wave 1-5 渐进式推进。
- **Roadmap 修订**：[2026-07-23-integrated-product-hardening-roadmap](2026-07-23-integrated-product-hardening-roadmap.md) 已更新 P0/P1/P2/P6/P7 条款，新增战役卡片展开、FAB 一致性、筛选面板重构、档案时间格式化与编辑者署名等任务。

### 下一波开发顺序（Wave 1-5）

```
Wave 1 (P0+P1) ──┬─> Wave 2 (P2) ──┐
                 │                  │
                 └─> Wave 3 (P4+P5)─┴─> Wave 4 (P6) ──> Wave 5 (P7)
                   [依赖 CampaignEvent]
```

- **Wave 1**：战役中心区块重构 / 说/做滑块动画 / 设置页清理与自定义增强 / 全局 FAB 一致性
- **Wave 2**：资料库子职业查询修复 / 筛选面板 Material 3 重构 / facet 字段扩展
- **Wave 3**：CampaignEvent 事件层 / 组合式骰子编辑器 / 角色卡 CampaignActionSink / DM 快捷操作
- **Wave 4**：档案详情渲染 bug 修复 / 标签筛选 / 时间格式化与编辑者署名 / 创建 UI 重构
- **Wave 5**：主页战役卡片可展开 / 临时身份用后即弃 / 主聊/私聊/小群

### 旧接口清理清单

- **本轮已清理**：6 个 worktree、6 个分支、所有活动 plans 归档
- **Wave 1 待清理**：`HomeDashboardPage` 死代码、`LegacyCharacterImporter` 疑似死代码、过时注释「与 sessions 模块保持一致」
- **Wave 3 待清理**：`GET :id/check-requests` 端点复查下线、`CharacterCampaignBinding` 全套删除（迁移到 CampaignActor）、Prisma 残留 Session/CheckRequest 表
- **Wave 5 待清理**：临时角色持久化路径（`sendDraftActorMessage` + `createTemporaryNpc` + `_showQuickTemporaryForm` + 临时角色面板分区）

详见 [计划文档第五节](../superpowers/plans/2026-07-23-user-feedback-integration-hardening.md#五旧接口清理清单)。

## 0.1 四线并行收束（2026-07-23）

四条并行成果已全部整合进 `offline-first-0.1` 主线：

- **设置重构**：设置持久化修复（失败回滚）、ClientMode 独立 store、统一 `AppTheme` 唯一 Material 3 主题入口、设置页拆为独立 section。
- **资料库收敛**：资料库转为只读查阅平台，补齐子职业、职业特性与装备方案的结构化筛选；修复 `parentClass`/`subclassOf`/`featureOf` 关系型筛选遗漏。
- **角色卡密度**：收紧角色卡信息层级，统一角色业务列表组件；创建/升级向导清晰区分自动授予、必选项与阻断原因。
- **战役中心与档案 Wiki**：战役中心重排为概览/角色/档案三栏；档案升级为结构化 Wiki（正文 blocks、标签、关联、附件引用），创建者或 DM 可编辑；详情自适应 BottomSheet/Dialog。
- 修复聊天历史消息伪造 75% 生命环的问题，历史消息只使用发送时的真实快照。
- 保留「合并连续消息头像」偏好，避免设置合并时回归。

验证：客户端整合回归 140 项通过，服务端战役与档案 78 项通过，`flutter analyze`、服务端 lint、Web release 构建均通过。Web 构建仅保留 `socket_io_common` 的第三方 WASM dry-run 警告。

设计与实施记录见：

- `docs/superpowers/plans/archive/2026-07-23-parallel-settings-theme.md`
- `docs/superpowers/plans/archive/2026-07-23-parallel-content-library.md`
- `docs/superpowers/plans/archive/2026-07-23-parallel-character-experience.md`
- `docs/superpowers/plans/archive/2026-07-23-parallel-campaign-center.md`

整合审查发现与暂缓项详见各计划末尾的「最终报告」与「整合审查发现处置」段。

## 0.1 高频界面减负（2026-07-23）

- 主壳收敛为战役、角色、资料库、设置四个入口；删除无效首页。
- 说/做切换恢复为两个紧凑图标按钮，保留 `68×48` 交互层和独立语义。
- 战役归档角色默认折叠。
- 生命环改为真实 HP 圆弧，历史消息固定使用发送时健康快照。
- Composer 改为头像、统一输入表面、发送键三段布局。
- 连续消息头像合并可在设置中关闭并持久化。
- 待办：战役中心区块间距与层级推迟到 P0 收尾批次。

设计与实施记录见：`docs/superpowers/plans/archive/2026-07-23-high-frequency-ui-simplification.md`

## 0.1 战役与规则全链路加固（2026-07-18）

- 聊天身份链路已收敛：DM 切换旁白后由服务端固定保存「旁白 / DM」快照，客户端使用独立居中系统样式；角色发言继续使用 Actor 身份与头像。
- 头像生命环统一读取最新 Actor 完整角色快照，修复小尺寸头像外圈与图片重叠；未提供有效 HP 时退化为中性外圈，不伪造生命比例。
- 战役内角色入口统一打开完整角色卡：本人可编辑自己的角色，其他玩家只读，战役 owner / manager 可编辑任意 Actor；聊天室头像、战役角色目录和快捷面板复用同一 launcher。
- DM 检定工具改为直接代掷并发送结构化 `roll` 事件，不再发送含义相反的请求；支持普通 / 优势 / 劣势、技能修正和可选 DC。
- 战役概览重排为摘要、统计、邀请码、成员和主持工具，邀请信息提高优先级；玩家看不到主持工具。
- 创建器新增标准数组、27 点购点与 4d6 去最低随机生成；职业结构化豁免、技能候选与背景固定熟练会进入草稿，规则固定项不可被错误取消。
- 资料关系现已持久化到 Drift，数据库 schema 升至 7；子职业、职业特性及 Wiki 链接在导入、重启和角色创建后不再丢失。
- 资料库法术检索增加环位、学派、职业 facet；字段内多选为 OR、字段间为 AND。角色创建、角色卡和聊天室资料引用统一使用 Material 浮动详情。
- 当前私人构建实际聚合 1106 条：12 职业、48 子职业、414 职业特性、391 法术、62 专长、10 种族、16 背景、51 装备、102 物品。Python 校验为 0 重复、0 schema 错误、0 断链、0 关系错误、0 规则引用错误；Flutter 真实导入与 12 职业子职解析通过。
- 私人测试构建通过 `scripts/build_private_client.ps1` 临时注入资料并在 `finally` 恢复公开占位；公开源码和普通构建仍不包含商业规则正文。
- 验证：服务端 334 项测试通过；Flutter 全量 520 项通过，2 项无私有路径时按设计跳过，另以真实路径运行的 2 项私有包测试通过；`flutter analyze` 和服务端 lint 零问题；Docker Compose 配置与 `git diff --check` 通过；公开及私人 Web release 均构建成功。浏览器自动截图验收因本机浏览器控制沙箱初始化失败未执行，但本地静态站点返回 HTTP 200，宽窄屏 Widget 测试已覆盖本轮界面。

设计与实施记录见：

- `docs/superpowers/specs/2026-07-18-campaign-rules-integration-hardening-design.md`
- `docs/superpowers/plans/2026-07-18-campaign-rules-integration-hardening.md`


## 0.1 私有资料验收与主流程收敛（2026-07-16）

- PHB 2024 私有 v2 包已重新提取并通过独立验收：共 875 条，包含 12 职业、58 子职业、173 职业特性、391 法术、62 专长、10 种族、16 背景、51 装备和 102 物品；重复 ID、断链、关系错误和规则引用错误均为 0。
- 12 个职业均具备 1–20 级 progression，并在 3 级包含子职业选择。术士 20 级「奥术化神」通过名称别名稳定关联到「奥术登神」条目；原书表格中的横线和「子职特性」占位不再制造人工复核噪声。
- 魔契师契约魔法已按 1–20 级生成独立法术位资源，记录法术位数量、最高环阶和 `shortRest` 恢复规则；角色规则投影会保留 grant 中的恢复元数据。
- 新增 `npm run validate:phb-private`：先运行 Python 完整性校验，再由 Flutter 真实 `ContentPackageImporter.previewJson()` 验证客户端导入。私有包继续位于 `.gitignore` 排除的 `private-imports/`。
- 客户端不再声明或自动加载任何 `assets/private/` 资料；资料库首次安装为空，所有本地资料均从「设置 → 资料包」显式导入。
- 战役成员面板统一以服务端 membership 为身份来源、以 `CampaignActor` 为角色状态来源；移除了 `CharacterController` 中永远返回空或失败的旧战役绑定/HP 调整存根，以及角色页失效的「绑定战役」入口。
- `MainShell` 不再实例化旧 `SessionController`；服务器管理页移除了房间、旧角色 API、检定、遭遇和 Session 五套未使用客户端依赖，并删除重复的模式设置入口。旧源码暂留为日志和遭遇迁移素材，但不再进入主导航或应用依赖图。
- 已删除通过编译参数注入账号密码的 Debug 登录。正式自动登录按服务器 profile 独立设置并默认开启，access token 失效时使用 refresh token 恢复；关闭会清除持久 token，但保留当前内存会话，客户端不保存用户名或密码。
- 最新封版验证：`npm run doctor` 全绿，服务端 306 项测试通过，Flutter 362 项测试通过、私有包测试在未提供路径时 1 项按设计跳过，`flutter analyze` 无问题，Docker Compose 配置有效；`flutter build web --release --pwa-strategy=none` 成功。

## 0.1 战役与角色联动收口（2026-07-16）

- 战役权限不再读取客户端全局 DM / Player 模式：任何已登录用户都可创建战役并成为 owner，公开邀请码固定加入为玩家；只有战役 owner / manager 可以发送系统事件、检定请求和使用战役管理工具。
- 战役消息支持 `say / action / roll / system / checkRequest` 五类结构化事件，动作消息显示角色来源，系统消息加粗，检定请求与骰点使用独立 Material 3 信息面。
- 战役页面升级为双页工作区：默认进入聊天室，右滑或点击顶部信息按钮进入战役信息页；信息页集中展示简介、成员、战役角色、共享资料与 owner 管理入口。
- DM 可从战役角色打开完整编辑页，选择属性、豁免或技能并设置普通 / 优势 / 劣势和可选 DC；目标玩家可直接在检定消息上掷骰，骰点事件保留请求 ID。
- 创建战役改为三步 Material 3 引导：基本信息、规则与资料、确认创建；资料包管理在创建成功后继续处理，不阻塞战役创建。
- 内容包 v2 新增稳定 `relations`：支持 `subclassOf / featureOf / spellOf / requires / replaces / related`；子职业只会出现在所属职业的选择中，并递归参与创建、升级和角色卡规则投影。
- 账号恢复统一使用正式认证链路：启动时先验证 access token，401 时刷新 token 后重新获取用户；服务端拒绝 refresh token 才清除本地会话，临时网络错误不会删除持久凭据。
- 修复 v0.1 初始 Prisma 迁移被压成单行注释的问题；空开发库已从头应用 6 份迁移，服务端 Docker 镜像可正常执行 `prisma migrate deploy` 并启动。
- 验证：`npm run doctor` 全绿；服务端 306 项测试通过，Flutter 358 项测试通过，`flutter analyze` 无问题，Docker Compose 配置有效。

## 0.1 角色卡信息架构统一（2026-07-16）

- 角色详情调整为「总览 / 属性 / 动作 / 法术 / 装备 / 资源 / 特性 / 角色资料」八个稳定区域；职业与自定义次数资源从总览移入独立资源页。
- 总览状态改为响应式 Material 3 信息板，分别呈现 HP、临时 HP、灵感和死亡豁免，并保留任意数值伤害/治疗、状态效果和短休/长休操作。
- 角色详情页统一合并本地运行时状态后再调用持久化回调，HP、状态、法术位和职业资源在标签切换后保持一致。
- 资源页按响应式网格展示剩余次数、已用次数、恢复规则和进度，并保留新增、编辑、删除、消耗和恢复能力。
- 新增共享 `ContentEntryReader`，角色卡浮动详情与资料库详情共用正文渲染；条目摘要与正文首段相同时只显示一次。
- 设置中的默认角色卡标签新增「资源」，旧 `status` 自动映射到总览，旧 `details` / `notes` 自动映射到角色资料。
- 本节验证结果已被上方最新整体验证覆盖。

设计与实施记录见：

- `docs/superpowers/specs/2026-07-16-character-sheet-unification-design.md`
- `docs/superpowers/plans/2026-07-16-character-sheet-unification.md`

## 0.1 角色体验重构（2026-07-16）

- 角色规则结果与玩家手动修改已分层：自动授予继续写入 `resolvedGrants/contentRefs`，手动特性、法术、动作及隐藏项写入 `data.manualOverrides`，重新投影和升级不会覆盖玩家修改。
- 新增独立的下一级升级向导：固定授予自动显示，只呈现当前等级必须完成的选择，缺项时禁止确认，完成后原子更新角色并保留装备、货币、运行时状态、人物资料和私人笔记。
- 角色详情收束为「总览 / 动作 / 法术 / 装备 / 特性 / 角色资料」六区；HP、临时 HP、状态、死亡豁免、职业资源和休息进入总览。
- 角色卡支持离线快速编辑：资料库或自定义特性、法术添加 / 删除 / 准备、装备添加 / 数量 / 装备 / 同调 / 删除、自定义动作，以及外貌、个性、理想、牵绊、缺点、背景故事、语言和私人笔记。
- 角色列表改为紧凑的可展开角色卡：点小三角展开 HP 进度、AC、先攻、被动察觉、状态、主要职业资源和快捷操作；点角色主体进入完整详情，移除了冗余的布局切换偏好。
- 角色详情总览改为响应式身份区和固定统计格；法术按戏法 / 环位分组，装备页提高货币优先级并区分已装备与背包，装备、法术和特性可打开本地资料详情。
- 职业与自定义资源均可在角色总览新增、编辑和删除；每项资源记录最大次数与短休恢复、长休恢复或不自动恢复，休息只恢复适用资源。
- DM / 玩家模式切换仅保留在设置页；角色页不再提供临时切换按钮，DM 模式隐藏本地玩家角色并显示战役 Actor 管理。
- 标准创建顺序调整为「职业 / 背景 / 物种 / 属性 / 熟练 / 装备 / 法术 / 详情 / 审核」，没有候选项或规则选择的装备 / 法术步骤会自动隐藏，职业等级授予与规则选择继续由资料库 v2 规则驱动。
- 验证：`flutter analyze` 无问题，Flutter 全量测试 345 通过，`flutter build web --release` 成功，`http://127.0.0.1:5173/` 返回 200 且桌面 / 窄屏 Flutter 视图挂载无控制台错误。

更新时间：2026-07-16

## 0.1 规则驱动角色自动化（2026-07-15）

- v2 choice 已支持类型、标签、最高条目等级、稳定 ID 白名单、推荐项和创建步骤过滤。
- 引导创建器会把职业产生的法术与装备选择放到对应页面，自动应用推荐值，并禁止通过自由选择绕过法表或等级资格。
- `equipmentBundle` 可递归授予实际物品；角色草稿只保存规则引擎认可的选择，非法旧 ID 不会进入角色卡。
- 升级队列可在原地完成新等级解锁的特性、专长和法术选择，完成前不能应用升级。
- v2 职业可声明施法属性与法术位资源；角色卡优先使用资料派生数据，保留无规则旧资料的兼容回退。

更新时间：2026-07-15

## 版本结论

项目当前统一为 `0.1` 开发线，尚未达到可用 MVP。此前文档中出现的 `v0.2`、`v0.4`、`v0.8`、`v1.x`、`v2.x` 只作为内部迭代记录保留，不代表对外版本，也不代表功能已经封版。

后续开发不再新增旧式小版本号。所有计划、测试和文档都归入 `0.1`，可使用 `0.1-chat-01`、`0.1-content-02` 这类内部任务名。

## 0.1 产品主线

`0.1` 的目标是把已有原型收束成能开团使用的开源工具：

- 战役是主入口，像 QQ 群聊一样陈列在客户端中。
- 点击战役直接进入聊天室，不要求先创建场次、开始场次或进入另一层桌面。
- 玩家以绑定角色的头像、名字和简要状态发言。
- 输入区分为「说」和「做」两种模式：说话以聊天气泡显示，动作用斜体事件显示。
- 掷骰、角色卡、资料库、检定请求、跑团日志和 DM 控场都从战役聊天室的 `+` 入口打开。
- 资料库必须提供 GUI 新增、导入、启用和查询能力；JSON 只保留为高级入口。
- 开源仓库不内置任何规则正文。资料库默认为空，用户通过本地导入 v1 JSON 或 `.dndpack` 包添加自己的资料；商业 PDF 提取只能保存在用户本地，不进入公开仓库。战役作用域的远端内容由第四份计划单独处理。

## 已有可复用能力

这些能力已经存在于代码中，但都视为 `0.1` 内部能力，而不是已发布版本：

- Monorepo、Flutter 客户端、NestJS 服务端、PostgreSQL、Prisma、Docker Compose 和 CI。
- 服务器 profile 管理、服务器发现、Player/DM 模式切换。
- 账号系统：注册、登录、刷新、退出、当前用户、注册开关。
- 战役系统：创建战役、邀请码、加入战役、成员权限。
- Session / 聊天 / 掷骰 / 日志模型和实时广播能力。
- 角色卡：创建、编辑、角色绑定战役、战役角色状态查看和 HP 调整。
- 内容库：内容包校验、导入、导出、条目查询、战役启用内容包、战役可用资料查询。
- DM 控场：NPC、遭遇、参战者、先攻推进、HP 和状态更新。
- 检定请求：DM 发起、玩家响应、结果写入聊天和日志。
- 设置中心：主题、密度、规则集、角色卡偏好和跑团日志偏好。

## 当前 0.1 已推进

- 客户端已建立离线优先基础：基于 Drift 的跨平台本地数据库（Native + Web WASM），应用无需配置服务器即可启动并使用首页、角色、资料库和设置；服务器 Profile 迁入 Drift 持久化，旧 SharedPreferences 数据一次性迁移。
- 客户端已建立同步基础设施：Outbox、cursor 和 SyncStatusController 已就位，后续业务同步在此基础上扩展。
- 设置页已新增同步状态条目和离线服务器管理入口；未连接服务器时显示「尚未连接服务器」，可通过「管理服务器」按钮进入 Profile 管理页。
- 客户端导航已收束为「首页 / 战役 / 角色 / 资料库 / 设置」。
- 顶层「桌面」入口不再作为独立大页面暴露。
- 战役列表以聊天室入口为核心。
- 战役聊天室已有角色身份条、成员列表、说/做输入、加号工具菜单、掷骰、角色卡和资料库入口。
- 战役页创建权限已与客户端显示模式解耦：邀请码加入保留在顶部小入口，任何已登录用户都可创建战役并自动成为该战役 owner。
- 战役列表已开始按群聊入口呈现绑定角色：条目前方显示角色头像 / 首字母，副标题显示 `角色名 · HP 当前/最大 · AC` 状态摘要，点击条目直接进入战役聊天室。
- 战役聊天室 `+` 菜单按战役身份收束：普通成员不显示 DM 控场入口，战役 owner / manager 显示遭遇和成员状态入口。
- 聊天消息头已开始按绑定角色显示简要状态，例如 `角色名 · HP 当前/最大 · AC`；若角色有状态条件，会继续显示 `中毒, 倒地` 这类摘要。后续继续扩展私聊可见性和系统事件。
- 加号菜单已补入「桌面工具」和「DM 控场」入口，后续在这里继续接入检定、日志、遭遇和地图。
- 本地资料库现在默认为空；用户通过本地导入 v1/v2 JSON 或 `.dndpack` 包添加资料，导入有事务、大小和路径安全校验；v2 条目可声明角色规则，格式见 `docs/content/content-package-format-v2.md`。
- 服务端 `seed.ts` 不再创建任何系统内容包或 SRD 资料正文，只初始化服务器设置；公开仓库不再内置任何 SRD/PHB 官方规则正文。
- 资料库 UI 已重建为独立 Wiki：全文检索、类型 / 包 / 语言 / 收藏筛选、独立详情路由、包内链接与反向链接、收藏、笔记和职业等级视图，宽屏双栏窄屏单栏。
- 资料包管理位于「设置 → 资料包」：导入预览、启用 / 停用、升级、导出、删除，删除前显示受影响收藏和笔记数量。
- 战役资料库仍保留服务端战役作用域能力：条目关联链接、按用户隔离的收藏、仅看收藏筛选，以及成员范围详情 API；其与本地资料库的统一同步留给第四份计划。
- 角色创建会先选择通用资料或战役资料；选择战役后，职业、种族、背景、法术和装备候选项仅来自该战役启用的内容。
- 设置里的「默认创建方式」已接入角色创建入口：从角色页新建角色时会按偏好直接进入快速创建或标准创建，保留无偏好时的创建方式选择页。
- 标准创建已开始使用资料库内容：角色页登录后加载全局资料库条目，新建角色时会优先用 `class` / `species` / `background` 条目生成职业、物种和背景选项；也可以从 `spell`、`equipment`、`item` 条目多选初始法术和装备，并写入角色 `data.contentRefs` 与初始 inventory；职业步骤已支持 1-20 级等级选择，并预览 HP、熟练加值、法术位和职业资源；属性步骤已支持 6 项能力值编辑，熟练步骤已支持技能熟练选择，职业资源会按职业 / 等级写入角色数据，并会重新计算 HP、AC 和先攻；没有资料库内容时保留内置兜底选项。
- 角色状态页已支持职业资源运行时追踪：目前内置战士第二气息 / 动作如潮、野蛮人狂暴，旧角色若缺少 `data.classResources` 会按职业和等级自动推导；消耗 / 恢复会写入 `data.runtime.classResourcesUsed`。
- 个人角色已迁移为本地优先（Drift）：无需登录即可创建、编辑和运行角色卡，`CharacterRepository` 只操作本地数据库，服务器不再作为个人角色的前置门禁。
- 角色内容引用现在保存快照：引用资料条目时会同时保存稳定键与必要快照，本地资料包被删除或缺失后角色卡仍保持完整可用。
- 服务端 Personal Vault 同步 API 已就位（`push/changes/devices`）：按用户隔离、operation ID 幂等、cursor 单调分页、设备撤销与 tombstone 保留，冲突返回 HTTP 409 与当前 revision。
- 客户端 Vault 同步服务已实现 push → pull → apply → save cursor 的固定顺序：先推送本地 Outbox 再分页拉取远端变化，409 转为冲突态，网络异常保留 Outbox 并增加重试计数。
- 个人实体（角色、收藏、笔记、偏好、资料包 manifest）在本地写入时原子入队 Vault Outbox；资料包 manifest 只含 `id/version/locale/system/contentHash`，正文与 assets 永不上传。
- 旧服务器角色可一次性安全导入：首次登录旧服务器时拉取远端角色，本地不存在的直接导入，ID 相同且内容不同则复制为带新本地 UUID 的副本并追加「（服务器导入）」，成功后写服务器+用户 marker，任何失败都不写 marker。
- 设置页已暴露个人同步控制：登录后显示 pending 数量、立即同步、后台同步开关、错误详情（可复制，不含 token 或实体全文）和设备列表 / 撤销；未登录时明确提示同步可选，不禁用本地角色与资料。
- 战役协作链路已就位：服务端 `CampaignActor` / `CampaignContentEntry` / `CampaignChange` / `CampaignActorAudit` 模型与 API 完成；DM 可在战役作用域内创建独立 JSON 条目，玩家本地角色发布后形成完整 `CampaignActor`，owner/DM 都有完整编辑权，所有修改有审计、修订号和冲突可见。
- 客户端战役缓存已落地：5 张本地 Drift 表（`CampaignActorsCache` / `CampaignActorBacklinks` / `CampaignContentCache` / `CampaignSyncCursors` / `CharacterSyncConflicts`）缓存当前战役的 Actor、内容条目、反向链接和同步游标，离线可读，联网时按 cursor 增量更新；WebSocket 仅广播 cursor 与 entityType，完整实体通过 HTTP changes 拉取。
- Wiki 已合并本地资料包与当前战役缓存：同名条目不覆盖，来源 chip 标注「本地」/「战役」，战役缓存缺失时自动回退到本地包。
- 战役聊天身份已绑定 `CampaignActor`：消息持久化 `campaignActorId`，不再信任客户端 displayName；支持说/做两种格式、头像角色卡、资料引用快照和离线历史。
- 本地备份与恢复已就位：`设置 → 数据管理` 提供 `.dndtable-backup` ZIP 导出（`manifest.json` + `database.json` + `assets/`）、SHA-256 校验、单事务原子恢复、战役缓存清理和资料索引重建，所有破坏性操作都需二次确认。
- 旧服务端资料模块已下线：`apps/server_nest/src/modules/content/` 整个目录删除，对应 Prisma 模型（`ContentPackage` / `ContentItem` / `ContentItemLink` / `UserContentFavorite` / `CampaignContentPackage` / `ContentOverride`）已从 schema 移除，迁移 SQL 把存量战役作用域内容转入 `CampaignContentEntry` 并记录初始 `CampaignChange`，旧全局/用户/战役内容包 API 返回 404。`CharacterCampaignBinding` 暂时保留以兼容旧角色端点。
- 客户端旧 `ContentApiClient` / `ContentController` / `ContentItem` 链路及测试已删除；聊天室、角色创建和 Wiki 统一读取离线 `ContentRepository`，战役仅同步 DM 创建的私有 JSON 条目。
- 资料包 v2 规则内核已落地：稳定条目 ID、等级进度、递归规则选择、授予账本、运行时状态模型，以及特性、熟练、法术、装备、资源、动作、抗性、速度、AC/HP/属性和说明授予。
- 标准角色创建已重组为 Material 3 分步向导：桌面端使用步骤导航栏、中间任务区和固定摘要，窄屏使用步骤选择器、进度条与底部操作；资料选项可直接打开 Wiki，职业和起源步骤会预览自动授予，审核页阻止缺项提交。
- 角色卡特性页会显示规则授予及来源条目/等级，动作页会显示资料规则生成的动作；角色继续保存稳定资料快照，运行时状态与派生账本分离。
- 已有角色修改等级时会生成升级队列：对比新旧规则账本、列出新增授予，并在存在待选规则或缺失条目时阻止应用；应用后重算 HP / AC / 速度 / 先攻 / 熟练与动作，保留临时 HP 等运行时状态。
- 战役聊天室 `+` 菜单会在角色已绑定 Actor 时显示资料规则生成的角色动作；客户端只提交稳定 `actionId`，服务端从 Actor 角色快照派生并保存动作名、资料条目、公式和 Actor 修订号，历史消息不会随角色升级漂移。
- DM 角色页已接入 Actor Audit API：同页显示临时 HP、条件和职业资源等运行时状态，按来源条目/等级展开规则授予账本，并列出每次修改的基线修订、结果修订、变更路径和操作人；成功编辑后自动刷新历史。

## 当前缺口

- 战役列表还需要进一步像群聊列表：最近消息、未读、成员头像叠放；绑定角色头像和状态摘要已有第一版。
- 聊天消息还需要系统事件、私聊 / DM 可见性和更完整的骰点卡片；角色 HP/AC/状态条件旁显已有第一版。
- 标准创建已有 2024 顺序的分步导航、完成度、固定摘要、规则选择、授予预览与独立升级向导；法术准备数量上限已按施法属性修正 + 等级派生并阻止超额选择，装备购买预算仍待后续增强。
- 检定请求已接入战役上下文；「桌面工具」仍需继续迁入日志和地图。
- 「DM 控场」目前是入口壳，遭遇面板需要从旧桌面页迁入战役工具。
- 本地资料库已有导入预览、检索、筛选、收藏、笔记、独立详情路由、条目编辑、复制条目和批量导入确认向导；后续可继续扩展字段校验与更多类型的结构化字段可视化。
- 资料库详情页已按 Material 3 规范配色，类型 chips 已统一，但可继续扩展更多类型的结构化字段可视化（如怪物的挑战等级、状态的持续时间）。
- 商业规则正文（如 PHB 2024）不能提交进公开仓库，也不进入 seed 或分发产物；用户若需要完整正文，只能保存在用户本地或自托管服务器，并以本地 JSON / `.dndpack` 形式导入。

## 0.1 下一步顺序

1. 完成战役聊天室信息架构：群聊式列表、最近消息、未读、成员头像叠放。
2. 把日志从旧 Session 详情迁入战役 `+` 工具，并补齐检定请求历史与重复响应状态。
3. ✅ 把遭遇控场从旧桌面页迁入「DM 控场」底部页 — `EncounterPanelPage` widget 已创建, 接入 `EncounterController`, DM 控场 sheet 提供"遭遇控场"入口跳转, 支持参与者 HP 调整 / 推进回合 / 结束遭遇 / 空态新建遭遇.
4. ✅ 推进标准创建向导：法术准备上限 — `StructuredClassRules.preparedSpellLimit` 按施法属性修正 + 等级计算可准备法术数，向导第 6 步通过 `_MultiChoiceSection.maximum` 阻止超额选择并实时显示 `已选/上限` 计数；装备购买预算仍为后续增强项。
5. ✅ 增强本地资料库 GUI：编辑条目、复制条目、批量导入确认向导 — `ContentDetailPage` 支持就地编辑条目名称/摘要，并基于现有条目复制副本；新增 `BatchImportWizardDialog` 通过 `ContentFilePicker.pickMultiple()` 并行生成多份预览报告，支持勾选/全选/取消全选后批量导入；`ContentPackageSettingsPage` 在「从文件导入」下新增「批量导入」入口。
6. ✅ 旧 `rooms`、`TableTabPage`、Session 和独立 CheckRequests 源码清理 — 服务端 `RoomsModule` / `SessionsModule` / `SessionsGateway` / `CheckRequestsModule` 已删除；检定历史收敛为 CampaignChatMessage 聚合，旧 Session 检定路由固定返回 404。Prisma 旧表暂留给预发布数据迁移，不得作为新功能依赖。
7. ✅ DM Actor 编辑与玩家本地角色的双向同步 — 切片 A (publishCharacter baseRevision + socket changeStream + 409 冲突对话框) 与切片 B (CharacterSyncConflictRepository + BannerController + ResolutionPage) 已完成.

## 2026-07-22 总体审查修复

- 本地资料条目编辑/复制不再把完整正文送入 Vault；复制条目保留结构化 rules。
- 本地角色 revision 每次写入递增；发布成功建立新 backlink 基线，避免自冲突。
- Actor 无冲突回写覆盖完整角色构建字段；冲突保存远端 actor revision，并能真正应用已捕获的远端快照。
- 输入栏角色卡优先走统一 CampaignActor launcher，恢复玩家本人和 DM 的正确编辑权限。
- 检定响应必须使用请求目标 Actor；关键消息与 JournalEntry 同事务写入，提交后再广播。
- 移除已孤立的 Session CheckRequests HTTP 模块，并同步架构、API、领域模型和 Agent 入口文档。
- 最终验收：`npm run doctor` 全绿，服务端 18 套件 / 271 项测试通过，Flutter 567 项通过、2 项私有包路径测试按设计跳过；随后 `npm run validate:phb-private` 以真实 1106 条资料包补跑 2 项导入与子职关联测试并通过；`flutter build web --release` 成功，`git diff --check` 通过。

## 2026-07-22 战役聊天壳层收口

- 顶栏收束为返回、战役名称和战役中心；聊天记录搜索统一留在战役中心，不再在聊天室维护重复搜索、高亮和跳转状态。
- 消息时间线按群聊习惯区分本人靠右、他人靠左，连续同身份消息折叠重复姓名，旁白、系统事件和检定卡保持居中且限制阅读宽度。
- 时间线默认定位到最新消息，发送成功后回到最新位置；360x800、390x844 和 1280x720 均有长身份与长内容回归测试。
- 输入栏拆为独立 Material 3 Composer：32px 头像配 48px 触控目标、紧凑图标式说/做切换、可伸缩文本框、发送状态和临时身份提示；失败发送保留草稿。
- 头像工具面板保留既有视觉，将身份、高频角色操作和战役工具分层；客户端 DM/Player 偏好不参与战役权限判断。
- 删除聊天页旧内联输入栏、旧搜索面板和重复消息布局，聊天页面只负责生命周期、加载态与业务动作协调。
- 验收：聊天相关 69 项测试通过；Flutter 全量 583 项通过、2 项私有路径测试按设计跳过；`flutter analyze` 零问题；Web release 构建成功；`npm run doctor` 全绿，服务端 18 套件 / 271 项测试通过，Docker Compose 配置有效。

## 2026-07-22 角色呈现壳层重构

- 角色卡新增独立 `CharacterSheetShell`：手机保留可滚动标签，900px 以上使用 Material 3 NavigationRail，八个业务面板和初始页面 ID 保持不变。
- 标准创建新增独立 `CharacterBuilderShell`：手机步骤选择、桌面侧栏、编辑区、摘要列和底部动作插槽脱离规则状态，职业、子职、装备、法术和规则选择逻辑未改动。
- 删除角色业务页面中的重复响应式 Scaffold、NavigationRail 和手机步骤选择器实现，为后续角色卡内容密度优化建立稳定边界。
- 验收：角色壳层与角色页面 49 项测试通过；Flutter 全量 587 项通过、2 项私有路径测试按设计跳过；`flutter analyze` 零问题；Web release 构建成功；`npm run doctor` 全绿，服务端 18 套件 / 271 项测试通过。

## 验证规则

- 客户端页面改动：先写 widget test，看到失败，再实现，再运行目标测试。
- 客户端收口：运行 `flutter analyze`、`flutter test`、`flutter build web --release`。
- 服务端 API 改动：运行对应 service / e2e 测试和 `npm run lint:server`。
- 跨端契约或版本闸门：运行 `npm run doctor`。
