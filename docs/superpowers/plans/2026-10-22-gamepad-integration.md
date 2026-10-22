# Gamepad integration implementation plan

> Implement inline using the executing-plans workflow, then obtain one independent review.

## Approved design

Integrate Gamepad Assist Forever 0.7.0's active overlay implementation into Awesome Forever Toolkit. Preserve A/B/X/Y secure routing, native fallback, context/always/native modes, macros, Base and stance profiles, and persisted activation. Put Gamepad bindings beneath the current class in the shared standalone window, after general pages. Use fresh per-character toolkit settings; never import or modify old addon settings. The original repository remains untouched. Commit all changes; do not push.

## Architecture and constraints

- Add Modules/Gamepad/{Module,Config,OverlayLogic,ActionModel,OverlayVisual,OverlayRuntime,ConfigurationActions,Pages}.lua. Runtime and action logic are shared across classes; only the page heading is class-specific.
- Store assignments and enabled flags in AwesomeForeverToolkitCharacterDB.gamepad. No old-addon compatibility or migration handling, per the user correction during execution.
- Start listeners only when the module starts. Use uniquely named AFT secure routers. Keep the secure snippet/attribute contract and target semantics unchanged.
- Expose visual descriptors through the module, not a legacy global. Utilities use only this internal provider.
- Reuse the existing editor's callbacks within the shared scroll frame, adapt dimensions and English copy, and remove both old configuration surfaces. /aft gamepad opens this page; subcommands retain behavior. No /gaf registration.
- Preserve existing custom settings and unrelated files. Maintain blank lines between logical blocks.

## Review focus

1. Fresh character settings: no unwanted activation or writes to any old settings/global.
2. Missing gamepad APIs/layout: toolkit login and other pages still work; saved enabled choices restore when ready.
3. Combat and modifiers: no secure mutation in combat; native fallback and held-key routes remain unchanged.
4. Class UI: non-Warriors get their own class heading without activating Warrior; all class pages stay last.
5. Visual ownership: integrated provider colors overlays and clears tint after stopping without leaking routers or settings.

## Tasks

- [x] 1. Runtime and storage. Add integration tests for fresh settings, missing layout, and class-independent activation. Run them RED. Port the active model/visual/runtime files, introduce module/config adapters, add TOC entries and command dispatch. Port active upstream behavioral suites, replacing only namespace/storage/lifecycle setup and obsolete migration expectation. Run gamepad and full suites; commit.
- [x] 2. Shared editor and visual bridge. Test page placement and actual editor callbacks, command opening, combat gating and provider selection. Run RED. Adapt the existing editor to a 600px content frame, use English labels, expose one page for the player's class. Connect internal descriptors to Utilities without external fallback. Run gamepad and full suites; commit.
- [x] 3. Package and review. Update README, client checklist and provenance. Verify all Lua, all tests, reproducible ZIP, and unchanged upstream secure snippet/driver logic. Obtain independent review; fix substantive findings with failing regressions, rerun full checks and commit. Leave the current branch ready to push.

## Execution notes

Continue in the existing clean toolkit feature checkout, matching the user's established workflow. The user approved the scope and explicitly asked to proceed; no additional design approval is needed. Automated tests cannot establish real client secure-execution or taint behavior. No new dependency or WoW API is introduced by this migration.

Task 1: runtime/config and migrated behavioral suites pass (33/33 files), committed 88b5cbb. The active secure snippet and action preparation logic are preserved; the obsolete automatic migration test now checks that missing enabled flags stay off.

Task 2: the user removed old-addon compatibility from scope after task 1. Removed Gamepad duplicate detection, optional dependency and legacy visual fallback. Shared editor is adapted to 600px and scales on narrower windows, English labels and diagnostics, class grouping and /aft gamepad navigation. Existing editor callbacks and direct internal overlay bridge tests pass. The full suite passes 34/34 files.

Task 3: independent review of 2b27679..fd43a91 found one Important startup issue: Enable overrides on fresh settings without gamepad APIs faulted the module until reload. Reproduced through the actual editor (RED), guarded quick-start API/layout readiness (GREEN), and reran the full suite (34/34). Reviewer independently inspected the follow-up and reran the integration test; approved with no remaining substantive findings or deferred minors. Reviewer additionally checked editor/cache reuse on all 13 class tokens.

Verification: 34/34 Lua test files, 89 Lua syntax files, 56-file reproducible package, and git diff --check pass. OverlayLogic (secure snippet, routing and condition drivers) matches upstream exactly after the namespace header. Source Gamepad repository remains untouched.

Review limits and decisions: physical controller delivery, secure execution/taint, and rendered UI/scale cannot be proved by mocks; follow the updated client checklist before declaring those validated. Old-addon coexistence and migration remain deliberately out of scope per user instruction. Preserved upstream algorithms are covered by their migrated suites and source comparison, not a new redesign. Package reproducibility was verified by the implementer, though the read-only reviewer did not rebuild it. Continuing in the current feature checkout preserves the user's established commit-and-push workflow; no other implementation worker edited it. No push or merge performed.
