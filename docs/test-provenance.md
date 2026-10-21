# Regression provenance

Warrior feature tests derive from d6d86ac; Utilities tests derive from 9d609f2. Source repositories were clean at import.

Feature fixtures load the new runtime/services, never source repositories. The root integration harness loads the actual toolkit manifest and both modules.

The original settings implementation has been replaced. Its meaningful behavior checks now live in:
- tests/settings.lua: defaults, saved utility choices, immediate tint changes, independent toggles, scroll ownership, class navigation, shared launchers, preview cleanup, colors and restricted picker values.
- tests/settings_close.lua: X, Escape, footer, reverted colors, no-op edits, position edits and combat interruption.
- tests/graphics_ui.lua: all 10 original graphics scenarios, through the new page.

Assertions about old native-category navigation, absolute section counts and literal source strings were retired with that UI. Warrior native-gamepad feature tests retain their runtime assertions; UI selector coverage is in the root settings suite.
