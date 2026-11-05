# Kings Reminder Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this approved change inline, with a fresh final review.

**Goal:** Add a movable missing-Kings reminder with optional glow-only presentation and a reusable, conservative buff tracker.

**Architecture:** A shared tracker combines guarded direct aura queries with out-of-combat identification of Blizzard tracked buff frames. Consumers receive present/missing/unknown; frame visibility never implies coverage of other casters or targetable buffs. Paladin owns blessing definitions and presentation. Righteous Fury remains unchanged for this trial.

**Tech Stack:** Existing Lua addon runtime, Blizzard aura/cooldown-viewer APIs, LibCustomGlow.

**Spec:** User-approved conversation design: 36px grayscale Blessing of Kings with red glow when Kings and Greater Kings are missing, unless Freedom is active; include other Paladins; unknown/incomplete data hides the warning. Latest addition: hide artwork while retaining glow, like Battle Shout.

## Global Constraints

- No changes to dk-force or Righteous Fury behavior.
- Default icon size 36px; movable via preview, account-wide settings like other Paladin reminders.
- Never inspect secret values or modify Blizzard frames. Cache identities only outside combat.
- Preserve existing work and commit all changed/new files; user pushes.

## Review Focus

- Another Paladin's Kings: hidden CDM entries cannot establish all-caster absence.
- Target blessings: visible CDM entry is presence only with readable player unit or an explicitly self-only buff definition.
- Inactive/hidden/recycled viewers and Edit Mode must not establish presence or absence.
- Missing APIs, secret values and partial failures yield unknown rather than false missing.
- Glow-only mode keeps animation and positioning; disabling, settings close and combat clean up previews.

### Task 1: Shared tracking service

Files: Services/BuffTracker.lua, Services/TrackedBuffFrames.lua, manifest, tests/buff_tracker.lua.
Interfaces: root.BuffTracker.New(groups, options) -> tracker; groups contain key and spellIDs; options.selfOnly explicitly authorizes using hidden tracked frames for absence of inherently self-only buffs. tracker:Sample() -> state, detail; tracker:Invalidate() clears direct query cache. detail includes source and per-group state for diagnostics.

- [x] Write failing tests for direct lookup, restricted data, complete/incomplete groups, tracked frame presence, target/other-caster safety, frame recycling, viewer hiding/editing and self-only reuse.
- [x] Implement guarded direct sampling and frame discovery, never writing to Blizzard frames.
- [x] Run focused tests; commit the reusable service together with its first consumer after final integration verification.

### Task 2: Blessing reminder integration

Files: Paladin/Services/Blessings.lua, Paladin/Features/BlessingReminder.lua, Config.lua, Module.lua, Pages.lua, manifest, tests/paladin/blessings.lua, README.md, docs/client-validation.md.
Interfaces: addon.Blessings.groups supplies Kings (20217), Greater Kings (25898), Freedom (1044); addon.BlessingReminder uses the shared tracker, existing PopupIcons and Glow. /aft paladin buffs prints per-group detection and coverage diagnostics.

- [x] Write failing integration tests for missing/present/unknown, other-caster blessings, glow-only preview, settings and combat cleanup.
- [x] Implement enable/size/hide-artwork/position settings and live diagnostic command; reuse existing popup behavior.
- [x] Run all Lua tests, syntax, reproducible packaging and diff checks.
- [x] Fresh review, resolve findings, commit all changes without pushing.

## Execution notes

Ruling: CDM visibility alone cannot prove all-caster blessing absence because current Blizzard source filters own casts and can track target auras. The default all-caster tracker therefore uses CDM only for verified player presence. It returns unknown for hidden CDM entries unless the consumer explicitly declares an inherently self-only buff. This keeps the requested no-false-warning behavior and provides a useful foundation for Righteous Fury.

Scope refinement: user requested Kings/Greater Kings specifically, suppressed by Freedom; other blessings must not suppress it. The shared tracker remains generic.

Validation: 48/48 Lua test files, syntax for 140 Lua files, reproducible package containing 90 files, and git diff whitespace checks passed. Fresh final review reported no actionable findings. Live client validation remains outstanding.
