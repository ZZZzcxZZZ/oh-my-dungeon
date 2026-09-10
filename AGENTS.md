# AGENTS.md

This is the root handoff entry for coding agents.

## Workspace

Work only from:

```text
C:\Users\26047\Desktop\dnd-table-tool
```

The worktree may contain uncommitted work from the user or other agents. Never
reset, revert, delete, or commit unrelated changes.

## Required Reading

1. `README.md` — 面向使用者的安装与使用教程
2. `docs/README.md` — **项目唯一事实来源**：架构、数据模型、接口边界、领域行为、
   离线与同步、内容体系、部署运维、工程规范、当前状态与验收基线
3. `AGENTS.md`（本文件）— Agent 协作硬约束
4. `DESIGN.md` — 涉及 UI 时必读的设计 token 与组件契约
5. 仅当需要追溯历史决策时，才查阅 `docs/archive/`（历史证据，不是待办）

设计系统回归保护：`apps/client_flutter/test/app_theme_test.dart`（契约断言）、
`apps/client_flutter/test/golden/`（golden 基线）、`npm run lint:design`（DESIGN.md 契约 lint）。

`docs/archive/` 中的文档可能描述已被取代的流程与接口，不得直接作为实现依据。

## Current Boundaries

- Public development version is `0.1.0`.
- Use Character for the product domain. Actor is allowed only in migrations or
  archived history.
- A campaign is the persistent chat and collaboration workspace. Do not restore
  Room or Session as prerequisites.
- The Flutter client is offline-first. Server collaboration and Personal Vault
  sync are optional.
- UI and future AI integrations use the same query and operation services. They
  must not write databases directly.
- Combat and AI Agent runtimes are outside the current scope.
- Commercial rulebook text is private user-provided content. Never commit it,
  seed it, or include it in a public build.

## Engineering Rules

- Read existing implementation and tests before changing behavior.
- Use TDD for behavior changes.
- Prefer existing boundaries and Material 3 shared components.
- Hide unfinished features instead of exposing placeholder controls.
- Delete code only after reference and static-analysis audits.
- Use targeted verification while developing and `npm run check` for a phase
  gate.

## Private Test Content

`private-imports/` is ignored by Git and may contain local copyrighted test
material. Use only the dedicated validation and private build scripts. Do not
move it into tracked assets or distribution packages.
