# Native quest tracker combat baseline

User-approved goal: enhance Blizzard's existing tracker, never create or replace it. Work remains on codex/native-quest-tracker. The full goal includes tags, sorting, grouping, filters, scrolling, all/tracked selection and TomTom.

## First testable increment

- Opt-in Quests module and Quest tracker settings before class pages.
- Level and E/D/R type prefixes on existing native quest headers; preserve Blizzard's original title/color formatting and restore on disable.
- Add an addon-owned quest-count label beside the native quest header.
- Observe native updates with secure post-hooks. No replacement of Update, GetContentsHeight, BuildQuestWatchInfos, EnumQuestWatchData or click methods; no reparenting or layout state writes.
- Defer native text changes and new hooks until out of combat. Native objective progress remains Blizzard-controlled during combat.
- Suppress this module when QuestTagsForever is loaded, matching other toolkit legacy modules.
- Development-only slash test: explicitly arm with /aft quests debug on; /aft quests test runs the addon refresh path and requests the engine's normal SortQuestWatches API. Never invoke tracker Update or MarkDirty from addon code. Log observed native updates; if no update is observed the request did not exercise the native path. This is not a synthesized PLAYER_LEVEL_UP event or proof of taint safety.
- Automated tests cover decoration, idempotence/restoration, pooled headers, combat deferral, late native load, opt-in/legacy exclusion and diagnostic gating. Existing suite/syntax/package must pass before commit.

## Client validation gate

Disable QuestTagsForever and reload before enabling this module. Test quest progress/completion, normal refresh and combat refresh; compare observed native update counts. A real combat level-up remains necessary. The first baseline must be validated in-game before implementing layout-changing features. Sorting/grouping/filtering/scrolling/all-quests/TomTom remain pending, not silently replaced by another tracker or declared complete.

## Baseline verification

Independent review identified prefix wrapping after native layout. Decorations now revert when they change measured header height; a regression test failed before the fix and passes after it. Full validation passes: 49/49 test files, syntax for 144 Lua files, package validation for 93 files, and git diff --check. In-game rendering and combat level-up validation remain pending.
