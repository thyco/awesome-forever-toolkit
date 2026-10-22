# Awesome Forever Toolkit

One addon for shared WoW Forever utilities and class assistance. Version 0.1.0 targets interface **16001**. Includes Utilities, Warrior assistance and Gamepad bindings with shared button discovery, client helpers, visuals and configuration controls.

## Install

1. Build with `python3 scripts/package.py`, or use the generated `dist/AwesomeForeverToolkit-0.1.0.zip`.
2. Extract into `Interface/AddOns`, producing `AwesomeForeverToolkit/AwesomeForeverToolkit.toc`.
3. Disable **Utils Assist Forever** and **Warrior Assist Forever**. If either is loaded, the toolkit suppresses the matching module for that session; disable the old addon and reload to activate its replacement.
4. Enable **Awesome Forever Toolkit** and restart the client if it does not appear.
5. Click the thumbs-up beside the minimap, type `/aft` or `/af`, or use the launcher under Settings → AddOns.

Settings start fresh. No legacy settings are imported or modified. The original addon repositories remain independent.

Local regression tests pass; **in-game validation is still required**, particularly native gamepad transitions and taint behavior. See [the client checklist](docs/client-validation.md).

## Configuration

The movable standalone window has these pages:

- **General:** show/hide the minimap button. Drag that button around the minimap to reposition it.
- **Action bars:** range checks, queued attack highlights, cooldown/unusable greying and click-through.
- **Graphics:** grass and ground-effect density with a reset to the client-reported default.
- **Warrior → Reminders & glows:** select Battle Shout, Overpower, Revenge, Execute, Victory Rush or Shield Block; only the selected feature's controls are shown.
- **Warrior → Stance indicator:** current stance icon, shield corner and positioning.
- **Your class → Gamepad bindings:** A/B/X/Y assignments and Base/form profiles. Available on every class, after the shared pages.

Warrior pages appear only on Warriors with the module active. The last available page is remembered per character. Reminder location selectors save standard bar/button and native gamepad page/set/button separately; the current input mode determines which selection is used. Gamepad bindings use a separate page under your current class.

Changes to Warrior settings, including moving its icons, mark the footer **Apply & Reload**. X, Escape and the footer request that reload before hiding the window. A cancelled color edit still requires a reload if a change was applied during the session. Unchanged settings close normally. Page switching does not reload.

Configuration cannot open in combat. Entering combat hides it and clears previews; pending reload status survives until reopening and closing outside combat. Utility and graphics controls retain their existing combat restrictions.

## Features and scope

Utilities retain:
- Explicit out-of-range tinting, including native Blizzard gamepad ability bars.
- Queued next-swing borders for supported spells/macros.
- Real-cooldown and unusable-action greying, optional resource shortages and pet actions.
- Click-through on any of eight standard bars; hold Shift outside combat to interact.
- Account-wide ground-effect density control, leaving it untouched until explicitly configured.
- Range and cooldown/unusable coloring on the toolkit’s own gamepad overlays.

Warrior retains Battle Shout tracking and reminders; Overpower, Revenge, Execute, Victory Rush and Shield Block glow rules; the stance icon and shield corner; native gamepad page/stance replacement handling; preview actions; and restricted-value protections. Defaults and trigger rules follow Warrior 0.9.6 and Utils 0.6.0.

Hunter and Paladin assistance have not been migrated. Their existing addons may remain installed. Gamepad bindings are integrated; disable the standalone Gamepad Assist Forever when using the toolkit. There is no compatibility layer or old-settings migration for it.

## Commands

- `/aft`, `/af`, `/aft config`: open or raise the window.
- `/aft status`: module status, including any duplicate-addon guard.
- `/aft warrior`: Warrior diagnostics.
- `/aft gamepad` or `/aft gamepad config`: open Gamepad bindings.
- `/aft gamepad on|off|status|log`: activate saved bindings, disable overrides, or inspect diagnostics.
- `/aft gamepad set A context|always <spell ID or spell link>` and `/aft gamepad set A native`: edit the Base profile; replace A with B, X or Y as needed.
- `/aft utilities`: range/cooldown diagnostics.
- `/aft utilities clicky 1-8|all`: make selected bars clickable.
- `/aft utilities noclicky 1-8|all`: enable click-through.
- `/aft utilities status`: print click-through state.

The old `/uaf`, `/waf`, `/gaf` and `/bnc` aliases are not registered by this addon.

## Gamepad bindings

Open **Your class → Gamepad bindings**, alongside your spellbook or `/macro`. Drop a spell or macro onto A, B, X or Y. A new drop chooses **Context**, unless that button already uses **Always**.

- **Native** restores Blizzard behavior while remembering the assignment. **Clear** removes the Base assignment.
- **Context** uses the assignment in combat or with a living hostile target. Hostile mouseover is considered only without a selected target; a friendly or dead selected target prevents that fallback.
- **Always** uses it without requiring combat or a target. Triggers, shoulder modifiers, native stance and possess layers still take priority.
- **Profile** cycles Base and known stance/form profiles for editing; it does not switch your current form. A form without its own choice inherits Base. **Native** explicitly restores Blizzard behavior for that form; **Base** removes the form override and restores inheritance.
- **Enable overrides** controls saved activation. Assignments and activation survive reload. Temporary unavailable macros or layout do not erase the preference.

Spells use the existing target/mouseover rules; macros keep their own targeting and castsequence rules. Macro names must be unique across account and character macros. After renaming a macro, assign it again. Items and flyouts are unsupported. Configuration is locked during combat; macro/form data updates are deferred until combat ends.

The overlay is visual only. Test with the physical controller; clicking it with a mouse still reaches the native button. When assigning A permanently, bind jump elsewhere. Controller Rebound must be disabled because it claims the same buttons. Starting with no assignments via `/aft gamepad on` retains the original quick-start behavior: it copies the spell from page 1, LT+X to A in Context mode.

## Saved settings

`AwesomeForeverToolkitDB` stores account-wide Warrior and graphics preferences. `AwesomeForeverToolkitCharacterDB` stores utility preferences, UI state and gamepad assignments/activation per character. Module subtrees are validated independently.

## Development

```sh
python3 tests/run.py
python3 tests/syntax.py
python3 tests/package.py
```

Each Lua test file runs in its own process against mocked client APIs. The bundled glow-library integration test also executes the actual library. [Regression provenance](docs/test-provenance.md) documents the migrated coverage. Tests and packaging do not depend on the old repositories.

The approved PNG and its generation prompt live under `artwork/`. `python3 scripts/prepare_icon.py` regenerates the 256×256 RGBA TGA using Pillow. The checked-in TGA means Pillow is unnecessary to install or package the addon. Distribution zips are build outputs and are ignored by Git.

## Attribution

Feature code derives from the author's Warrior Assist Forever and Utils Assist Forever projects. Utils' click-through behavior derives from BarNoClicky by mostlyharmlessx; cooldown greying adapts GreyOnCooldown behavior. LibCustomGlow and LibStub are bundled with their original notices; see `AwesomeForeverToolkit/Libs/`. Source-library formatting is preserved.
