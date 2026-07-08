# AGENTS.md

This file is the root handoff entry for AI coding agents.

## Project Directory

Work from:

```text
C:\Users\26047\Desktop\dnd-table-tool
```

Do not use the older prototype folder as the active workspace.

## Required Reading

Before implementing, read these files in order:

1. `README.md`
2. `docs/roadmap/current-execution-status.md`
3. `docs/roadmap/v0.1-release-checklist.md`
4. `docs/roadmap/v0.2-execution-plan.md`
5. `docs/roadmap/mvp-roadmap.md`
6. `docs/agents/agent-execution-guide.md`
7. `docs/engineering/engineering-standards.md`
8. `docs/architecture/system-architecture.md`
9. `docs/architecture/domain-model.md`
10. `docs/architecture/api-realtime-boundary.md`

If the task involves deployment, also read:

```text
docs/deployment/self-hosting.md
```

## Current Version State

- `v0.1.0` is tagged and represents the engineering skeleton baseline.
- `v0.2.0` is tagged and covers accounts, server auth, and Player/DM mode integration.
- `v0.3.0` is tagged and covers the Campaign / CampaignMember / CampaignInvite model, permissions, and invite-code join flow.
- The `rooms` and dice prototype is frozen: do not extend it. It will be replaced by the formal Session / DiceRoll model in v0.4.

## Development Rules

- Follow the roadmap by version gates, not by random feature additions.
- Use TDD for new behavior: write a failing test, run it, implement, then verify.
- Keep commits small, but make them serve the active milestone.
- Prefer commit messages with version scope, for example:

```text
feat(v0.2): add auth data model
feat(v0.2): add register endpoint
docs(v0.2): update auth plan
```

## Verification Rules

Use targeted verification during implementation:

- Server API or service change: run the relevant server test.
- Flutter page or state change: run the relevant widget/unit test and `flutter analyze` when needed.
- Cross-client/server contract change: run both the server API tests and Flutter API client tests.

Run full `npm run doctor` only for:

- version gates,
- dependency upgrades,
- CI / Docker / script changes,
- release or merge readiness.

Do not use `doctor` as a substitute for reading the roadmap and validating requirements.

## Immediate Next Work

v0.3 is sealed. Next milestone is `v0.4` 跑团桌面基础版: Session model, formal DiceRoll replacing the `rooms` prototype, ChatMessage, JournalEntry, and WebSocket realtime broadcast. Start by creating `docs/roadmap/v0.4-execution-plan.md` with version goals, acceptance criteria, task list, and data model changes before implementing.
