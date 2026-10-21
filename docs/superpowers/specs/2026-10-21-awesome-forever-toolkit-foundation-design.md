# Awesome Forever Toolkit: shared foundation, Utilities and Warrior

Date: 2026-10-21
Status: approved; phase-one implementation complete locally, pending client validation

## Purpose and agreed scope

Build one maintainable addon in /Users/collogt/Work/Projects/awesome-forever-toolkit. The primary goal is to fix shared behavior once, particularly native Blizzard gamepad support and configuration-window behavior.

Phase one includes a shared core, a standalone configuration window, a minimap launcher using the approved comic thumbs-up icon, all current Utils features, and all current Warrior features. Original repositories remain untouched. All new files and implementation changes are staged and committed in the new repository; the user pushes.

Settings migration is explicitly excluded at the user's request. Start with fresh defaults. Preserve the current distinction between account-wide Warrior/graphics settings and per-character utility preferences. There is no legacy settings importer, migration session, or requirement to load old addons.

Hunter, Paladin, and Gamepad Assist's binding overrides are later phases. Native Blizzard gamepad button discovery and Warrior glow placement are included now. These are distinct from binding overrides.

## Baseline and approach

Reference baselines inspected:

- Warrior commit d6d86ac: standalone settings window and reload-before-close behavior.
- Utils commit 9d609f2: existing gamepad UI support.
- Toolkit commit dac6cf4: approved icon and generation prompt.

At implementation start, check source working trees for newer changes and preserve applicable user edits. Do not assume Git HEAD alone represents the intended source.

The selected approach is one addon with shared infrastructure and separate feature modules. Keeping five independent addons in one repository would leave the difficult cross-addon maintenance largely intact. A wholesale rewrite of every feature would add regression risk without serving this first phase.

## Package and ownership

Proposed structure:

```text
AwesomeForeverToolkit/
  AwesomeForeverToolkit.toc
  Core/
  Services/
  UI/
  Modules/Utilities/
  Modules/Warrior/
  Media/
  Libs/
tests/
artwork/
```

The manifest loads libraries, core and shared services, modules, UI, then startup in a deterministic order. Match the source addons' current client target (interface 16001) unless verified client requirements change.

Core owns startup, module registration and configuration storage. Each module owns its domain rules and declares its settings and pages. Avoid one giant global feature namespace: module-local state must remain separate.

Shared services own safe client reads, standard/native-gamepad button discovery, glow presentation, and reusable settings controls. A display-location selector uses the same button catalog as the runtime. Class rules request presentation through the shared services instead of implementing frame lookup themselves.

Utilities owns range checks, cooldown/unusable/resource greying, pet-action greying, queued next-swing highlights, click-through, and graphics controls. Preserve its external GamepadAssistForeverVisuals bridge so the existing standalone Gamepad addon continues to work during this phase.

Warrior owns Battle Shout reminders, Overpower, Revenge, Execute, Victory Rush, Shield Block, the stance indicator, and shield-corner presentation. Preserve the current trigger rules, defaults, diagnostic information and native gamepad behavior.

Do not force unlike services into one algorithm. Proc glows and queued-attack borders retain their separate effects and lifecycles behind shared presentation ownership. Shared discovery must support both enumerating utility targets and resolving a class feature's selected location.

Only the Warrior module activates on Warriors. General utilities remain available on every class. Disabled features release their own visuals and stop unnecessary work; one feature must not clear another feature's output. Preserve established polling intervals and event behavior initially rather than combining every update loop.

## Configuration window

Use one movable, screen-clamped standalone window, based on Warrior's current implementation. A left sidebar selects a page; the right content region scrolls independently; a fixed footer owns closing and reload status.

Phase-one navigation:

- General: minimap button visibility and general UI preferences.
- Action bars: range, cooldown/unusable greying, queued highlights and click-through.
- Warrior, on Warriors:
  - Reminders & glows: compact selector for Battle Shout and each reactive ability.
  - Stance indicator: icon and shield-corner controls.
- Graphics: grass and ground-effect density.

Do not show empty Hunter, Paladin or Gamepad bindings pages. When binding overrides are migrated later, Gamepad bindings belongs beneath the current class, never as a top-level sidebar page.

