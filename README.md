# Awesome Forever Toolkit

One addon for shared WoW Forever utilities and class assistance. Version 0.1.0 targets interface **16001**. This first phase includes Utilities and Warrior with shared button discovery, client helpers, proc glows and configuration controls.

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

Warrior pages appear only on Warriors with the module active. The last available page is remembered per character. Reminder location selectors save standard bar/button and native gamepad page/set/button separately; the current input mode determines which selection is used. Gamepad spell/macro binding overrides are a later phase and have no empty settings page.

Changes to Warrior settings, including moving its icons, mark the footer **Apply & Reload**. X, Escape and the footer request that reload before hiding the window. A cancelled color edit still requires a reload if a change was applied during the session. Unchanged settings close normally. Page switching does not reload.

Configuration cannot open in combat. Entering combat hides it and clears previews; pending reload status survives until reopening and closing outside combat. Utility and graphics controls retain their existing combat restrictions.

## Features and scope

Utilities retain:
- Explicit out-of-range tinting, including native Blizzard gamepad ability bars.
- Queued next-swing borders for supported spells/macros.
- Real-cooldown and unusable-action greying, optional resource shortages and pet actions.
- Click-through on any of eight standard bars; hold Shift outside combat to interact.
- Account-wide ground-effect density control, leaving it untouched until explicitly configured.
- Integration with the existing external Gamepad Assist visual provider.

Warrior retains Battle Shout tracking and reminders; Overpower, Revenge, Execute, Victory Rush and Shield Block glow rules; the stance icon and shield corner; native gamepad page/stance replacement handling; preview actions; and restricted-value protections. Defaults and trigger rules follow Warrior 0.9.6 and Utils 0.6.0.

Hunter, Paladin and Gamepad binding overrides have not been migrated. Their existing addons may remain installed.

## Commands

- `/aft`, `/af`, `/aft config`: open or raise the window.
- `/aft status`: module status, including any duplicate-addon guard.
- `/aft warrior`: Warrior diagnostics.
- `/aft utilities`: range/cooldown diagnostics.
- `/aft utilities clicky 1-8|all`: make selected bars clickable.
- `/aft utilities noclicky 1-8|all`: enable click-through.
- `/aft utilities status`: print click-through state.

The old `/uaf`, `/waf` and `/bnc` aliases are not registered by this addon.

## Saved settings

`AwesomeForeverToolkitDB` stores account-wide Warrior and graphics preferences. `AwesomeForeverToolkitCharacterDB` stores utility preferences and UI state per character. Module subtrees are validated independently.

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
