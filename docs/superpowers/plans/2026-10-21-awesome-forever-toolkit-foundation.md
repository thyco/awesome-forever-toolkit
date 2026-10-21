# Awesome Forever Toolkit Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution, or superpowers:subagent-driven-development if the user selects delegated execution. Steps use checkbox syntax for tracking.

**Goal:** Deliver one installable addon containing the shared foundation, Utilities and Warrior, with a standalone configuration window and minimap launcher.

**Architecture:** One manifest loads shared services and isolated module namespaces. Modules retain their feature rules and event cadence; shared button discovery, glow presentation and UI controls remove duplicated infrastructure. The existing Gamepad binding addon remains external.

**Tech Stack:** Lua, WoW Forever interface 16001, bundled LibStub/LibCustomGlow, Python packaging and texture conversion, mocked-client Lua regression tests.

**Spec:** ../specs/2026-10-21-awesome-forever-toolkit-foundation-design.md (approved 2026-10-21).

## Global constraints

- Work in /Users/collogt/Work/Projects/awesome-forever-toolkit; original repositories remain untouched.
- Stage and commit all new files and implementation changes. The user pushes.
- Fresh defaults only: no settings migration or reads/writes of legacy databases.
- Account storage: AwesomeForeverToolkitDB. Character storage: AwesomeForeverToolkitCharacterDB.
- Warrior and graphics remain account-wide; utilities and UI state remain per-character.
- Preserve Warrior's reload-before-hide behavior, native gamepad selection semantics and restricted-value protections.
- Preserve Utilities' supported button coverage and GamepadAssistForeverVisuals bridge.
- Bindings UI belongs under the class when implemented in a later phase. No empty binding pages now.
- Primary command /aft; convenience alias /af; status command /aft status.
- Preserve bundled licenses. No added runtime dependency beyond bundled libraries and the client.
- Separate logical blocks with blank lines, including test arrangement, action and assertions.
- If Java is introduced, no var and no @ParameterizedTest. No Java is needed here.
- In-game taint validation is distinct from mocked tests and cannot be claimed from their results.

## Review focus

1. Native gamepad frames appear after startup or are replaced: discovery must find current frames and not retain stale highlights (Task 2).
2. Combat interrupts a changed configuration session: no reload occurs in combat; pending reload survives reopening (Task 6).
3. A non-Warrior logs in with remembered Warrior navigation: fall back to General while utilities continue (Tasks 1 and 6).
4. A color edit is cancelled after live application: restored color still leaves the session requiring reload (Task 6).
5. One visual owner stops while another remains on the same button: the remaining effect must survive (Tasks 3 and 8).

## Files and responsibilities

All paths below are relative to the new repository.

