# 当前执行状态

**版本：** 0.1
**更新时间：** 2026-09-10
**状态：** 0.1 开发线；设计系统收敛完成，服务端已可自托管部署

## 当前产品边界

- Flutter 客户端离线优先；本地角色、资料包、设置和 Markdown 镜像不依赖服务器。
- NestJS 服务端负责账号、Personal Vault 和战役协作。
- 战役是类似群聊的长期跑团工作区，不要求创建 Room 或 Session。
- 统一领域名称为 Character；Actor 只允许出现在兼容迁移和历史档案中。
- 当前不开发战斗系统和 AI Agent 运行时。
- 公开仓库和公开构建不包含商业规则正文。

## 已完成

- 产品统一命名为 OhMyDungeon，并接入 Android、Web、Windows 与应用内图标；
- 服务器实例身份、客户端备注和每账号私人工作区；
- 账号切换数据隔离、离线账号恢复和旧数据迁移；
- 本地 Character、战役 Character 发布、玩家绑定和 DM 管理权限；
- 战役主聊、私聊、小群、未读状态与增量刷新；
- 档案创建者权限、DM 管理权限和统一资料阅读界面；
- Character Markdown v2、原生自动镜像、外部修改差异确认；
- 结构化怪物分类与动作投影；
- AI Ready 查询、操作、事件和数据结构规范；
- Actor 持久化名称向 Character 的无损数据库迁移；
- Material 3 设计系统契约（`DESIGN.md`）与全量 UI 审查；
- 自托管 Docker 部署（含离线 Prisma 引擎与部署包脚本）。

## 验收基线（2026-09-10 实测）

- 客户端：`flutter analyze` 0 问题；`flutter test` 871 项通过、5 项跳过
  （3 项 golden 默认跳过 + 2 项私有路径测试按设计跳过）；
- 服务端：356 项通过、8 项跳过，26/27 个套件通过；
- 脚本层：`npm run test:scripts` 27 项通过（打包、预览服务、私有提取器）；
- `DESIGN.md`：官方 `@google/design.md` lint 通过（0 error / 0 warning）；
- 私有测试构建：PHB、MM、DMG 私人资料包注入后构建成功，构建结束自动恢复
  `bundled_content.json` 为 `{}`。

## 2026-07-29 仓库整理

- 100 份旧路线、Agent prompt、交接报告、计划和规格已移入 `docs/archive/`；
- 当前文档统一由 `docs/README.md` 索引，非归档 Markdown 本地链接零断链；
- 删除项目级 Pub 缓存、日志、旧分发产物、工具状态和旧顶层 PHB bundle；
- 删除无消费者的客户端 encounters 页面、控制器、API 客户端及孤立测试；
- 删除没有代码或消费者的 `packages/` 占位目录；
- `private-imports/` 与私人 release Web 测试版已保留并重新验证。

## 2026-08-03 OhMyDungeon 测试候选版

- 客户端、服务端、Web/PWA、Android、Windows 与发布脚本统一使用 OhMyDungeon 品牌；
- Android 应用 ID 固定为 `app.ohmydungeon.client`，支持独立 release 签名配置；
- 新备份使用 `.ohmydungeon-backup`，旧 `.openquest-backup` 与 `.dndtable-backup` 仍可恢复；
- 合并客户端 API 实例并删除无消费者的旧 Character HTTP CRUD；
- 角色操作与战役事件补齐并发幂等保护、重放边界和查询索引；
- 修复 Docker `-d` 参数被 PowerShell 吞掉导致启动命令附着日志的问题；
- 公共 APK、私人资料 APK、Linux 服务端包与私人 Web 预览均已构建；
- 服务端生产依赖审计为 0 漏洞，桌面与移动 Web 预览无溢出和控制台错误。

## 2026-09-10 设计系统收敛与自托管部署

**设计系统**

- 新增 `DESIGN.md`（颜色/排版/圆角/间距/组件 token + 八段规范），并接入
  `npm run lint:design` 与 CI `design` job；
- 全量 UI 审查（约 430 个元素）记录于 `docs/design/design-audit.md`，并完成：
  - 选中态 chip 文字角色（`secondaryLabelStyle`）、对话框 elevation、SearchBar 主题；
  - 彩色底 `on-*` 文字角色、`outline` 文字对比度（AA）；
  - 35 处输入框边框覆盖清理、间距/圆角归位、对话框尺寸 token 化；
  - 破坏性操作统一 error 角色、共享 `EmptyState`、语义排版 token
    （`AppTextStyles`）、触达尺寸 ≥ 48dp；
- 新增主题契约回归测试（`app_theme_test.dart`）与 3 个 golden 基线
  （`test/golden/`，默认跳过，CI `golden` job 在 Linux 校验）。

**自托管部署**

- 服务端在自托管主机上以 Docker Compose 运行（PostgreSQL + 服务端），
  `/health` 与 `/.well-known/dnd-tool-server` 验证通过；
- 修复部署链三个缺陷：部署包缺失离线 Prisma 引擎、引擎可执行位丢失、
  npm registry 不可达（Dockerfile 支持镜像参数）；
- 打包脚本在 `engines/` 缺失时提前失败；脚本文件统一 UTF-8 BOM，
  避免 PowerShell 5.1 按 ANSI 解析中文注释。

**客户端发行物**

- 私有资料 APK 构建成功（含 PHB/MM/DMG，约 79 MB）；
- 新增 `BundledDefaultServerSeeder`：仅在
  `--dart-define=BUNDLED_DEFAULT_SERVER=true` 的发布构建中，于首次启动自动加入
  内嵌服务器并设为默认；测试与公开构建保持「无服务器」语义。

**仓库整理（本轮）**

- 删除无引用死代码（旧战役内容编辑器与 JSON 导入对话框，已被档案编辑器替代）；
- 清理旧品牌分发产物、构建输出、日志与 `__pycache__`；
- 补齐文档：私有资料流水线文档、README 重写、文档索引与执行状态更新；
- 脚本层单测接入 `npm run test:scripts`。

## 下一开发周期

在提出新功能前先基于真实使用反馈建立新规格。不得从历史 `v0.2-v2.x` 文档继续
顺序开发，也不得恢复已隐藏的战斗、Room、Session 或旧 Actor 产品入口。
