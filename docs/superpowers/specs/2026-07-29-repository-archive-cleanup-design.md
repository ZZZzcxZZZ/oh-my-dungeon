# 仓库归档清理设计

**日期：** 2026-07-29
**版本：** 0.1
**状态：** 已完成并验收

## 目标

让仓库根目录和文档入口只呈现当前仍有效的工程事实，同时保留可追溯的历史决策。
本轮不改变业务行为，不删除私人测试资料，不引入新的版本编号。

## 保留

- `apps/`、`infra/`、`scripts/` 和当前工程配置；
- `private-imports/` 及当前 `apps/client_flutter/build/web` 私人测试构建；
- `docs/architecture/`、`docs/content/`、`docs/deployment/`、`docs/development/`、
  `docs/engineering/`；
- 当前产品规划、当前执行状态、0.1 发布清单；
- 2026-07-29 私人工作区与战役体验收敛规格；
- 数据库迁移中的旧 Actor/Session/Room 名称。

## 归档

- 旧 v0.2-v2.17 路线和执行记录；
- 已完成的历史里程碑、旧 MVP 计划和旧交接报告；
- 已执行完且没有消费者的并行 Agent prompt；
- 已完成或被新设计覆盖的 superpowers plans/specs。

归档目录为 `docs/archive/`，按 `roadmap/`、`agent-prompts/`、`handoffs/`、
`superpowers/plans/`、`superpowers/specs/` 分类。归档文件不再作为当前实现依据。

## 删除

- `.pub-cache/`、`.logs/`、`dist/` 等可重新生成的本地输出；
- 空的 `.codex-test-bin/`、`.worktrees/`；
- 顶层旧 `phb-2024-content-bundle.json`；
- 经引用审计确认没有消费者的废弃源码。

`.trae/`、`.workbuddy/`、`.superpowers/` 属于工具状态，本轮只在确认不包含用户配置
或未完成工作后处理。

## 当前文档入口

`docs/README.md` 作为唯一文档索引，区分：

1. 当前事实来源；
2. 当前 0.1 计划与验收；
3. 历史档案。

根 `README.md`、`AGENTS.md` 和 Agent 执行指南不得再链接历史版本为当前计划。

## 验收

- `git diff --check` 通过；
- 根目录不再出现旧私有 bundle、日志、项目级 Pub 缓存和旧分发产物；
- 当前文档中不把 v0.2-v2.x、Actor、Room、Session 当作现行架构；
- 所有历史文件可在 `docs/archive/README.md` 查找；
- Flutter analyze、客户端与服务端测试、服务端 lint/build 通过；
- 私人测试资料和现有 Web 测试版仍在。