- AwesomeForeverToolkit/AwesomeForeverToolkit.toc: runtime load order and saved-variable declarations.
- AwesomeForeverToolkit/Core/Addon.lua: shared namespace and module registration.
- AwesomeForeverToolkit/Core/Config.lua: validated scoped stores and change subscriptions.
- AwesomeForeverToolkit/Core/Bootstrap.lua: login order, duplicate-addon guards, commands and diagnostics.
- AwesomeForeverToolkit/Services/Client.lua: union of current safe-read helpers, with identical-name differences reconciled by tests.
- AwesomeForeverToolkit/Services/Buttons.lua: standard/native gamepad enumeration and selection.
- AwesomeForeverToolkit/Services/Glow.lua: Warrior proc-glow lifecycle and owner arbitration.
- AwesomeForeverToolkit/UI/Window.lua: open/close/reload state, sidebar and active content.
- AwesomeForeverToolkit/UI/Widgets.lua: common controls and vertical layout.
- AwesomeForeverToolkit/UI/DisplayLocation.lua: shared keyboard and native-gamepad selector.
- AwesomeForeverToolkit/UI/Minimap.lua: launcher and saved placement.
- AwesomeForeverToolkit/UI/Pages.lua: page registration and General page.
- AwesomeForeverToolkit/Modules/Utilities/{Module,Config,Pages}.lua: utility namespace, scoped configuration, page definitions.
- AwesomeForeverToolkit/Modules/Utilities/Services/: Macros.lua, NextSwing.lua, Range.lua, IconTint.lua, QueuedGlow.lua, Cooldown.lua, Graphics.lua.
- AwesomeForeverToolkit/Modules/Utilities/Features/: RangeCheck.lua, QueuedAttackGlow.lua, CooldownGrey.lua, GamepadOverlay.lua, BarClickThrough.lua.
- AwesomeForeverToolkit/Modules/Utilities/Runtime.lua: utility event/polling behavior.
- AwesomeForeverToolkit/Modules/Warrior/{Module,Config,Pages}.lua: Warrior namespace, configuration, page definitions.
- AwesomeForeverToolkit/Modules/Warrior/Services/: Stance.lua, StanceIcon.lua, ReactiveSpells.lua, Timers.lua, BattleShoutAura.lua, BattleShoutIcon.lua.
- AwesomeForeverToolkit/Modules/Warrior/Features/: BattleShoutReminder.lua, ReactiveAbilities.lua.
- AwesomeForeverToolkit/Modules/Warrior/Runtime.lua: Warrior event/diagnostic behavior.
- AwesomeForeverToolkit/Media/: Icon.tga and referenced Warrior artwork.
- AwesomeForeverToolkit/Libs/: one bundled LibStub/LibCustomGlow copy plus notices.
- tests/helpers.lua: shared runtime harness; tests/warrior/helpers.lua and tests/utilities/helpers.lua retain focused feature fixtures.
- tests/run.py: sorted recursive Lua test execution, excluding helper modules; failure exits nonzero.
- scripts/package.py: deterministic installable zip.
- scripts/prepare_icon.py: approved PNG to RGBA TGA conversion.
- README.md and docs/client-validation.md: install, commands, features and manual acceptance checks.

## Shared contracts

Use existing dot/colon conventions consistently. No method should close over another module's configuration.

- addon.modules: table keyed by Utilities and Warrior.
- addon.RegisterModule(id, module): rejects duplicate IDs.
- addon.Start(): initializes stores and UI, evaluates class/conflicts, then starts eligible modules once.
- module.Start(), module.Stop(), module.Diagnostics(): module runtime boundaries.
- addon.Config.NewStore(scope, id, defaults, validate, normalize): returns store with Get(key), GetDefault(key), Set(key, value), GetColor(key), Subscribe(callback). scope is account or character; Set returns true only for a changed value.
- addon.Config.GetSection(scope, id): returns the persisted table used by graphics/UI state.
- addon.Buttons.Bars(), Bar(index), Selected(bar, button), All(), CooldownAll(): preserve existing utility semantics; All includes native gamepad frames; CooldownAll returns entries with button/kind.
- addon.Buttons.Mode(), GamepadBars(), GamepadPositions(), GamepadCandidates(bar, button), GamepadSelected(page, bar, button): preserve Warrior behavior.
- addon.Buttons.SelectionLabel(config, kind): takes a store explicitly, replacing Warrior's implicit addon.Config access.
- addon.Glow retains Warrior's public API; consumers use globally unique owner IDs.
- addon.Window:RegisterPage(page): page fields id, label, parent, available(), build(parent), refresh(), clearPreview().
- addon.Window:Open(), Close(), ShowPage(id), Refresh(), MarkReloadRequired(): common lifecycle.
- addon.Window.controls: controls for the currently built page, keyed by namespaced setting key.
- addon.Window.settings: store-bound setting adapters used by widgets.
- addon.Widgets.Setting(store, key): returns GetValue/SetValue adapter.
- addon.DisplayLocation.Create(parent, store, kind): consumes shared catalog; creates the five selection controls and returns a refreshable group.
- addon.Minimap:Initialize(), Refresh(), SaveAngle(angle): manages button and character UI state.
- addon.ClearPreviews(): asks active modules to clear previews without touching protected actions.

