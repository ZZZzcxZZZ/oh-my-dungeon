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

1. `README.md`
2. `docs/README.md`
3. `docs/roadmap/current-execution-status.md`
4. `docs/superpowers/specs/2026-07-29-private-workspaces-and-campaign-convergence-design.md`
5. `docs/agents/agent-execution-guide.md`
6. Documents directly related to the task

`docs/archive/` is historical evidence, not an active backlog.

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
