# D&D AI Ready Foundation Design

**Date:** 2026-07-26
**Status:** Approved for implementation planning
**Scope:** Incremental D&D-only foundation work. This design does not implement an AI agent.

## 1. Goal

Make the existing D&D table tool ready for a future AI agent without replacing
the current product or forcing users into an AI workflow.

The foundation must make game state:

- structured and machine-readable;
- editable through one set of validated application operations;
- synchronized between local characters and campaign state;
- traceable through immutable game events;
- exportable and importable as readable Markdown;
- usable through a simple UI while retaining complete character editing.

The current database state remains the source of truth. Events describe changes
and support history, synchronization, summaries, and future memory retrieval;
they are not used to rebuild the entire database.

## 2. Product Principles

1. The UI remains simple. Common actions such as damage, healing, condition
   changes, resource use, and inventory changes are available as direct actions.
2. Full character editing remains available for experienced users and homebrew
   content.
3. The current Flutter controllers and repositories and the NestJS service
   architecture are extended incrementally. No generic command-bus framework is
   introduced.
4. The implementation targets D&D 2024. It does not introduce a generic TRPG
   DSL.
5. Markdown is a readable interchange format, not the runtime database.
6. Future AI tools and current UI controls must call the same application
   operations and pass the same authorization and validation checks.
7. Existing private content packages remain compatible through adapters and
   validation; this milestone does not require re-extraction.

## 3. Character Authority and State

A character is one persistent identity, not a local character plus an unrelated
campaign copy.

### 3.1 Character profile

The profile contains persistent descriptive identity:

- name, avatar, owner, appearance, biography, and notes;
- species, background, classes, subclasses, and level;
- abilities, saves, skills, proficiencies, features, and spells;
- permanent inventory and currency;
- custom D&D fields and homebrew entries.

### 3.2 Character state

Runtime state is scoped:

- the local/default state keeps a character usable offline;
- each campaign state keeps HP, temporary HP, death saves, resources,
  conditions, concentration, and campaign-scoped inventory for that campaign.

The client renders a `ResolvedCharacterView` that combines the persistent
profile with the selected state. In a campaign context the campaign state wins.
In the general character list, the client shows the most recently active
campaign state when available and clearly labels its campaign; otherwise it
shows the local/default state.

Permanent campaign changes, including level changes and permanent item grants,
automatically update the persistent profile. Runtime changes update the selected
campaign state and the local cached view. A character can participate in
multiple campaigns without sharing runtime HP or conditions between them.

### 3.3 Compatibility

The existing `Character`, `CampaignCharacter`, local Drift character tables,
`sheetJson`, and `data` fields remain readable during migration. A versioned v2
adapter converts legacy records into the typed domain model. New write paths use
the v2 structure. Old write paths are removed only after their UI callers have
migrated and compatibility tests pass.

## 4. Structured D&D Data

The initial domain types cover:

- `HitPoints`: current, maximum, and temporary values;
- `DeathSaves`: successes and failures;
- `CharacterResource`: stable ID, name, current, maximum, recovery rule,
  source reference, and custom flag;
- `CharacterCondition`: stable ID, condition reference or type, source,
  duration, remaining duration, removal policy, and metadata;
- `CharacterItem`: instance ID, template reference, name snapshot, quantity,
  equipped and attuned state, owner, scope, and instance data;
- `AbilityScores`: six integer scores;
- `CharacterBuild`: species, background, class and subclass choices, level,
  proficiencies, features, and spells.

Standard fields use explicit typed properties. Extensible lists use validated
JSON objects with stable IDs. Arbitrary extensions are stored under a namespaced
object such as `homebrew.dragonBloodline`; extensions contain data only and
cannot execute scripts.

Content library records are templates. Character inventory records are
instances. An instance keeps its template reference and a small name snapshot
so that a character remains readable if a package is unavailable.

## 5. Application Operations

No caller directly mutates persistence fields for gameplay changes. Feature
services expose ordinary methods such as:

- `adjustHitPoints`;
- `setTemporaryHitPoints`;
- `addCondition` and `removeCondition`;
- `consumeResource` and `restoreResources`;
- `grantItem`, `consumeItem`, `transferItem`, and `equipItem`;
- `updateCharacterProfile` and `updateCharacterBuild`;
- later, `startCombat`, `addCombatant`, `advanceTurn`, and `endCombat`.

Each operation performs, in one application transaction where applicable:

1. authenticate the caller;
2. authorize ownership or campaign DM capability;
3. validate the command and current revision;
4. apply D&D-specific invariants;
5. persist the state change;
6. append a `GameEvent`;
7. append an outbox/sync signal;
8. return the updated view and event.

HTTP action endpoints are explicit and stable, for example:

```text
POST /characters/:id/actions/adjust-hp
POST /characters/:id/actions/add-condition
POST /characters/:id/actions/restore-resources
POST /characters/:id/items
POST /items/:id/actions/consume
```

Flutter UI actions call repositories/controllers that use these operations.
Future AI tools will use the same contracts.

## 6. Game Events

`GameEvent` is an immutable audit fact associated with an optional campaign and
character. It records:

- schema version and event type;
- character type and character ID;
- target references;
- command/request ID for idempotency;
- cause reference;
- structured before and after snapshots limited to changed values;
- structured payload;
- creation time.

Initial event types include:

```text
character.hp.adjusted
character.condition.added
character.condition.removed
character.resource.consumed
character.resource.restored
character.item.granted
character.item.consumed
character.item.transferred
character.item.equipped
character.profile.updated
character.build.updated
campaign.combat.started
campaign.combat.turn_advanced
campaign.combat.ended
```