## Task 1: Loadable core and isolated stores

**Files:** Create Core files, manifest, tests/helpers.lua, tests/core.lua, tests/config.lua, tests/run.py, and a minimal README.

- [ ] Inspect git status in all three repositories and any ancestor AGENTS.md. Record exact source revisions and uncommitted changes before copying. Use the worktree skill at execution time to determine whether isolation is needed; do not create an unnecessary second checkout of the empty project.
- [ ] Write core tests around registration, repeated Start, non-Warrior eligibility, and scoped storage. Adapt the mock environment from Warrior's tests/helpers.lua; load actual manifest files with loadfile(path, "t", env), skipping bundled library implementation in favor of the existing mock.
- [ ] Pin fresh-store behavior with executable assertions:

```lua
local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:loadManifest()
world:fire("PLAYER_LOGIN")

local defaults = { enabled = true }
local valid = function(_, value) return type(value) == "boolean" end
local first = addon.Config.NewStore("account", "first", defaults, valid)
local second = addon.Config.NewStore("character", "second", defaults, valid)

assert(first.Set("enabled", false))
assert(first.Get("enabled") == false)
assert(second.Get("enabled") == true)
assert(first.Set("enabled", false) == false)
assert(world.env.WarriorAssistForeverDB == nil)
assert(world.env.UtilsAssistForeverDB == nil)
```

- [ ] Run lua tests/config.lua and lua tests/core.lua; confirm failure comes from missing functionality before implementation.
- [ ] Implement scoped tables with schemaVersion = 1, copied defaults, validators/normalizers and listeners called only on changes. Reject unknown keys. A malformed module subtree is repaired without resetting unrelated subtrees.
- [ ] Add module-status tests for loaded Utils/Warrior legacy addons, ensuring corresponding module Start is not called, other modules still start, and status explains disabling/reloading. Use C_AddOns.IsAddOnLoaded through a safe helper at PLAYER_LOGIN.
- [ ] Implement registration/startup and command routing. Defer UI wiring until Task 6; do not leave manifest entries pointing to absent files.
- [ ] Run both tests and luac -p on created Lua files; commit: "Add toolkit core and scoped configuration".

## Task 2: Shared client helpers and button catalog

**Files:** Create Services/Client.lua, Services/Buttons.lua, tests/buttons.lua; extend tests/helpers.lua with gamepad fixtures.

- [ ] Read both Client.lua implementations fully and compare every shared function. Bring over the behavior needed by both modules, keeping restricted values out of comparisons/stringification.
- [ ] Port Warrior's native-gamepad tests and Utils' button-enumeration assertions into tests/buttons.lua. Add a setup where a gamepad frame appears after the first discovery and is replaced before a later one.
- [ ] Add a direct shared-contract test using helper world:button(name, slot) and world:gamepadBar(key, slots), copied from Utils:

```lua
local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:loadManifest()
local standard = world:button("ActionButton1", 1)

assert(addon.Buttons.Selected(1, 1) == standard)
assert(addon.Buttons.GamepadSelected(0, 1, 1) == nil)

local native = world:gamepadBar("topBar", { 10, 11 })
local seen = {}
for _, button in ipairs(addon.Buttons.All()) do
    assert(not seen[button])
    seen[button] = true
end

assert(seen[standard])
assert(seen[native[1]])
```

- [ ] Run lua tests/buttons.lua and confirm red.
- [ ] Merge discovery into the shared catalog: preserve eight standard bars, native normal/stance/possess coverage, pet classification, and optional supported third-party enumeration from Utils. Preserve Warrior's active-page check and stance override resolution.
- [ ] Replace the implicit config dependency in SelectionLabel with its explicit argument. Add malformed index, secret mode, missing page, replaced frames, and hidden stance cases from existing fixtures.
- [ ] Run lua tests/buttons.lua and core/config regressions; commit: "Share client compatibility and button discovery".

