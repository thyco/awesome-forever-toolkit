# Gamepad integration implementation plan

> Implement inline using the executing-plans workflow, then obtain one independent review.

## Approved design

Integrate Gamepad Assist Forever 0.7.0's active overlay implementation into Awesome Forever Toolkit. Preserve A/B/X/Y secure routing, native fallback, context/always/native modes, macros, Base and stance profiles, and persisted activation. Put Gamepad bindings beneath the current class in the shared standalone window, after general pages. Use fresh per-character toolkit settings; never import or modify old addon settings. The original repository remains untouched. Commit all changes; do not push.

## Architecture and constraints

- Add Modules/Gamepad/{Module,Config,OverlayLogic,ActionModel,OverlayVisual,OverlayRuntime,ConfigurationActions,Pages}.lua. Runtime and action logic are shared across classes; only the page heading is class-specific.
- Store assignments and enabled flags in AwesomeForeverToolkitCharacterDB.gamepad. Legacy GamepadAssistForever disables this module through the existing duplicate-addon guard.
- Start listeners only when the module starts. Use uniquely named AFT secure routers. Keep the secure snippet/attribute contract and target semantics unchanged.
- Expose visual descriptors through the module, not a legacy global. Utilities prefer this provider when active, retaining the external legacy provider when the module is suppressed.
- Reuse the existing editor's callbacks within the shared scroll frame, adapt dimensions and English copy, and remove both old configuration surfaces. /aft gamepad opens this page; subcommands retain behavior. No /gaf registration.
- Preserve existing custom settings and unrelated files. Maintain blank lines between logical blocks.

## Review focus

1. Both addons loaded: no competing secure bindings, legacy global replacement, or legacy settings writes.
2. Missing gamepad APIs/layout: toolkit login and other pages still work; saved enabled choices restore when ready.
3. Combat and modifiers: no secure mutation in combat; native fallback and held-key routes remain unchanged.
4. Class UI: non-Warriors get their own class heading without activating Warrior; all class pages stay last.
5. Visual ownership: integrated provider colors overlays and clears tint after stopping without leaking routers or settings.

## Tasks

- [ ] 1. Runtime and storage. Add integration tests for fresh settings, duplicate guard, missing layout, and class-independent activation. Run them RED. Port the active model/visual/runtime files, introduce module/config adapters, add TOC entries and command dispatch. Port active upstream behavioral suites, replacing only namespace/storage/lifecycle setup and obsolete migration expectation. Run gamepad and full suites; commit.
- [ ] 2. Shared editor and visual bridge. Test page placement and actual editor callbacks, command opening, combat gating and provider selection. Run RED. Adapt the existing editor to a 600px content frame, use English labels, expose one page for the player's class. Connect internal descriptors to Utilities while preserving external fallback. Run gamepad and full suites; commit.
- [ ] 3. Package and review. Update README, client checklist and provenance. Verify all Lua, all tests, reproducible ZIP, and unchanged upstream secure snippet/driver logic. Obtain independent review; fix substantive findings with failing regressions, rerun full checks and commit. Leave the current branch ready to push.

## Execution notes

Continue in the existing clean toolkit feature checkout, matching the user's established workflow. The user approved the scope and explicitly asked to proceed; no additional design approval is needed. Automated tests cannot establish real client secure-execution or taint behavior. No new dependency or WoW API is introduced by this migration.
