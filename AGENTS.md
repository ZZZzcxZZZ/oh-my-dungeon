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
3. `docs/roadmap/2026-07-23-integrated-product-hardening-roadmap.md`
4. `docs/roadmap/mvp-roadmap.md`
5. `docs/agents/agent-execution-guide.md`
6. `docs/engineering/engineering-standards.md`
7. `docs/architecture/system-architecture.md`
8. `docs/architecture/domain-model.md`
9. `docs/architecture/api-realtime-boundary.md`

If the task involves deployment, also read:

```text
docs/deployment/self-hosting.md
```

## Current Version State

- The public development line is `0.1.0`; historical `v0.x`, `v1.x`, and
  `v2.x` tags are internal iteration records, not release gates.
- The product is campaign-first: a campaign opens as a group-chat room. Do not
  extend the frozen `rooms` prototype or revive the old top-level table flow.
- The active milestone is the `0.1` campaign/rules integration hardening line.
  Treat `docs/roadmap/current-execution-status.md` as the live backlog and the
  July 18 hardening spec/plan as the latest completed design baseline.
- `RoomsModule`, `SessionsModule`, `SessionsGateway`, and the standalone
  `CheckRequestsModule` are retired. Do not recreate their routes or make a
  Session a prerequisite for campaign chat, journal, checks, or encounters.
- Commercial rulebook content remains a user-provided private import. Never
  commit it, seed it, or include it in a distributable build artifact.

## Development Rules

- Follow the roadmap by version gates, not by random feature additions.
- Use TDD for new behavior: write a failing test, run it, implement, then verify.
- Keep commits small, but make them serve the active milestone.
- Prefer commit messages with version scope, for example:

```text
feat(0.1): add campaign conversations model
feat(0.1-chat-01): implement speaker snapshot
docs(0.1): update hardening plan
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

Read `docs/superpowers/specs/2026-07-18-campaign-rules-integration-hardening-design.md`
and `docs/superpowers/plans/2026-07-18-campaign-rules-integration-hardening.md`
before changing campaign, Actor, character builder, or content integration.
Preserve the offline boundary: imported package bodies remain local, Vault
only carries allowed personal entities, and campaigns only sync DM-published
JSON entries. Do not add a public package marketplace or a second detail flow.
