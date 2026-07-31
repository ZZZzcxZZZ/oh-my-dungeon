# Player Flow And Campaign Tools Hardening Plan

> **Scope:** Incrementally harden the current D&D application. Do not implement
> combat or a generic TRPG engine. Preserve free-form character editing while
> making rule-driven creation clearer and safer.

## Goals

1. Make player character creation use local content directly.
2. Separate rule-validated choices from optional custom content.
3. Treat temporary chat identities as one-message snapshots, never persisted characters.
4. Make campaign archive and DM utilities complete, simple, and consistent.
5. Remove unfinished entry points and align touched UI with Material 3.

## Task 1: Remove The Character Content Source Gate

**Files**

- Modify: `apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- Modify: `apps/client_flutter/test/characters_tab_page_test.dart`

**TDD**

1. Add a widget test with campaigns available that taps create and asserts:
   - no `选择创建资料` dialog appears;
   - the builder opens directly;
   - campaign content selection callback is not invoked.
2. Run:
   `flutter test test/characters_tab_page_test.dart`
3. Remove `_selectCampaignContentSource()` and always query
   `localContentRepository ?? contentRepository`.
4. Re-run the targeted test and `flutter analyze`.

**Acceptance**

- Player creation has one obvious entry.
- Campaign-specific content remains unavailable until its future design is ready.

## Task 2: Remove Persistent Temporary Characters

**Files**

- Modify: `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- Modify: the actual `CampaignIdentitySheet` source located by `rg`
- Modify: `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_tool_sheet.dart`
- Modify: `apps/client_flutter/test/campaign_identity_sheet_test.dart`
- Modify: relevant campaign chat/tool sheet widget tests
- Modify: `apps/server_nest/src/modules/campaign-sync/campaign-characters.controller.ts`
- Modify: `apps/server_nest/src/modules/campaign-sync/campaign-characters.service.ts`
- Modify: `apps/server_nest/test/campaign-characters.e2e-spec.ts`

**TDD**

1. Add client tests proving the identity sheet has one local temporary identity
   entry and never lists stored temporary characters.
2. Add server e2e coverage proving character creation/update rejects
   `lifecycle=temporary`.
3. Run the targeted Flutter and Nest tests and confirm failure.
4. Remove persisted temporary character sections and duplicate tool actions.
5. Reject new temporary lifecycle writes while keeping historical message
   snapshots readable and old character records hidden/archivable.
6. Re-run targeted tests.

**Acceptance**

- A temporary identity exists only in the outgoing message speaker snapshot.
- It clears after a successful send.
- NPCs and other persistent characters remain manageable.

## Task 3: Harden Rule-Driven Spell Selection

**Files**

- Modify: `apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- Modify: `apps/client_flutter/lib/src/features/rules/domain/rule_choice_resolver.dart`
- Add/modify: `apps/client_flutter/test/character_builder_choices_test.dart`
- Add/modify: `apps/client_flutter/test/character_rules_engine_test.dart`

**TDD**

1. Add domain tests for class list, character level, maximum spell level,
   explicit option IDs/tags, and min/max choice count.
2. Add widget tests for:
   - visible selected count;
   - spell name/level/school filters;
   - disabled rule choices after reaching the maximum;
   - a separate custom spell action that does not affect the rule quota.
3. Implement a small selection view model/helper rather than embedding more
   filtering logic directly in the page widget.
4. Render rule choices and custom choices as visually separate sections.
5. Re-run targeted tests and analyze.

**Acceptance**

- A level-one rule choice cannot select ninth-level spells.
- Choice limits are visible and enforced for rule entries only.
- Users can still add clearly marked custom spells.

## Task 4: Add Equipment Budget And Custom Equipment

**Files**

- Modify: `apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- Add: `apps/client_flutter/lib/src/features/characters/domain/equipment_cost.dart`
- Add: `apps/client_flutter/test/equipment_cost_test.dart`
- Modify: `apps/client_flutter/test/character_builder_choices_test.dart`

**TDD**

