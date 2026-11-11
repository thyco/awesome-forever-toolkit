# Awesome Forever Toolkit

One addon for shared WoW Forever utilities and class assistance. Version 0.1.0 targets interface **16001**. Includes Utilities, Warrior, Hunter and Paladin assistance, and Gamepad bindings with shared button discovery, client helpers, visuals and configuration controls.

## Install

1. Build with `python3 scripts/package.py`, or use the generated `dist/AwesomeForeverToolkit-0.1.0.zip`.
2. Extract into `Interface/AddOns`, producing `AwesomeForeverToolkit/AwesomeForeverToolkit.toc`.
3. Disable **Utils Assist Forever**, **Warrior Assist Forever**, **Hunter Assist Forever** and **Paladin Assist Forever**. If one is loaded, the toolkit suppresses the matching module for that session; disable the old addon and reload to activate its replacement.
4. Enable **Awesome Forever Toolkit** and restart the client if it does not appear.
5. Click the thumbs-up beside the minimap, type `/aft` or `/af`, or use the launcher under Settings → AddOns.

Settings start fresh. No legacy settings are imported or modified. The original addon repositories remain independent.

Local regression tests pass; **in-game validation is still required**, particularly native gamepad transitions and taint behavior. See [the client checklist](docs/client-validation.md).

## Configuration

The movable standalone window has these pages:

- **General:** show/hide the minimap button. Drag that button around the minimap to reposition it.
- **Action bars:** range checks, queued attack highlights, cooldown/unusable greying and click-through.
- **Graphics:** grass and ground-effect density with a reset to the client-reported default.
- **Target castbar:** opt-in native target castbar positioning, account-wide scale, a draggable preview, and reset.
- **Warrior → Reminders & glows:** select Battle Shout, Overpower, Revenge, Execute, Victory Rush or Shield Block; only the selected feature's controls are shown.
- **Warrior → Stance indicator:** current stance icon, shield corner and positioning.
- **Hunter → Hunter reminders:** ammunition thresholds, pet health/happiness, screen pulse and movement-aspect warnings.
- **Hunter → Reactive abilities:** Mongoose Bite and Counterattack glows, independent standard/gamepad destinations, colors, previews and the optional Counterattack icon overlay.
- **Paladin → Paladin reminders:** current aura icon, missing-Kings reminder, seal refresh timer and the Righteous Fury shield reminder icon.
- **Paladin → Ability glows:** Holy Strike/Judgement and Exorcism, with standard/gamepad destinations, colors and previews.
- **Your class → Gamepad bindings:** A/B/X/Y assignments and Base/form profiles. Available on every class, after the shared pages.

Class assistance pages appear only on the matching class with its module active. The last available page is remembered per character. Reminder location selectors save standard bar/button and native gamepad page/set/button separately; the current input mode determines which selection is used. Gamepad bindings use a separate page under your current class.

Changes to Warrior, Hunter or Paladin settings, including moving their icons, mark the footer **Apply & Reload**. X, Escape and the footer request that reload before hiding the window. A cancelled color edit still requires a reload if a change was applied during the session. Unchanged settings close normally. Page switching does not reload.

Configuration cannot open in combat. Entering combat hides it and clears previews; pending reload status survives until reopening and closing outside combat. Utility and graphics controls retain their existing combat restrictions.

## Features and scope

Utilities retain:
- Explicit out-of-range tinting, including native Blizzard gamepad ability bars.
- Queued next-swing borders for supported spells/macros, including gamepad overrides.
- LibCustomGlow square proc and queued-attack effects on all buttons, including gamepad Face and D-pad buttons.
- Real-cooldown and unusable-action greying, optional resource shortages and pet actions.
- Click-through on any of eight standard bars; hold Shift outside combat to interact.
- Account-wide ground-effect density control, leaving it untouched until explicitly configured.
- Range and cooldown/unusable coloring on the toolkit’s own gamepad overlays.

