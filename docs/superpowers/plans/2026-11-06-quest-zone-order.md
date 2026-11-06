# Quest level ordering and zone groups

Approved behavior: native Blizzard tracker only; each quest-log zone has its own heading, current zone first, other zones in quest-log order. Level ascending default, descending and native order options. Grouping may be disabled. Per-character settings. Continue on codex/native-quest-tracker; commit, do not push.

Architecture: independent metadata/order builder; reorder existing watched quests through native RemoveQuestWatch/AddQuestWatch calls outside combat, immediately re-add each removed quest and verify membership/order. Detect insertion end rather than assuming it. Do not override native methods, change native layout fields, or invoke native layout. Add compact addon-owned zone labels only in measured native gaps; hide a label if insufficient space instead of overlapping rows. Native tracker still decides which quests fit. No copied third-party implementation.

1. Add tests/quests/order.lua with a native watch-list fixture. Test current zone first, multiple distinct zone headings, level direction, stable ties, missing metadata, both insertion directions, no-op sorting, watch membership, rejected re-add recovery, combat deferral, and retry suppression.
2. Implement Modules/Quests/Order.lua for metadata/order and native watch transaction. Persist a failed re-add for recovery on next login; suspend further sorting on failure. Build metadata from quest-log headers, identify current zone via current map/parent names and zone text. Default order restoration uses native SortQuestWatches.
3. Implement Modules/Quests/Groups.lua for addon-owned compact headings. No block creation, reparenting, native state writes or geometry changes. Test measured gap/hidden/collapsed/combat cases.
4. Wire defaults, settings, events, diagnostics and manifest. Coalesce watch changes; sort only on relevant events/config changes, not every layout hook. Add docs for native API side effects, compact headings and client tests.
5. Run focused tests (red then green), full suite, Lua syntax/package, independent review; resolve findings, commit all files and leave live client validation pending.

Review focus: native callbacks can occur synchronously while sorting; never recurse. Missing metadata must leave watch membership intact. API failures must not silently untrack a quest. Repeated native sorting must not cause a sorting loop. Headings must fit existing gaps, including UI scale and collapsed trackers. Client combat taint and gamepad performance still require in-game testing.

## Implementation record

Implemented the three native ordering choices, independent zone groups/current-zone priority, compact headings, gamepad-safe ChoiceDropdown controls, event coalescing, combat deferral and watch recovery. Native sorting/grouping remains subject to tracker capacity and Blizzard special-quest priority. Headings hide during combat rather than retain potentially stale labels across pooled-row updates.

Focused ordering and heading tests failed before implementation, then passed. Independent review found two issues: errors after a successful remove could discard recovery; choosing native order while grouping remained on could retain previous level sorting. Both now have regressions observed failing before their fixes and passing afterwards; reviewer confirmed the fixes. Full local verification: 51/51 test files, syntax 148 Lua files, package 95 files. Client rendering/performance/taint validation remains pending.
