# Campaign And Character Integration Implementation Plan

> Design source:
> `docs/superpowers/specs/2026-07-16-campaign-character-integration-design.md`

## Delivery Order

This plan is one coherent `0.1` milestone. Tasks are ordered by dependency and
must use focused TDD before the final full verification.

## Task 1: Campaign Authority Invariants

**Server**

- Remove public invite role selection from controller and service input.
- Persist every public invite with `roleOnJoin = player`.
- Persist every new joined membership as `player`, ignoring legacy invite data.
- Add policy and e2e regression tests proving players cannot obtain manager
  authority.

**Client**

- Stop passing global client mode into campaign pages as authority.
- Derive `canManageCampaign` from current user and campaign membership.
- Hide campaign creation only according to the supported product rule: any
  authenticated user may create a campaign and becomes its owner.
- Keep global mode as an offline workspace preference only.

## Task 2: Typed Campaign Events And Check Requests

**Server**

- Add nullable `eventData` JSON to `CampaignChatMessage`.
- Validate `say`, `action`, `roll`, `system`, and `checkRequest`.
- Restrict `system` and `checkRequest` creation to campaign managers.
- Validate target character and check request payload.
- Preserve server-derived character display snapshots.

**Client**

- Add typed message helpers and event-data serialization.
- Render character identity for both speech and actions.
- Render system events in bold and roll/check request events with focused
  Material 3 surfaces.
- Allow an character owner to answer a check request and persist the linked roll.

## Task 3: Content Relations And Subclass Rules

- Add `ContentRelation` to `ContentEntry` JSON parsing and serialization.
- Validate relation type and stable target IDs during package import.
- Extend choice resolution so `subclass` options must relate to the source
  class.
- Ensure selected subclasses recursively contribute grants, choices, and
  progression.
- Add class-at-level-3 and level-2-to-3 upgrade tests.
- Open class feature and subclass details with the shared floating reader.
- Update the private package format documentation and CHM extraction prompt.

## Task 4: Character Sheet Structure

- Add a dedicated Abilities destination.
- Reduce the persistent header to one compact row.
- Remove the full ability matrix from Overview.
- Replace incremental HP controls with a numeric damage/healing sheet.
- Make overview sections responsive and prevent portrait/landscape overflow.
- Add local and campaign-context check callbacks without coupling the character
  domain to networking.

## Task 5: Resource Interaction

- Present resources as current/max values.
- Use direct pips for small resources and numeric entry for large resources.
- Use one, two, or three columns according to available width.
- Add short-rest and long-rest recovery commands.
- Preserve editable recovery policy and custom resource definitions.
- Add unit and widget tests for clamping, rest recovery, and responsive layout.

## Task 6: Campaign Workspace And Creation Guide

- Replace the chat-only route with a two-page campaign workspace.
- Open on chat and expose the campaign hub by right swipe and app-bar action.
- Put information, characters, shared content, and owner controls in the hub.
- Let the owner open an character, select an ability/save/skill, and send a check
  request.
- Replace the create dialog with a three-step Material 3 guide.
- Keep optional shared-content import recoverable and separate from campaign
  creation success.

## Task 7: Safe Debug Login

- Add compile-time debug-login configuration.
- Use the normal auth API and token store instead of a server bypass.
- Activate only in debug builds when identifier and password are explicitly
  provided.
- Add tests proving release configuration cannot activate debug login.

## Task 8: Verification And Documentation

Run after focused tests are green:

```text
npm run lint:server
npm run test:server
flutter analyze
flutter test
flutter build web --release
docker compose config
```

Then run the local web preview and inspect narrow and wide layouts for:

- compact character header
- ability layout
- resource direct editing
- campaign swipe navigation
- action identity
- system event emphasis
- owner/player control visibility
- subclass creation and upgrade details

Update current execution status with only verified behavior. Do not add private
CHM output to the repository.