## Task 3: Shared proc-glow service

**Files:** Create Services/Glow.lua, Libs/, tests/glow.lua.

- [ ] Copy bundled libraries/notices after comparing versions; retain the tested Warrior proc-glow behavior, including reserved effects and geometry refresh. Review every method used by ReactiveAbilities and icons.
- [ ] Port the existing glow assertions and add two-owner arbitration:

```lua
local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:loadManifest()
local button = world:button("ActionButton1", 1)

addon.Glow.Prepare(button)
addon.Glow.ConfigureOwner("warrior:test", { priority = 10 })
addon.Glow.ConfigureOwner("other:test", { priority = 1 })
addon.Glow.Set(button, "warrior:test", true)
addon.Glow.Set(button, "other:test", true)
addon.Glow.Set(button, "warrior:test", false)

assert(world.glowActive[button] == true)
```

- [ ] Use the verified signature Glow.Set(button, owner, active, options), with options optional. Run lua tests/glow.lua before implementation and confirm the missing service failure.
- [ ] Implement the shared service using the current Warrior code, renaming its library key to AwesomeForeverToolkit and avoiding module-specific globals. Preserve preparation outside combat and behavior for unprepared buttons.
- [ ] Verify the second owner remains active, color changes do not restart intro flashes, ending combat cancels an intro as before, and disabling an owner never affects queued borders.
- [ ] Run glow and button tests; commit: "Centralize proc glow presentation".

## Task 4: Utilities module and regression suite

**Files:** Create all Utilities files listed in the file map except Pages.lua (Task 6); copy tests/utilities/ from the existing suite and adapt its loader.

- [ ] Copy the utility tests into the new repo, preserving assertions. Redirect dofile helper paths to tests/utilities/helpers.lua and manifest/module loaders to the new files.
- [ ] Run python3 tests/run.py tests/utilities and confirm failures identify missing module behavior.
- [ ] Introduce module-local namespace assignment at the start of each migrated module file:

```lua
local _, root = ...
local addon = root.modules.Utilities
```

- [ ] Register Utilities before loading its files; inject root.Client and root.Buttons. Preserve the module-local feature list, range state and icon tint coordination. Bind Config to the character utilities store using the original defaults/validators.
- [ ] Adapt Graphics.Initialize to root.Config.GetSection("account", "graphics"). Preserve no-write-before-selection, reset-to-client-default, locked CVar handling and delayed restoration.
- [ ] Move Bootstrap behavior into Runtime, with module.Start owning event registration. Replace SettingsPanel refresh calls with the root window Refresh callback once available, guarded during startup. Do not carry over the old settings panel or slash registration.
- [ ] Retain the external GamepadAssistForeverVisuals provider contract and guard malformed providers using the existing tests.
- [ ] Port diagnostics and click-through command behavior under /aft; document exact routing as /aft utilities <existing utility command>. Do not claim legacy slash names.
- [ ] Run python3 tests/run.py tests/utilities; include graphics, clickthrough, cooldown, next_swing, queued_glow, overlay_bridge and integration scenarios. Verify feature Stop paths release their own state.
- [ ] Commit: "Integrate utility features with shared toolkit services".

## Task 5: Warrior module and regression suite

**Files:** Create all Warrior files listed above except Pages.lua; copy tests/warrior/ feature fixtures and tests.

