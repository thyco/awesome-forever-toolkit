# Regression provenance

Warrior feature tests derive from d6d86ac; Utilities tests derive from 9d609f2. Source repositories were clean at import.

Feature fixtures load the new runtime/services, never source repositories. The root integration harness loads the actual toolkit manifest and all current modules.

The original settings implementation has been replaced. Its meaningful behavior checks now live in:
- tests/settings.lua: defaults, saved utility choices, immediate tint changes, independent toggles, scroll ownership, class navigation, shared launchers, preview cleanup, colors and restricted picker values.
- tests/settings_close.lua: X, Escape, footer, reverted colors, no-op edits, position edits and combat interruption.
- tests/graphics_ui.lua: all 10 original graphics scenarios, through the new page.

Assertions about old native-category navigation, absolute section counts and literal source strings were retired with that UI. Warrior native-gamepad feature tests retain their runtime assertions; UI selector coverage is in the root settings suite.

## Gamepad integration

The active Gamepad Assist Forever 0.7.0 source files are OverlayLogic, ActionModel, OverlayVisual, OverlayRuntime, ConfigurationActions and ConfigurationUI. Old paging/secure probe implementations are not packaged or imported.

The activation, configuration, profiles, overlay/router and visual suites in tests/gamepad derive from those active upstream suites. The loader adapts namespaces and uses the real toolkit configuration adapter. Storage assertions target AwesomeForeverToolkitCharacterDB.gamepad; missing activation flags now remain off rather than importing/enabling legacy assignments. The shared editor suite adapts the original UI callbacks to one class page instead of two standalone/native panels.

The secure router snippet, condition driver generation and spell macro generation are unchanged. Root integration covers fresh state, absent gamepad APIs, class page order and combat opening restrictions. Utility overlay tests now use the internal module provider, including hidden-frame preparation, range/cooldown tint, macro spell changes and cleanup.

Real-client secure execution, controller delivery and visual rendering remain manual checks. No test depends on the source repository at runtime.