1. Add unit tests for normalized denomination conversion, quantity, subtotal,
   total, and unpriced custom entries.
2. Add widget tests for recommended package versus shopping mode, displayed
   suggested budget, overspend warning, and custom item creation.
3. Implement the cost value object and keep calculation out of the widget.
4. Display the budget as guidance only. Never disable submit or remove an item
   because the total exceeds the suggested budget.

**Acceptance**

- Prices and totals are understandable.
- Overspending produces a warning, not a hard limit.
- Custom equipment remains available.

## Task 5: Make The Story Step Useful

**Files**

- Modify: `apps/client_flutter/lib/src/features/characters/domain/character.dart`
- Modify: character serialization and Markdown import/export adapters
- Modify: `apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- Modify/add: character domain, Markdown, and builder tests

**TDD**

1. Add round-trip tests for appearance, personality traits, ideals, bonds,
   flaws, backstory, and private notes.
2. Add a widget test for the renamed `故事` step and its fields.
3. Extend the structured character model without replacing existing free-form
   editing.
4. Keep only the character name required.

**Acceptance**

- Story data survives local save, synchronization, and readable Markdown
   import/export.

## Task 6: Simplify Campaign Archive Editing

**Files**

- Modify: `apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_archive_editor_page.dart`
- Modify: `apps/client_flutter/test/campaign_archive_editor_page_test.dart`

**TDD**

1. Test field order: type, title, tags, summary, body, linked entries.
2. Test link search while already-selected entries remain selected.
3. Test that no attachment placeholder is exposed.
4. Implement a compact searchable relation picker using Material 3 fields and
   list rows.

**Acceptance**

- Tags sit directly below title.
- Relations are searchable and reliable.
- No non-functional attachment promise is shown.

## Task 7: Complete DM Quick Operations

**Files**

- Modify: `apps/client_flutter/lib/src/features/campaigns/presentation/characters/dm_quick_ops_sheet.dart`
- Modify: `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_event_dispatcher.dart`
- Modify: `apps/client_flutter/test/dm_quick_ops_sheet_test.dart`
- Modify/add: dispatcher tests and server runtime-command tests when required

**TDD**

1. Add tests for distinct damage and healing modes using positive input.
2. Add tests for granting an item and a structured condition.
3. Verify each operation updates character state and emits a campaign event/chat
   system message through the existing dispatcher.
4. Replace signed-delta wording with a mode selector and numeric amount.
5. Add a target-first condition flow; do not introduce combat state.

**Acceptance**

- DM can damage, heal, grant an item, grant a condition, and make a quick roll.
- The same operation path updates data and campaign history.

## Task 8: Campaign Cards, Settings, And Material 3 Cleanup

**Files**

- Modify: `apps/client_flutter/lib/src/features/campaigns/presentation/campaigns_tab_page.dart`
- Modify: campaign card widget tests
- Modify: `apps/client_flutter/lib/src/features/server_home/presentation/settings_tab_page.dart`
- Modify: related settings section widgets and preference tests
- Modify: `apps/client_flutter/lib/src/app/theme/app_theme.dart` only when a
  missing shared token/component theme is proven

**TDD**

1. Test compact collapsed campaign cards and a coherent expanded action area.
2. Test settings order and persistence of every visible preference.
3. Remove or hide no-op settings and unfinished campaign actions.
4. Audit touched screens for semantic colors, theme text styles, 8 dp spacing,
   48 dp targets, responsive constraints, and absence of nested cards.

**Acceptance**

- Visible controls have working consumers.
- Layout remains usable at narrow phone and wide desktop widths.

## Task 9: Verification And Test Build

1. Run targeted tests after every task.
2. Run:
   - `npm run lint:server`
   - Flutter analyze
   - all Flutter tests
   - all server tests
3. Run `npm run doctor` as the final version gate.
4. Build the private-content web test package using the repository's supported
   script, without committing private source content.
5. Start the local server and preview, then inspect desktop and mobile layouts
   with browser screenshots.
6. Report the URL, exact test totals, residual risks, and any deliberately
   deferred work.

