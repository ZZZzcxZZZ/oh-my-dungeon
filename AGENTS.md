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
- Current active milestone is `v0.2`: accounts, server auth, and Player/DM mode integration.
- Do not continue expanding the temporary `rooms` prototype unless the current version plan explicitly says so.
- The `rooms` and dice prototype code must later be folded into the formal Campaign / Session / Table model.

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

Continue `v0.2` from:

```text
docs/roadmap/v0.2-execution-plan.md
```

Recommended next task:

1. Add Prisma auth models: `User`, `ServerAdmin`, `RefreshToken`.
2. Generate Prisma client.
3. Add `PasswordHashService`.
4. Add tested `AuthService` register behavior.
5. Add `POST /api/auth/register`.