A selected reminder shows its enable switch and trigger description, applicable display-location controls, appearance controls, and supported preview action. Standard action-bar and gamepad selections remain separately saved. Preserve Warrior's existing input-mode selection semantics; this refactor must not silently change which bars glow.

Use shared controls for labels, checkboxes, choices, colors, feature selection and display locations. Lay out sections from their content instead of repeating large absolute vertical offsets. Feature-specific controls, such as Overpower's stance colors, remain part of that feature.

Remember the last valid page per character, falling back to General if unavailable. All UI text uses Awesome Forever Toolkit branding.

## Entry points and window lifecycle

Use /aft as the primary command, with /af as a convenience alias. Both open the same window; /aft status supplies diagnostics. The Blizzard AddOns settings entry contains only a launcher.

The minimap button uses the approved icon, opens or raises the configuration window, supports dragging around the minimap, and has a descriptive tooltip. Save its position and visibility per character. Hiding it never removes slash-command access. Generate a client-compatible texture from the approved source asset and keep that source under artwork.

All entry points call the same window controller. No configuration opening or reload in combat. If combat begins while open, hide the window, clear previews safely, and retain any pending reload requirement. Reopening after combat must preserve that requirement.

Preserve Warrior's tested close behavior:

- Custom controls save directly; do not join Blizzard's settings commit queue.
- No-op assignments do not mark the session changed.
- Warrior changes, including icon position edits, mark a reload required.
- Reverting a changed color does not clear that requirement.
- X, Escape and the footer all use the same close function.
- With a pending reload, call ReloadUI while the window is still visible, before its normal hide/cleanup path, and request it only once.
- Without a pending reload, clear previews and close normally.
- Changing pages does not reload.
- Footer says Close or Apply & Reload according to that state.

Utility and general changes retain immediate application where already supported; protected changes retain their existing combat deferral. The shared controller tracks reload requirements explicitly so utility edits cannot erase a Warrior requirement.

These code-level safeguards are a regression baseline, not proof of absence of taint. Native client testing remains required.

## Storage, coexistence and error behavior

Use versioned AwesomeForeverToolkitDB for account-wide data (Warrior and graphics) and AwesomeForeverToolkitCharacterDB for per-character data (utilities and UI state). Separate module subtrees and validators prevent setting-name collisions. Missing or invalid values get the corresponding current module default. Do not read or write legacy databases.

The installation instructions require disabling Utils Assist Forever and Warrior Assist Forever when their replacements run. If either legacy addon is loaded, suppress the matching toolkit module for that session and show a clear status explaining that it can start after the old addon is disabled and the UI reloaded. This is a duplicate-runtime guard, not a migration workflow. Do not disable other addons automatically.

Retain client restricted-value handling and combat checks from the reference implementations. Missing native gamepad UI makes its targets unavailable without breaking standard-bar utilities or the settings window. Failed previews report a useful reason and leave saved selections intact.

## Validation and acceptance

Adapt the existing meaningful Lua regression tests to the new structure; keep assertions about behavior rather than filenames. Cover:

- Fresh defaults, invalid values, module isolation and account/character scope.
- Warrior features and utility behavior from both existing suites.
- Native gamepad page/set/button selection, input-mode changes, missing or restricted frames and supported previews.
- Shared discovery used by both modules and ownership of overlapping visual effects.
- Window close paths, reload-before-hide, reverted colors, no-op edits, combat interruption and page switching.
- Minimap visibility/position and consistent launcher behavior.
- Non-Warrior startup and duplicate-addon guards.
- The external Gamepad overlay bridge.

Run Lua syntax checks, relevant migrated regression suites and packaging checks. Package one installable AwesomeForeverToolkit folder, retaining bundled library license notices. Tests and packaging must not require old source repositories at runtime.

Document a focused in-game checklist: install with old overlapping addons disabled; configure keyboard and native gamepad locations; test stance/page changes and glows in combat; edit colors and positions; close through X/Escape/footer; enter combat with the window open; reload and verify saved preferences; move/hide/reopen through the minimap launcher; check for blocked-action/taint errors.

Report local automated results separately from in-game checks that require the user's client. Phase one is implementation-complete only when the scoped addon and local checks are ready; client validation limitations must remain explicit.

## Next step

After review of this written design, prepare a concrete implementation plan with commit-sized steps and validation commands. Review that plan before implementation, as required by the active architectural workflow.
