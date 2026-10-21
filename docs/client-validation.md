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
- If using the external Gamepad Assist addon, confirm its overlays retain utility feedback.
- Change grass density, verify displayed value, change the client's preset, reload, then reset to the client default.
- Drag the minimap button at different UI scales, reload and verify placement.
- Hide the button, reopen with /aft and show it again.
