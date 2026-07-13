# 离线优先资料库与战役协作总执行 Prompt

将以下内容原样交给接续开发 Agent：

```text
你将在 `C:\Users\26047\Desktop\dnd-table-tool` 持续开发 D&D 跑团工具 0.1。不要只实现一个页面或一个端点后停下；除非出现无法自行解决的真实阻塞，否则按四份计划从头到尾连续推进，并在每个阶段形成可运行、可测试、可提交的完整增量。

开始前必须阅读：

1. `AGENTS.md`
2. `docs/superpowers/specs/2026-07-14-offline-first-compendium-sync-design.md`
3. `docs/superpowers/plans/2026-07-14-offline-foundation.md`
4. `docs/superpowers/plans/2026-07-14-local-compendium.md`
5. `docs/superpowers/plans/2026-07-14-local-characters-vault.md`
6. `docs/superpowers/plans/2026-07-14-campaign-actors-content.md`
7. `docs/roadmap/current-execution-status.md`
8. `docs/agents/agent-execution-guide.md`

使用 `superpowers:using-git-worktrees` 创建隔离 worktree，再用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 执行。计划中的每个任务都必须逐项更新 `- [ ]` 为 `- [x]`；不要先批量勾选。工作区可能有用户变更，先检查 `git status`，不得回退或覆盖不属于你的变更。

核心产品边界不可改变：

- 公开版本统一编号为 0.1，完成这轮前不要擅自升级版本号。
- 客户端离线优先。资料库、个人角色、角色创建、规则计算、收藏、笔记、设置在未配置服务器、未登录和断网时必须可用。
- 服务器是可选协作设施，负责个人 Vault 跨设备同步，以及战役 Actor、DM 自定义条目、聊天和实时状态。
- 默认资料库为空。公开仓库、种子、构建产物和默认数据库不得包含 SRD、玩家手册或任何官方规则正文。
- 不帮助提取或分发受版权保护的官方资料。只实现通用、空内容、用户自行导入的 schema、校验、存储和 UI。
- 本地基础资料包正文、图片和源文件永不上传。Vault 只同步安装清单中的 `id/version/locale/system/contentHash`。
- 战役资料同步必须保持简单：只同步 DM 创建的独立 JSON 条目。不要实现 overlay、patch、dependency、翻译层、勘误层、服务器包市场或自动下载。
- Player 模式角色页管理自己的本地角色；DM 模式角色页管理当前战役的玩家 Actor、NPC、未认领和归档角色。
- 玩家发布本地角色后形成完整 `CampaignActor`。owner/DM 对战役 Actor 有完整编辑权；更新带 revision，冲突可见，所有 DM 修改有审计，并同步回角色所有者。
- 聊天身份绑定 `CampaignActor`，不得信任客户端传入的显示名或头像。玩家输入支持“说”和“做”；DM 点击头像进入完整可编辑角色卡。
- WebSocket 只广播最新 cursor 和 entityType，完整实体通过 HTTP changes 拉取并写本地 Drift 缓存。
- Wiki 同时查询本地资料与当前战役缓存，同名条目不覆盖，来源必须清晰。

执行纪律：

1. 先运行一次 `npm run setup` 和 `npm run check` 建立基线。Windows 若只出现 Flutter symlink/Developer Mode 提示但命令 exit 0，记录即可，不要反复 doctor。
2. 每个功能严格 TDD：先写失败测试并运行确认红，再写最小实现，运行目标测试确认绿，然后提交。
3. 优先遵循现有 NestJS、Prisma、Flutter 和测试装配模式；不要顺手重构无关模块。
4. 手工编辑使用 `apply_patch`。搜索优先 `rg`/`rg --files`。不要使用破坏性 Git 命令。
5. 每个计划内使用目标测试、lint 或 analyze；只在一个计划完成时运行 `npm run check`。四份计划全部完成后再运行 `npm run doctor` 和 `flutter build web`。
6. 每个任务完成一个独立 Conventional Commit。提交前检查 `git diff --check` 和任务涉及的测试结果。
7. 如果测试暴露既有缺陷且阻断当前计划，先补回归测试再修复；如果与计划无关，记录但不要扩大范围。
8. 每 30 秒以内给用户简短进度更新，说明正在完成哪个计划、发现了什么、下一步是什么。不要因为完成一个小功能就结束任务。
9. 只有同一阻塞连续出现三次且无法继续时才停止，并报告已尝试命令、完整错误、受阻任务和可继续的未阻塞工作。

阶段完成门禁：

- 阶段 1：应用无服务器仍进入本地主壳；Drift、Profile 迁移、Outbox 和同步状态有测试；`npm run check` 通过。
- 阶段 2：默认空资料库、导入/升级/删除、Wiki 搜索/链接/类型视图/收藏/笔记和设置 GUI 可用；服务端无默认正文；`npm run check` 通过。
- 阶段 3：个人角色完全本地化，资料引用有快照；Vault 同步不上传资料正文；旧服务器角色安全导入；`npm run check` 通过。
- 阶段 4：CampaignActor、DM 完整编辑与审计、战役 JSON 条目 cursor 同步、DM 资料管理、Wiki 合并与 Actor 聊天全部联通；旧服务端内容边界已迁移；`npm run check` 通过。

最终验证必须使用新鲜输出：

```powershell
npm run setup
npm run check
npm run doctor
cd apps/client_flutter
flutter build web
```

随后执行：

```powershell
rg -n -i "srd|player.?s handbook|players handbook|玩家手册" apps packages --glob '!**/build/**' --glob '!**/node_modules/**'
git diff --check
git status --short
```

逐条核对四份计划的完成标准，更新 `README.md`、`docs/roadmap/current-execution-status.md`、`docs/agents/agent-execution-guide.md` 和架构文档。最终汇报必须包含：各阶段提交、实际测试通过数、build 结果、迁移注意事项、仍存在的明确风险。没有新鲜验证证据，不得声称完成。
```