- [ ] Copy foundation, aura, feature, stance_icon, reactive_foundation, reactive_spells, reactive_feature, gamepad and integration tests. Redirect helper paths and module loads; retain behavior assertions.
- [ ] Run python3 tests/run.py tests/warrior and confirm red for missing module code.
- [ ] Add the Warrior namespace and inject shared Client, Buttons and Glow. Use account warrior Config with the exact current defaults and validators.
- [ ] Move domain services and features with the same namespace prelude as Utilities, using root.modules.Warrior. Preserve original spell IDs, aura fallbacks, cooldown/range rules, stance behavior and subscriptions.
- [ ] Replace Buttons.SelectionLabel(kind) calls with root.Buttons.SelectionLabel(addon.Config, kind). Namespace every proc owner ID. Preserve input-mode routing rather than adding simultaneous keyboard/gamepad activation.
- [ ] Move Bootstrap behavior into Runtime and expose Diagnostics through /aft warrior. Start only after the core class/conflict check; do not independently create an old settings panel.
- [ ] Copy referenced Warrior artwork and change only addon asset paths. Keep icon move/preview methods available for the shared window.
- [ ] Run python3 tests/run.py tests/warrior plus shared-service tests. Assert zero Warrior runtime activation on HUNTER while utility initialization remains possible.
- [ ] Commit: "Integrate Warrior reminders and native gamepad support".

## Task 6: Shared standalone settings UI

**Files:** Create UI/Window.lua, Widgets.lua, DisplayLocation.lua, Pages.lua and both modules' Pages.lua; create tests/settings.lua and tests/settings_close.lua.

- [ ] Port Warrior's settings_close.lua into the shared harness, then add page-switch, unsupported remembered-page and utility-only edit cases. Existing helper mocks must invoke OnShow/OnHide callbacks so lifecycle ordering is actually exercised.
- [ ] Add the reload-order assertion:

```lua
local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:loadManifest()
world:fire("PLAYER_LOGIN")
addon.Window:Open()

local visibleAtReload
world.env.ReloadUI = function()
    assert(not world.combat)
    visibleAtReload = addon.Window.canvas:IsVisible()
end

addon.modules.Warrior.Config.Set("overpowerEnabled", false)
addon.Window:Close()

assert(visibleAtReload == true)
```

- [ ] Run lua tests/settings_close.lua and lua tests/settings.lua before implementing the window.
- [ ] Build the standalone shell using Warrior's frame setup, explicit Escape handler, own close path and launch-only Blizzard settings entry. No shared Blizzard commit queue, no normal hide before a required reload, no reset of dirty status after cancellation.
- [ ] Implement page registration, availability filtering and ShowPage. Save the page in character ui storage, fall back to general, and clear only outgoing previews when switching. A page switch never calls Close.
- [ ] Reuse current safe widgets; add a vertical layout cursor to place successive sections without large repeated hardcoded offsets. Bind controls through Widgets.Setting(store,key). Return refreshable controls and retain color-picker cancel semantics.
- [ ] Implement DisplayLocation.Create from the shared Buttons labels. Build separate standard bar/button and gamepad page/set/button controls, including Not selected values. This UI does not change current input mode.
- [ ] Define module pages from existing setting groups. Warrior uses one selected feature at a time with relevant options and its existing preview method. Graphics retains live value, disabled reasons and reset-to-client-default.
- [ ] Subscribe Warrior changes to Window:MarkReloadRequired regardless of current page, including icon dragging. Utility/general edits do not erase that flag. Hook common ClearPreviews into close and combat-hide paths.
- [ ] Test X, Escape, footer, unchanged assignment, reverted color, icon position edit, combat interruption, repeated Close, page switches, missing gamepad UI, and missing Settings launcher API. The independent /aft window must remain usable if the optional launcher is unavailable.
- [ ] Run settings tests and both module suites; commit: "Add shared standalone configuration window".

## Task 7: Approved icon and minimap launcher

**Files:** Create UI/Minimap.lua, Media/Icon.tga, scripts/prepare_icon.py, tests/minimap.lua; update General page and manifest IconTexture.

- [ ] Read the approved PNG and preserve it. Add a repeatable conversion script using Pillow to produce a square 256x256 RGBA TGA; this is format/size conversion, not a redesigned image. Inspect output and a small thumbnail.
- [ ] Add launcher tests for click outside/inside combat, persisted drag angle, hide/reopen via slash command and missing Minimap. Example:

