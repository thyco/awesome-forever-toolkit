# Client validation checklist

Automated tests simulate client APIs; they cannot establish native-client taint safety. Run these checks on the targeted WoW Forever client before treating 0.1.0 as validated in game.

## Installation and first login

- Disable old Utils Assist Forever and Warrior Assist Forever, install the single AwesomeForeverToolkit folder, then log in.
- Confirm the thumbs-up minimap button and fresh defaults. Open through the button, /aft, /af and the AddOns launcher.
- On a Warrior, confirm Warrior pages. On another class, confirm utilities work and no Warrior runtime/pages activate.
- If testing coexistence, enable an old addon and reload: the corresponding toolkit module must remain inactive and /aft status must explain why.

## Configuration lifecycle

- Open/close without changes using X, Escape and Close; no reload.
- Change a Warrior setting, then close through each route: one reload, saved value restored.
- Change a color, cancel it, then close: original color restored and reload still required.
- Move Battle Shout/stance icons; close and verify saved position after reload.
- Change pages and feature selections: visible controls/title follow selection; previews clear without reload.
- Enter combat while configuration is open: window hides, previews clear and no reload occurs. Reopen after combat and close to apply the pending reload.
- Confirm normal keyboard interaction and Escape do not inadvertently close the underlying Blizzard settings panel.
- Inspect for ADDON_ACTION_BLOCKED, ADDON_ACTION_FORBIDDEN and taint errors during all these transitions.

## Warrior and controller

- Configure each relevant standard action button and native gamepad page/set/button.
- Confirm keyboard/gamepad mode switching clears the old location and uses the saved new one.
- Test different native pages, stance replacement bars and possess layouts.
- Test Overpower in Battle/Berserker stance, Revenge in Defensive stance, Execute, Victory Rush and Shield Block under their normal conditions.
- Test gamepad preview outside combat, expiry after three seconds, page mismatch and missing/hidden destinations.
- Check Battle Shout reminders, stance icon, shield corner and custom/native glow colors.

## Utilities, graphics and launcher

- Confirm out-of-range tint, cooldown/unusable greying and queued attack borders, including gamepad bars.
- Confirm utility effects and Warrior glows coexist on the same button and stopping either leaves the other intact.
- Check click-through on selected bars, Shift interaction and combat deferral.
- Confirm the integrated Gamepad bindings overlays receive range and cooldown/unusable feedback, and disabling them clears those colors.
- Change grass density, verify displayed value, change the client's preset, reload, then reset to the client default.
- Drag the minimap button at different UI scales, reload and verify placement.
- Hide the button, reopen with /aft and show it again.

## Integrated Gamepad bindings (new; needs client validation)

- Disable standalone Gamepad Assist Forever and Controller Rebound. Start with fresh toolkit gamepad settings and confirm native controls remain unchanged until configured.
- Open `/aft gamepad`, the minimap launcher and the class page. Confirm one editor in the shared window, including on Hunter/Paladin, and no extra Blizzard settings category or window.
- Drop spells and macros onto all four buttons; select buttons in the diamond, switch Blizzard default/Contextual/Always, Clear assignment and enable/disable. Reject items/flyouts without losing the cursor or saved assignment. Verify narrow-window scaling and tooltip alignment.
- Test Base and two stance/form profiles, including resolved inherited names/icons/behavior, explicit Blizzard default, and Use Base assignment; confirm changing the edited profile does not switch stance.
- Reload while enabled, while disabled, and while the gamepad layout is unavailable. Confirm choices restore once layout/macros become ready. Test missing/renamed macros and form-list updates.
- With the physical controller, test combat, enemy target, no target, hostile mouseover without target, friendly/dead selected target, and soft target alone. Confirm macros retain their own target rules.
- Test LT, RT, LT+RT, LB, RB, LB+RB, stance and possess layers, and holding/releasing buttons across a context transition. Native behavior must remain intact.
- Test menu/dialog interactions and normal jump when Context is inactive. Check icons/cooldowns/utility colors at multiple UI scales and after layout changes.
- Enter combat with the editor open; it hides without changing secure bindings. Verify deferred macro/form refresh and `/aft gamepad off` after combat. Check for taint and blocked/forbidden action reports.

## Focused gamepad editor visual check

- Confirm the Y/X/B/A diamond matches the physical controller, with a gold outline on the selected button and a single editor to its right.
- Empty slots should show a muted button letter and Blizzard default; no question-mark texture. Assigned icons should retain a visible button-letter label.
- Switch to a form that inherits a Base spell or macro: the editor should show its actual icon, name and behavior with Inherited from Base. Change Base, return to the form, and verify the updated value. Also test inheriting an empty Base.
- Drop onto each diamond button and the larger editor slot; click without a cursor to select without changing assignments. Verify long spell/macro names, missing macros, profile dropdown, tooltips and narrow-window scaling.

## Hunter

- Disable Hunter Assist Forever, install the toolkit, then reload on a Hunter. Confirm Hunter reminders, Reactive abilities and Gamepad bindings appear together after shared pages. Confirm other classes do not start Hunter features.
- Check ammo cutoff colors/counts and one warning per low-ammo episode; check pet health/happiness, pulse preview, and Cheetah/Pack in combat. Move icons and verify positions survive Apply & Reload.
- Configure both normal and gamepad destinations for each reactive ability. Preview in each input mode. Open destination choices with the native gamepad UI active and confirm no protected-action errors.
- Trigger Mongoose Bite and learned Counterattack: a valid opportunity glows; an unrelated GCD does not erase it; casting clears it immediately. A real spell cooldown blocks Counterattack; Mongoose Bite still glows when the client reports an opportunity during its own cooldown. Subsequent opportunities must glow again without a reload.
- Check low mana, different learned ranks, missing/restricted cooldown data and a proc arriving during cooldown. Capture `/aft hunter` output if the result is wrong. Local mocks cannot establish actual client signal timing.
- Switch gamepad pages, sets, input mode and native frame replacements. Only the selected visible destination should glow; the previous destination and Counterattack icon must clear. Check the overlay GCD swipe and confirm action/binding/tooltip are unchanged.
- Close settings and enter combat with previews active: previews stop; unchanged settings close normally, changed Hunter settings request one reload before closing.

## Round Face glows and queued gamepad overrides

- Compare class proc previews on Face buttons and square buttons. Face glows should have a soft, pulsing circular halo; D-pad buttons should retain square effects even when their template includes a CircleMask. Check default and custom colors, UI scale, and expanded bars.
- Override a Face button with Raptor Strike, Heroic Strike, Cleave or Maul. With custom queued highlights disabled, queue the attack using the controller and confirm the checked indicator appears, then clears when consumed or canceled.
- Enable custom queued highlights and repeat with default and custom colors. The custom ring should be round and follow the override, without highlighting the original hidden action.
- Repeat with a supported conditional macro and a macro containing multiple next-swing commands, including when only the second command is queued. An unrelated tooltip spell should not prevent the queued indicator.
- Change Base/form assignments, disable overrides, and switch between standard and gamepad layouts. Confirm stale indicators disappear, including during combat transitions, with no protected-action errors.

These checks require the live client; local regression tests cannot confirm rendering, controller input, or client taint behavior.