Warrior provides a Battle Shout underlay with optional tracked combat reminders; Overpower, Revenge, Execute, Victory Rush and Shield Block glow rules; the stance icon and shield corner; native gamepad page/stance replacement handling; preview actions; and restricted-value protections. Defaults and trigger rules follow Warrior 0.9.6 and Utils 0.6.0. Battle Shout now defaults to **Combat-only underlay**: a grayscale icon with an animated glow, shown only during combat without consulting buff state. Positioning preview remains available outside combat. In Warrior → Reminders & glows → Battle Shout, use Move / preview icon to align it underneath TellMeWhen, then close settings to restore its BACKGROUND layer and click-through behavior. Set TMW's absent/underlay opacity to zero and use an opaque aura icon above it. The glow is clipped to our icon bounds; match the covered artwork area (a masked or transparent TMW border may need a slightly smaller underlay). Existing size, position and glow preferences are retained. **Tracked combat reminder** keeps the previous aura/timer behavior; the expiry threshold only applies to that mode.

The shared `Services/ReminderIcon.lua` component owns draggable positioning, preview layering, grayscale underlay presentation and bounded glow rendering. Class features supply texture, settings, move callbacks and visibility, so other buff underlays can reuse it without aura tracking or a TellMeWhen dependency.

Hunter retains ammunition, pet health/happiness and Cheetah/Pack reminders. Mongoose Bite follows Overpower's opportunity rule and ignores its own cooldown. Counterattack follows Revenge's rule and requires its own cooldown to be ready. Both preserve a confirmed opportunity through a GCD. A successful cast clears the glow immediately; a bounded guard prevents stale API results from immediately relighting it. An actual spell cooldown blocks Counterattack only; unavailable cooldown data also blocks Counterattack. Missing/restricted usability data does not invent an opportunity for either spell. The old indefinite consumed-proc latch is not carried over. Real-client event timing still needs validation.

Choose each Hunter ability's standard bar/button and native gamepad page/set/button separately. Gamepad destinations start unselected. The active UI determines the destination; Preview uses that UI outside combat. Counterattack's optional overlay only changes the displayed icon and GCD swipe, never the underlying action, binding or tooltip.

Gamepad bindings are integrated; disable the standalone Gamepad Assist Forever when using the toolkit. There is no compatibility layer or old-settings migration for it.

## Paladin assistance

Holy Strike/Judgement share one selected button and ignore the GCD when the client can identify it. Judgement glows when ready in combat, or outside combat with a living attackable target/mouseover. Holy Strike remains combat-only and its check defaults to disabled. Judgement's appearance takes priority and defaults to green (#00FF00); Holy Strike defaults to Blizzard native. Existing saved preferences are retained. Standard destinations default to bar 3, buttons 3 (attacks), 4 (seal), and 5 (Exorcism). Gamepad destinations start unselected and use the active page/set, including toolkit override visuals.

Exorcism glows in combat when ready with a living attackable Demon or Undead target/mouseover, ignoring distance and mana. Its icon is grayscale when an attackable unit exists but cooldown or eligibility prevents the spell. This shares the toolkit's tint compositor, preserving range and cooldown effects when Paladin assistance is disabled.

The current aura indicator shows your own selected Paladin aura, at 36px by default. With no aura selected, it shows Devotion Aura in cooldown-style grayscale with an animated red glow. It has no shield overlay and works independently of the action-bar layout. Enable, resize and move it under **Paladin → Paladin reminders**. Unreadable aura state hides the indicator instead of reporting a missing aura.

