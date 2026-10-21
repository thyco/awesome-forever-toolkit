# Implementation notes: phase one

Implemented on codex/toolkit-foundation in the user-designated repository. No original addon repository was modified. Nothing was pushed or merged.

## Verification

- 27 Lua test files passed, including preserved module regression suites.
- 73 Lua source/test files passed luac syntax validation.
- Installable archive passed checks for 48 packaged files, manifest/texture paths, licensing and reproducible output.
- The independent final review found one Important issue: utility effects could remain on departed gamepad frames. Six replacement/removal cases reproduced it, then passed after shared snapshot reconciliation was added.
- No Critical or Minor findings were raised.
- In-game taint, native rendering and controller behavior remain subject to docs/client-validation.md.

## Decisions made during execution

1. Used the new repository in place on a feature branch instead of creating a second checkout. This follows the approved plan and keeps the requested repository ready to push. Tradeoff: another worker in the same checkout would share its filesystem; no concurrent implementation worker was used.
2. Unified Client.Number on the Warrior number-or-nil contract. Utility callers retain the same truthiness behavior, while arithmetic consumers keep actual numeric values. Tradeoff: future callers must not compare this helper's result to literal true.
3. Ported old UI behavior assertions with the shared-window implementation rather than keeping assertions against the removed panel structure. Runtime checks remained active throughout; replacement settings and graphics checks now pass. Tradeoff during migration was delayed UI coverage, now resolved.
4. Actual-client taint and rendering could not be independently judged by the reviewer. Keep them explicitly unverified until the client checklist is exercised; the cost is potential client-specific issues despite local mocks passing.
5. Domain rules were reviewed through source migration and preserved regression suites rather than independently re-derived spell by spell. This preserves existing behavior; inherited domain assumptions still need in-game confirmation.
6. The reviewer deliberately did not rebuild the package in its read-only pass. The implementer ran the package checks, including manifest/texture existence and byte-for-byte reproducibility; the cost is no second independent packaging execution.

No minor findings were deferred. Distribution ZIPs and execution scratch are ignored build outputs; all source, artwork, tests and documentation are committed.
