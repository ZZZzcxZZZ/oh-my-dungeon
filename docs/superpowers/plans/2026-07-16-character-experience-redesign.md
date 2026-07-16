# Character Experience Redesign Implementation Plan

> Design source: `docs/superpowers/specs/2026-07-16-character-experience-redesign.md`

## Goal

Deliver a focused offline-first character workflow with four outcomes:

1. Rules automatically grant level features and drive required choices.
2. Character sheets support quick edits for features, spells, equipment, and profile data.
3. Level-up is a short guided flow that commits atomically.
4. Character lists offer comfortable and compact Material 3 layouts.

The first delivery excludes multiclassing, inventory containers, party inventory,
portrait decoration, and other nonessential customization.

## Task 1: Manual Overrides And Quick Edit Domain

**Files**

- Create: `apps/client_flutter/lib/src/features/characters/domain/character_profile.dart`
- Create: `apps/client_flutter/lib/src/features/characters/domain/character_manual_overrides.dart`
- Create: `apps/client_flutter/lib/src/features/characters/domain/character_override_resolver.dart`
- Create: `apps/client_flutter/lib/src/features/characters/domain/character_quick_edit_service.dart`
- Test: `apps/client_flutter/test/character_manual_overrides_test.dart`
- Test: `apps/client_flutter/test/character_quick_edit_service_test.dart`

**Steps**

1. Write failing JSON round-trip tests for profile and manual overrides.
2. Write failing tests proving manual additions coexist with automatic grants and
   hidden grants remain recoverable.
3. Write failing tests for adding/removing/preparing spells and updating profile
   text without losing runtime, inventory, or unknown `data` fields.
4. Implement immutable parsers and `CharacterOverrideResolver`.
5. Implement `CharacterQuickEditService`; keep `CharacterSheet.notes` synchronized
   with `profile.privateNotes` for backward compatibility.
6. Run focused tests and `flutter analyze` on the new domain files.

## Task 2: Level-Up Planner And Guided Upgrade

**Files**

- Create: `apps/client_flutter/lib/src/features/characters/domain/character_upgrade_planner.dart`
- Create: `apps/client_flutter/lib/src/features/characters/presentation/character_upgrade_page.dart`
- Modify: `apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart`
- Modify: `apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- Test: `apps/client_flutter/test/character_upgrade_planner_test.dart`
- Test: `apps/client_flutter/test/character_upgrade_page_test.dart`

**Steps**

1. Write failing planner tests for fixed grants, pending choices, validation, and
   preservation of manual state.
2. Build an independent upgrade draft for exactly the next level; derive all
   grants and choices from imported rule entries.
3. Reject confirmation while required choices are unresolved.
4. Apply the complete draft atomically through the existing character update
   path, preserving runtime, inventory, currency, profile, overrides, and notes.
5. Build a compact Material 3 stepper-style page that displays only decisions
   relevant to the target level plus a final summary.
6. Add a level-up command to character detail and list surfaces.

## Task 3: Six-Section Character Sheet And Quick Editing

**Files**

- Modify: `apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart`
- Modify: `apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- Test: `apps/client_flutter/test/character_pages_test.dart`

**Steps**

1. Add failing widget tests for the six destinations: Overview, Actions, Spells,
   Equipment, Features, and Profile.
2. Replace the separate runtime/details/notes destinations: runtime belongs in
   Overview, while biography and private notes belong in Profile.
3. Pass the local content catalog and a generic character save callback into the
   detail page so all non-campaign editing remains offline.
4. Add focused Material 3 bottom sheets:
   - Features: add from library or create a custom feature; hide/restore rule grants.
   - Spells: add/remove and toggle prepared state.
   - Equipment: add from library or custom, edit quantity/equipped/attuned, delete.
   - Profile: edit appearance, personality, ideals, bonds, flaws, backstory,
     languages, and private notes with debounced local save.
5. Refresh the visible sheet only after a successful save and show recoverable
   errors with `SnackBar`.

## Task 4: Character List Summary

**Files**

- Modify: `apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- Test: `apps/client_flutter/test/widget_test.dart`

**Steps**

1. Keep each character as a compact, tappable Material 3 card that opens the
   complete character sheet.
2. Add an independent trailing expand control; it must not navigate.
3. Show HP, AC, initiative, passive perception, conditions, one primary class
   resource, and contextual quick actions only in the expanded section.
4. Do not persist a separate list-density preference or show a layout switch.
5. Verify both expansion and navigation in widget tests, including narrow
   viewports and long names.

## Task 5: Creation Flow Refinement

**Files**

- Modify: `apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- Modify existing builder/domain files only where rule metadata requires it.
- Test: `apps/client_flutter/test/character_pages_test.dart`
- Test: `apps/client_flutter/test/guided_character_builder_test.dart`

**Steps**

1. Add failing tests for the 2024 order: class, background, species, abilities,
   proficiencies, equipment, spells, details, review.
2. Hide steps that have no applicable decision and mark visible steps complete,
   pending, or blocked.
3. Ensure class levels automatically project fixed features and only request
   legal spells/equipment/options supplied by the active content library.
4. Make quick creation apply valid recommendations and lead to the same final
   rules projection as guided creation.
5. Keep manual edits available after creation through the character sheet.

## Task 6: Verification And Preview

1. Run `dart format` on changed Dart files.
2. Run focused tests after each task.
3. Run `flutter analyze` and the full Flutter test suite.
4. Run the web release build.
5. Confirm `http://127.0.0.1:5173/` returns HTTP 200 and inspect desktop/mobile
   screenshots for blank pages, overflow, navigation, and edit flows.
6. Update execution-status documentation with only features actually verified.

## Acceptance Criteria

- Automatic rule grants and manual overrides are separate, deterministic, and
  survive save/reload.
- A user can complete a legal next-level upgrade without editing JSON.
- Features, spells, equipment, profile, and private notes are editable directly
  from the sheet while offline.
- The detail page has exactly six clear sections and follows Material 3 controls.
- Character list density persists independently of global compact-list settings.
- Existing campaign/chat behavior and server contracts do not regress.
- Analyze, tests, web build, and preview checks pass before declaring completion.
