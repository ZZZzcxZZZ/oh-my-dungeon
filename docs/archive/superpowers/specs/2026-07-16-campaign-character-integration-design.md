# Campaign And Character Integration Design

## Status

Approved on 2026-07-16. This design uses the domain-centered approach:
permissions, campaign events, content relationships, and rules projection are
made authoritative before the dependent UI is rebuilt.

## Product Goal

Make the campaign the online play workspace and the character sheet the
offline-first rules workspace. A character remains fully usable without a
server. When opened in a campaign context, the same character actions can
produce validated campaign events such as checks, rolls, item changes, and
rest results.

This milestone does not add maps, tactical combat, voice, macros, multiclassing,
or a generic plugin runtime.

## Authority And Permissions

Server campaign membership is the only source of campaign authority.

- The campaign creator is persisted as `owner`.
- Public invites always create a `player` membership.
- The client Player/DM workspace preference must not grant campaign authority.
- The owner can view and edit every campaign character.
- A player can edit only a campaign character owned by that player.
- DM-only controls are both hidden in the client and rejected by server policy.

The existing `dm` role may remain in storage for future migration, but this
milestone exposes no public path that grants it.

## Campaign Workspace

Opening a campaign enters chat. The campaign page is a two-page horizontal
workspace:

1. Campaign hub: information, members and characters, shared content, and owner
   controls.
2. Chat: the initial page and primary play surface.

Swiping right from chat reveals the campaign hub. Explicit app-bar navigation
is also available so the gesture is never the only discovery path.

The member list uses campaign characters rather than private local characters.
Selecting an character opens a quick sheet. The campaign owner may choose an
ability, saving throw, or skill and send a check request to that character.

## Typed Campaign Events

Campaign chat is a persisted event stream with a deliberately small set of
message kinds:

- `say`: in-character speech with character identity and a speech surface.
- `action`: in-character action with character identity and italic body text.
- `roll`: a dice result with character identity and structured roll metadata.
- `system`: a bold campaign event such as item gain or rest completion.
- `checkRequest`: a DM request targeting an character and a named check.

Every character-originated event stores server-derived display name and avatar
snapshots. Clients cannot submit authoritative speaker names.

Structured metadata is stored in `eventData`. It is JSON data, not executable
code. The minimum shapes are:

```json
{
  "kind": "roll",
  "eventData": {
    "notation": "1d20+5",
    "total": 17,
    "label": "察觉",
    "requestId": null
  }
}
```

```json
{
  "kind": "checkRequest",
  "eventData": {
    "targetCharacterId": "character-id",
    "checkType": "skill",
    "checkKey": "察觉",
    "label": "察觉检定",
    "dc": 15,
    "rollMode": "normal"
  }
}
```

The server validates message kind, character ownership, campaign management rights,
target character membership, supported check type, DC range, and roll mode.

## Character Sheet Information Architecture

The sheet uses eight destinations:

1. Overview
2. Abilities
3. Actions
4. Spells
5. Equipment
6. Resources
7. Features
8. Profile

The header is one compact summary row containing identity, class and level,
HP, AC, and active conditions. It must not become a second overview page.

Overview contains only high-frequency runtime state: HP, temporary HP,
inspiration, conditions, death saves, movement, initiative, passive perception,
and a short list of common actions. HP editing uses a numeric damage/healing
sheet rather than repeated one-point buttons.

Abilities owns all six ability scores, saving throws, and skills. Available
width determines a two- or three-column ability layout. Selecting a check rolls
locally when outside a campaign and offers campaign actions when a campaign
interaction context exists.

Resources display current value rather than "used" value:

- Small maxima use directly selectable pips.
- Larger maxima use a numeric current-value field.
- Narrow width uses one column, medium width two, and wide width three.
- Short-rest and long-rest commands restore all matching resources.
- Editing and deletion remain available from each resource menu.

## Content Relationships And Subclasses

Content package format 2 remains the public format. It gains an optional
backward-compatible `relations` array:

```json
{
  "relations": [
    {
      "type": "subclassOf",
      "targetId": "private-2024:class/wizard"
    }
  ]
}
```

Supported relations in this milestone:

- `subclassOf`
- `featureOf`
- `spellOf`
- `requires`
- `replaces`
- `related`

Relations are stable entry references and do not duplicate text.

A class activates a level-3 choice whose `optionType` is `subclass`.
The choice resolver filters subclasses whose `subclassOf` target equals the
source class ID. Selecting a subclass recursively activates the subclass rules
and progression. Creating a character at level 3 or higher and upgrading from
level 2 to 3 therefore use the same rule contract.

Class and subclass features remain independent `classFeature` entries. Their
detail surfaces use the shared floating content reader from both creation and
upgrade flows.

## Campaign Creation Guide

Campaign creation uses a compact three-step guide:

1. Identity: name and optional description.
2. Shared rules: select campaign JSON entries or skip.
3. Review: explain that the creator is the owner and invitees join as players.

Creating the campaign remains one server transaction. Optional content import
runs only after campaign creation and reports recoverable failures separately.

## Session Restoration

Authentication uses the same production flow in every build.

- Auto-login is a per-server user preference and defaults to enabled.
- The client stores tokens, never usernames or passwords.
- Startup validates the access token, then uses the refresh token after a 401.
- Disabling auto-login clears persisted tokens without ending the current
  in-memory session.
- The server receives no anonymous authentication bypass.

## CHM Private Extraction

The supplied CHM is user-provided private source material. Extraction happens
outside tracked repository paths. The extractor reads the CHM table of
contents and GB2312 HTML DOM, creates format-2 entries and relations, validates
all references, and writes a private ignored package plus review reports.

No extracted commercial text or assets may enter Git history, public fixtures,
Docker images, or distributable application assets.

## Acceptance Criteria

- A player cannot obtain campaign owner or DM authority through a client mode
  switch or public invite.
- Speech, actions, rolls, system events, and check requests retain their
  intended type after a server round trip.
- Action messages visibly identify their character.
- The owner can request a player character check and the player can answer it.
- The character sheet has a dedicated abilities destination and compact
  overview.
- Resources support direct current-value editing and rest recovery.
- Subclass choices appear automatically at the correct class progression level.
- Subclass features project into creation, upgrade, and the character sheet.
- Offline characters and local content remain usable without authentication.
- Debug mode cannot be enabled in release builds.