The seal reminder estimates a refresh from successful casts, at 25 seconds by default, with a green (#00FF00) glow. It is visible in combat or with a living attackable target/mouseover; Command damage procs do not reset it. Righteous Fury shows a draggable 64px icon when missing or within five minutes of expiration, only with a shield equipped. Its Blizzard-style icon glow defaults on and can be disabled independently; the positioning preview shows the same appearance as the reminder, like Hunter’s aspect icon. Readable aura timing takes precedence over its cast-timer fallback. Both reminders continue observing casts while disabled. Spell-name discovery retains the standalone addon's English-client limitation.

## Commands

- `/aft`, `/af`, `/aft config`: open or raise the window.
- `/aft status`: module status, including any duplicate-addon guard.
- `/aft warrior`: Warrior diagnostics.
- `/aft hunter`: Hunter learned-spell, usability-signal, cooldown and glow diagnostics.
- `/aft hunter config`: open Hunter reminders.
- `/aft paladin` reports Paladin destinations and timers; `/aft paladin config` opens its ability settings.
- `/aft gamepad` or `/aft gamepad config`: open Gamepad bindings.
- `/aft gamepad on|off|status|log`: activate saved bindings, disable overrides, or inspect diagnostics.
- `/aft gamepad set A context|always <spell ID or spell link>` and `/aft gamepad set A native`: edit the Base profile; replace A with B, X or Y as needed.
- `/aft utilities`: range/cooldown diagnostics.
- `/aft utilities clicky 1-8|all`: make selected bars clickable.
- `/aft utilities noclicky 1-8|all`: enable click-through.
- `/aft utilities status`: print click-through state.

The old `/uaf`, `/waf`, `/haf`, `/gaf` and `/bnc` aliases are not registered by this addon.

## Gamepad bindings

Open **Your class → Gamepad bindings**, alongside your spellbook or `/macro`. Select A, B, X or Y in the controller diamond to edit it, or drop a spell/macro directly onto a button. The focused editor also accepts drops. A new drop chooses **Contextual**, unless that button already uses **Always**. Empty buttons show a muted letter and **Blizzard default** instead of a question mark.

- **Blizzard default** restores native behavior while remembering the assignment. **Clear assignment** removes the Base assignment.
- **Contextual** uses the assignment in combat or with a living hostile target. Hostile mouseover is considered only without a selected target; a friendly or dead selected target prevents that fallback.
- **Always** uses it without requiring combat or a target. Triggers, shoulder modifiers, native stance and possess layers still take priority.
- The **Profile dropdown** selects Base or a known stance/form for editing; it does not switch your current form. An inherited profile displays the resolved Base icon, name and behavior with **Inherited from Base**. **Blizzard default** explicitly restores native behavior for that form; **Use Base assignment** removes the form override and restores inheritance.
- **Enable overrides** controls saved activation. Assignments and activation survive reload. Temporary unavailable macros or layout do not erase the preference.

Spells use the existing target/mouseover rules; macros keep their own targeting and castsequence rules. Macro names must be unique across account and character macros. After renaming a macro, assign it again. Items and flyouts are unsupported. Configuration is locked during combat; macro/form data updates are deferred until combat ends.

Override icons show the normal checked indicator while their spell is queued, even with custom queued highlights disabled. Custom highlights track the displayed spell or applicable supported macro commands. All buttons use the library’s square effects with the selected color (or the default glow color).

The overlay is visual only. Test with the physical controller; clicking it with a mouse still reaches the native button. When assigning A permanently, bind jump elsewhere. Controller Rebound must be disabled because it claims the same buttons. Starting with no assignments via `/aft gamepad on` retains the original quick-start behavior: it copies the spell from page 1, LT+X to A in Context mode.

## Saved settings

`AwesomeForeverToolkitDB` stores account-wide Warrior, Hunter, Paladin and graphics preferences. `AwesomeForeverToolkitCharacterDB` stores utility preferences, UI state and gamepad assignments/activation per character. Module subtrees are validated independently.

## Development

```sh
python3 tests/run.py
python3 tests/syntax.py
python3 tests/package.py
```

Each Lua test file runs in its own process against mocked client APIs. The bundled glow-library integration test also executes the actual library. [Regression provenance](docs/test-provenance.md) documents the migrated coverage. Tests and packaging do not depend on the old repositories.

The approved PNG and its generation prompt live under `artwork/`. `python3 scripts/prepare_icon.py` regenerates the 256×256 RGBA TGA using Pillow. The checked-in TGA means Pillow is unnecessary to install or package the addon. Distribution zips are build outputs and are ignored by Git.

## Attribution

Feature code derives from the author's Warrior Assist Forever, Hunter Assist Forever and Utils Assist Forever projects. Utils' click-through behavior derives from BarNoClicky by mostlyharmlessx; cooldown greying adapts GreyOnCooldown behavior. LibCustomGlow and LibStub are bundled with their original notices; see `AwesomeForeverToolkit/Libs/`. Source-library formatting is preserved.

## Experimental native quest tracker branch

`codex/native-quest-tracker` contains experimental native tracker enhancements, not the complete QuestTagsForever feature set. It enhances the existing Blizzard tracker; no separate tracker is created. Disable QuestTagsForever and reload before using it. The toolkit skips this module if QuestTagsForever is loaded.

All quest enhancement checkboxes default to enabled for fresh character settings. Configure them under **Quest tracker** in `/aft`; existing saved choices are preserved. Per-character options add quest levels and E/D/R tags to the native quest headers and a quest-log count. Title edits/new hooks wait until combat ends, while Blizzard's objective progress continues normally. Tags are skipped when they would change the native title height. Disabling restores still-owned title changes outside combat. Quest order defaults to **lowest level first**, grouped under each quest-log zone with the **current zone first**. Remaining zones follow quest-log order, never a combined Other category. Choose highest level first or Blizzard order within groups, or disable grouping for a single sorted list. Zone matching uses the current map and its parents plus the current zone name; quest-log class/profession categories remain separate categories.

Ordering uses native quest-watch removal and immediate re-add outside combat, retaining the watched set; it can briefly trigger Blizzard's normal watch animations and refreshes. It does not replace tracker methods or write native layout state. Sorting pauses if the client rejects or repeatedly changes the order; `/aft quests status` reports why. Changing an ordering option explicitly retries. A failed re-add is recorded for recovery on subsequent updates/reload. Selecting Blizzard order with grouping off, or disabling enhancements, requests native sorting; it does not restore an exact historical manual order.

Zone sections use the original addon's visual style: full native-size gold headings, normal quest spacing, and thin gold separators before later zones. The existing native quest content sits in a scroll viewport using the available Edit Mode tracker height below the quest header, stopping before any following visible tracker section. Zone positions are rebuilt from row heights on each update so spacing does not accumulate. Scrolling appears only when the displayed content exceeds that available area. Use the mouse wheel or scrollbar outside combat. Existing headings remain visible in combat while their associated quest rows and reserved space remain valid. Only headers whose rows disappear, are reused, or lose their reserved space are hidden; they are rebuilt after combat. Geometry changes and scrolling still wait until combat ends. Disabling grouping restores the native content parent and anchors. This scrolls only the rows Blizzard already chose to display; native tracker capacity and special quest priorities still apply. Validate rendering, watch animations, gamepad responsiveness, quest selection/item buttons, and combat taint in the client. Filters, all-quest mode, quest-log/map decorations and TomTom remain pending.

For repeatable diagnostics, run `/aft quests debug on`, then `/aft quests test`, wait a moment, and run `/aft quests status`. Repeat in and out of combat. The test queues toolkit decoration and calls the normal `C_QuestLog.SortQuestWatches()` engine API; it does not call native tracker Update/MarkDirty or synthesize a level-up event. It may reorder watched quests using Blizzard's normal sort, which can pause custom ordering; change an ordering option to retry afterwards. Compare native/combat update counts before and after; unchanged counts mean no native update was exercised. `/aft quests debug off` disables test commands, and reload also disarms them. Diagnostics report method taint where the client supports `issecurevariable`; these observations and local tests are not proof of taint-free operation. Test a real combat level-up when available.

## Target castbar positioning

Disable the standalone ForeverTargetCastbar addon, then enable **Target castbar → Enable target castbar positioning** in `/aft`. Use **Move / preview castbar** outside combat and drag the preview into place. Use **Horizontal position (%)** and **Vertical position (%)** to fine-tune the location numerically (0–100, with decimals). X is measured from the left, Y from the bottom; dragging refreshes both fields. Close settings or use **Lock / hide preview** when finished. The preview uses Blizzard's target castbar template; the actual castbar remains Blizzard-owned and keeps its native casts, channels and interruptibility display.

Position and scale are saved account-wide in `AwesomeForeverToolkitDB.targetCastbar`. The centre of the bar is anchored to screen percentages, independently of the target frame's position. Reset restores 50% across, 38% up from the bottom and 100% scale. Scale is a multiplier of the native bar and still inherits the target frame's Edit Mode scale; the preview follows that effective scale. Disabling positioning restores the native anchors and scale captured when positioning was enabled.

Dragging stops without saving if combat starts. Configuration changes wait until combat ends. Native combat layout hooks only preserve the previously applied position/scale when the castbar is unprotected; protected bars defer that maintenance until combat ends. No cast or aura values are inspected. If ForeverTargetCastbar is still loaded, toolkit positioning stays inactive to avoid competing hooks. Live positioning, preview appearance and taint behavior require an in-game check.