Chat system messages reference a game event instead of serving as the only
record of the change. Event payloads contain IDs and values, not executable
instructions or localized display text.

## 7. Queries and Future AI Context

The first query surface remains deliberately small:

```text
GET /characters/:id
GET /characters/:id/summary
GET /characters/:id/events
GET /campaigns/:id/state
GET /campaigns/:id/events
```

Detail views support the current UI. Summary views return compact structured
data for lists and future tool calls. Event queries support cursor pagination
and filters by type, target, and time.

A later `GET /campaigns/:id/context` endpoint will compose a bounded context:

- campaign identity and current location;
- relevant characters and compact states;
- active combat summary;
- active objectives and NPC references;
- recent events;
- knowledge entry references.

It will return references to rules rather than entire rule texts. A future agent
can search and load only the referenced content.

## 8. Future Agent Boundary

The future agent system may organize files into:

- `prompts/` for short behavioral and permission policies;
- `skills/` for workflows such as resolving an attack or leveling a character;
- `knowledge/` for searchable rule and content entries;
- `campaign-memory/` for summaries and indexed campaign facts;
- `characters/` for Markdown exchange files.

Rules and campaign history are not embedded wholesale in a system prompt.
Search retrieves relevant entries by stable ID, type, relationship, tag, and
text. This milestone only creates data and API contracts compatible with that
future layout.

## 9. Readable Markdown Exchange

Markdown exports prioritize human reading. YAML front matter contains only
format metadata, schema version, stable character ID, and update time.

The document uses predictable headings, tables, lists, and prose:

```markdown
---
format: dnd-character
version: 1
character-id: aria
---

# 艾莉娅

> 5 级精灵法师 · 贤者

## 属性

| 力量 | 敏捷 | 体质 | 智力 | 感知 | 魅力 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 8 | 14 | 13 | 18 | 12 | 10 |

## 生命与防御

- 生命值：24 / 35
- 临时生命值：0
- 护甲等级：15
- 速度：30 尺
```

Stable references that are necessary for lossless import use unobtrusive HTML
comments:

```markdown
<!-- dnd:item instance=itm_123 template=equipment:quarterstaff -->
```

The parser tolerates harmless formatting edits but validates numeric and
structured fields. Import always produces a preview with understandable
differences. The user chooses one of:

- create a new character;
- replace an existing character;
- merge compatible sections.

Exports support a base character card and a current campaign snapshot.

## 10. Offline Synchronization

Local edits save immediately. Bound-character operations enter the existing
outbox and synchronize when the server is available. Commands carry a stable
request ID and expected revision.

Delta operations such as HP adjustment and resource consumption are idempotent
and retryable. Full edits use optimistic revision checks. A real same-field
conflict is never silently overwritten; the UI offers two direct choices:
use the device version or use the server version.

The character list always renders the latest local cache. Online refreshes
happen automatically. Authentication or a live server is required only for
campaign and multiplayer operations, not for local character editing,
Markdown exchange, or local content lookup.

## 11. UI Requirements

The character card has two levels:

### 11.1 Quick play

Direct actions for HP, temporary HP, death saves, conditions, resources,
inventory, spells, checks, and dice rolls. The UI uses plain D&D terminology
and does not expose synchronization or domain architecture concepts.

### 11.2 Full editing

The existing complete character editor remains available. It covers profile,
abilities, combat statistics, build choices, proficiencies, features, spells,
inventory, currency, resources, conditions, biography, notes, and custom
entries.

Rules-derived entries display their source and can be restored to the package
default. Users may override names, descriptions, uses, recovery rules, and
values. Custom entries use the same UI components as package-derived entries.

## 12. Existing Defects Included in the Milestone

Before the new application operations are treated as reliable, the
implementation fixes:

1. direct and group message WebSocket broadcasts leaking to the campaign room;
2. conversation read state being shared across all conversations;
3. archived conversations remaining listed and writable;
4. runtime Docker images depending on an unpinned `npx prisma` download;
5. insecure Compose fallback credentials;
6. media JSON requests being rejected before the advertised upload limit and
   malformed Base64 being accepted;
7. factual drift in the development handoff document.

## 13. Delivery Phases

### Phase 1: reliable foundation

- fix the seven existing defects;
- add versioned character domain types and legacy adapters;
- add structured HP, condition, resource, and item operations;
- add `GameEvent` persistence and event queries;
- add character detail and summary views;
- migrate affected UI actions to the operations;
- add readable Markdown export, import, validation, and diff preview.

### Phase 2: combat and bounded context

- normalize active combat, combatants, initiative, turn, and action state;
- move combat operations behind the same application service boundary;
- add compact campaign and combat context queries;
- extend event coverage for combat and objectives.

## 14. Non-goals

This milestone does not implement:

- model-provider integration;
- an AI agent runtime;
- prompt or skill execution;
- automatic narration;
- embeddings or a vector database;
- complete combat rules automation;
- a generic TRPG rules language;
- executable scripts in content, characters, or extensions.

## 15. Acceptance Criteria

1. A character remains fully editable and readable offline.
2. A campaign-bound character shows the latest campaign state in campaign UI
   and the cached latest state in the general character list.
3. Permanent campaign changes automatically update the persistent character.
4. Runtime state for separate campaigns does not leak between campaigns.
5. UI and API operations produce the same validated state and game events.
6. Private conversation payloads are sent only to authorized participants.
7. Conversation unread state and archive behavior are conversation-specific.
8. Server deployment does not require runtime package downloads or default
   secrets.
9. Supported avatar uploads reach the media controller and invalid Base64 is
   rejected.
10. Markdown round trips preserve standard and custom character data while the
    exported file remains directly readable.
11. Existing server and Flutter test suites remain green.
