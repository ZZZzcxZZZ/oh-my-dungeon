# 当前执行状态

**版本：** 0.1
**更新时间：** 2026-07-29
**状态：** 私人工作区与战役体验收敛计划已完成并验收

## 当前产品边界

- Flutter 客户端离线优先；本地角色、资料包、设置和 Markdown 镜像不依赖服务器。
- NestJS 服务端负责账号、Personal Vault 和战役协作。
- 战役是类似群聊的长期跑团工作区，不要求创建 Room 或 Session。
- 统一领域名称为 Character；Actor 只允许出现在兼容迁移和历史档案中。
- 当前不开发战斗系统和 AI Agent 运行时。
- 公开仓库和公开构建不包含商业规则正文。

## 已完成

- 服务器实例身份、客户端备注和每账号私人工作区；
- 账号切换数据隔离、离线账号恢复和旧数据迁移；
- 本地 Character、战役 Character 发布、玩家绑定和 DM 管理权限；
- 战役主聊、私聊、小群、未读状态与增量刷新；
- 档案创建者权限、DM 管理权限和统一资料阅读界面；
- Material 3 导航、资料筛选、长文本和共享详情组件；
- Character Markdown v2、原生自动镜像、外部修改差异确认；
- 结构化怪物分类与动作投影；
- AI Ready 查询、操作、事件和数据结构规范；
- Actor 持久化名称向 Character 的无损数据库迁移。

## 验收基线

- 服务端：352 项测试、27 个套件通过；
- Flutter：835 项通过，2 项私有路径测试按设计跳过；
- Flutter analyze、服务端 lint/build、Prisma validate 通过；
- PHB 私有包 1106 条通过 schema、引用、规则和真实 Flutter 导入验证；
- PHB、MM、DMG 私人测试构建共包含 1880 条内容；
- release Web 已在桌面和 390×844 移动视口检查，无控制台错误和横向溢出。

## 2026-07-29 仓库整理

- 100 份旧路线、Agent prompt、交接报告、计划和规格已移入 `docs/archive/`；
- 当前文档统一由 `docs/README.md` 索引，非归档 Markdown 本地链接零断链；
- 删除项目级 Pub 缓存、日志、旧分发产物、工具状态和旧顶层 PHB bundle；
- 删除无消费者的客户端 encounters 页面、控制器、API 客户端及孤立测试；
- 删除没有代码或消费者的 `packages/` 占位目录；
- `private-imports/` 与私人 release Web 测试版已保留并重新验证。

完整实现和验收记录见
[私人工作区与战役体验收敛规格](../superpowers/specs/2026-07-29-private-workspaces-and-campaign-convergence-design.md)。

## 下一开发周期

在提出新功能前先基于真实使用反馈建立新规格。不得从历史 `v0.2-v2.x` 文档继续
顺序开发，也不得恢复已隐藏的战斗、Room、Session 或旧 Actor 产品入口。
