# 仓库归档清理实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 归档已完成或被替代的资料，删除可再生成的残留，让当前文档入口与 0.1 实现一致。

**架构：** 当前事实来源继续位于原分类目录；历史资料机械移动到 `docs/archive/`，
并通过单一索引访问。忽略的私人资料与当前测试构建独立保留。

**技术栈：** Git、PowerShell、Markdown、Flutter、NestJS

---

### 任务 1：审计文件与引用

**文件：**
- 修改：`docs/superpowers/plans/2026-07-29-repository-archive-cleanup.md`

- [x] 列出根目录生成物、文档和 Git 跟踪状态。
- [x] 使用 `rg` 检查 Agent prompt、旧 roadmap 和旧设计的当前引用。
- [x] 确认 `private-imports/` 与 `apps/client_flutter/build/web` 属于保留项。

### 任务 2：建立历史档案

**文件：**
- 创建：`docs/archive/README.md`
- 移动：旧路线、Agent prompt、handoff、历史 plans/specs

- [x] 创建按类别组织的归档目录。
- [x] 移动旧文件，保持原文件名。
- [x] 为档案添加“非当前事实来源”说明和分类索引。
- [x] 修复移动造成的当前文档链接。

### 任务 3：收束当前文档入口

**文件：**
- 创建：`docs/README.md`
- 修改：`README.md`
- 修改：`docs/agents/agent-execution-guide.md`
- 修改：`docs/roadmap/current-execution-status.md`

- [x] 建立当前事实来源、0.1 状态和历史档案的单一入口。
- [x] 清除现行文档中的旧版本排序和退役模块指引。
- [x] 检查所有当前 Markdown 本地链接。

### 任务 4：删除可再生成残留

**文件：**
- 删除：`.pub-cache/`
- 删除：`.logs/`
- 删除：`dist/`
- 删除：空 `.codex-test-bin/`
- 删除：空 `.worktrees/`
- 删除：`phb-2024-content-bundle.json`

- [x] 验证每个绝对目标路径都在仓库根目录内。
- [x] 使用原生 PowerShell 删除目标。
- [x] 确认 `private-imports/` 和当前 Web 构建未被删除。

### 任务 5：引用审计与验收

**文件：**
- 修改：`docs/superpowers/plans/2026-07-29-repository-archive-cleanup.md`

- [x] 运行当前文档退役术语扫描和链接检查。
- [x] 运行 `git diff --check`。
- [x] 运行 `npm run check`。
- [x] 运行服务端 build 与 Prisma validate。
- [x] 确认私人资料和 Web 测试版仍存在。