```lua
local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:loadManifest()
world:fire("PLAYER_LOGIN")

addon.Minimap:SaveAngle(450)
assert(addon.Config.GetSection("character", "ui").minimapAngle == 90)

addon.Config.GetSection("character", "ui").minimapHidden = true
addon.Minimap:Refresh()
assert(not addon.Minimap.button:IsVisible())

world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("")
assert(addon.Window.canvas:IsVisible())
```

- [ ] Run lua tests/minimap.lua and confirm red.
- [ ] Implement a nonsecure launcher button parented to Minimap, with tooltip, explicit click to Window:Open, and dragging based on cursor coordinates divided by effective scale. Normalize finite angles to [0,360); default to 225 degrees and visible. Missing Minimap skips launcher creation while commands continue working.
- [ ] Save minimapHidden and minimapAngle in character ui storage. General page controls refresh the launcher immediately. Do not use the same click to close an already open window: raise it instead.
- [ ] Test UI scale conversion and nonfinite saved angle normalization in addition to the cases above.
- [ ] Run minimap/settings suites and verify the converted image dimensions/alpha; commit: "Add comic icon and minimap configuration launcher".

## Task 8: Integration, packaging and delivery

**Files:** Create tests/integration.lua, tests/package.py, scripts/package.py, docs/client-validation.md; finish README.md and manifest.

- [ ] Add a real-manifest smoke test with both modules enabled. Assert there is one toolkit settings launcher, class availability is respected and repeated PLAYER_LOGIN cannot duplicate listeners or visuals.
- [ ] Exercise a standard action button with utility tint/queued border and a Warrior glow. Stop the Warrior owner and assert the utility effects remain; stop utilities and assert the remaining Warrior effect remains. Reuse existing mock observations instead of comparing internal implementation tables.
- [ ] Add package checks before implementing the packager: exactly one AwesomeForeverToolkit/ install root; all manifest paths exist; asset paths resolve; libraries and notices exist; no legacy addon folders, tests, research probes or absolute machine paths in the zip.
- [ ] Implement Python packaging with zipfile and pathlib, sorting paths and including only the installable addon tree. Output dist/AwesomeForeverToolkit-0.1.0.zip; keep distribution zip untracked via .gitignore while committing all source files, scripts and source/converted artwork.
- [ ] Document installation, old Utils/Warrior disablement, fresh defaults, /aft and /af, /aft status, utility/Warrior diagnostics, gamepad binding deferral, library attribution, and the in-game checklist from the approved spec.
- [ ] Run these commands from the repo root:

```sh
python3 tests/run.py
python3 scripts/package.py
python3 tests/package.py
git diff --check
```

Run syntax validation once per Lua file using Python subprocess.run(["luac", "-p", str(path)], check=True) over AwesomeForeverToolkit and tests. The runner invokes each Lua test in its own process from the repo root; a provided directory argument limits collection. Explicitly exclude helpers.lua.

- [ ] Inspect source for obsolete asset prefixes, old slash registration and legacy database references. Expected legacy addon names occur only in conflict detection and documentation; source provenance and tests may mention them deliberately.
- [ ] Request a whole-change review using the applicable review skill, fix actionable findings and rerun affected checks. Do not claim mocked tests establish taint-free client behavior.
- [ ] Commit: "Package toolkit foundation and document client validation". Verify git status is clean, summarize automated checks and outstanding in-game checks, and report commits. Do not push.

## Execution handoff

Recommended: inline execution in this chat, task by task, followed by whole-change review. These tasks share tightly coupled service and UI contracts; keeping the implementation context together should reduce integration overhead. Delegated execution remains available if the user prefers separate implementer/reviewer agents per task.

This plan contains no completed implementation claims. After the user's plan review and execution choice, follow the selected execution skill and keep task checkboxes current in committed updates.
