local H = dofile("tests/hunter/reactive/helpers.lua")
local world = H.new()
local addon = world:loadReactive("Services/ReactiveSpells", "Services/CounterattackOverlay", "Features/ReactiveAbilities")
local feature = addon.ReactiveAbilities
feature:Initialize()

H.equal(world.glowActive[world.env.ActionButton1], false, "normal glows are combat-only")
H.equal(addon.CounterattackOverlay.entries[world.env.ActionButton2].frame.visible, false, "normal overlay is combat-only")
world.combat = true
world:fire("PLAYER_REGEN_DISABLED")

H.equal(world.glowActive[world.env.ActionButton1], true, "keyboard Mongoose glows")
H.equal(world.glowActive[world.env.ActionButton2], true, "keyboard Counterattack glows")
H.equal(addon.CounterattackOverlay.entries[world.env.ActionButton2].frame.visible, true, "Counterattack icon covers destination")
H.equal(addon.CounterattackOverlay.entries[world.gamepad[2]].frame.visible, false, "gamepad overlay prepared before combat")

world.combat = true
world.style = 1
world:fire("INPUT_DEVICE_INTERFACE_TRANSITION")
H.equal(world.glowActive[world.env.ActionButton1], false, "UI transition clears keyboard glow")
H.equal(world.glowActive[world.gamepad[1]], true, "gamepad Mongoose destination glows")
H.equal(addon.CounterattackOverlay.entries[world.env.ActionButton2].frame.visible, false, "UI transition hides old overlay")
H.equal(addon.CounterattackOverlay.entries[world.gamepad[2]].frame.visible, true, "overlay follows gamepad")
H.equal(world.combatFrameCreations, 0, "switching mode in combat creates no frames")

world.pageUnit.currentPage = 2
world:fire("ACTIONBAR_PAGE_CHANGED")
H.equal(world.glowActive[world.gamepad[1]], false, "live proc only lights its selected page")
H.equal(addon.CounterattackOverlay.entries[world.gamepad[2]].frame.visible, false, "page change hides live Counterattack icon")
world.pageUnit.currentPage = 1
world:fire("ACTIONBAR_PAGE_CHANGED")
H.equal(addon.CounterattackOverlay.entries[world.gamepad[2]].frame.visible, true, "returning to selected page restores valid opportunity")

world:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1495)
H.equal(world.glowActive[world.gamepad[1]], false, "successful cast clears current glow immediately")
world.time = 107
feature:Refresh()
H.equal(world.glowActive[world.gamepad[1]], true, "new proc can glow after cast guard expires")

world.combat = false
world:fire("PLAYER_REGEN_ENABLED")
H.equal(world.glowActive[world.gamepad[1]], false, "leaving combat clears glow")
H.equal(addon.CounterattackOverlay.entries[world.gamepad[2]].frame.visible, false, "leaving combat hides icon")
H.equal(next(addon.ReactiveSpells.procUsable), nil, "leaving combat clears cached opportunity")
world.usable[1495] = false
world.usable[19306] = false
world.time = 110
feature:Refresh()
H.equal(feature:PreviewGamepad("mongoose"), true, "gamepad preview succeeds for shown destination")
H.equal(world.glowActive[world.gamepad[1]], true, "preview lights even without opportunity")

world.pageUnit.currentPage = 2
world:fire("ACTIONBAR_PAGE_CHANGED")
H.equal(world.glowActive[world.gamepad[1]], false, "page changes clear preview")
H.equal(feature.preview, nil)
H.equal(feature:PreviewGamepad("mongoose"), false, "hidden page cannot be previewed")

world.pageUnit.currentPage = 1
world.config.mongooseNativeColor = false
H.equal(feature:PreviewGamepad("mongoose"), true)
local entry = addon.Glow.Prepare(world.gamepad[1])
H.equal(world.glows[entry.frame].color[1], 0.2, "RGB tuple converted for shared glow")

world.style = 0
world:fire("INPUT_DEVICE_INTERFACE_TRANSITION")
H.equal(feature.preview, nil, "switching UI clears preview")
H.equal(feature:PreviewGamepad("mongoose"), false, "gamepad preview requires gamepad UI")
H.equal(feature:Preview("counterattack"), true, "keyboard preview supported")
world:tick(3.1)
H.equal(feature.preview, nil, "preview expires")

world.combat = true
world.config.counterattackGlowEnabled = false
world.usable[19306] = true
feature:Refresh()
H.equal(world.glowActive[world.env.ActionButton2], false, "overlay independent of disabled glow")
H.equal(addon.CounterattackOverlay.entries[world.env.ActionButton2].frame.visible, true)

feature:Stop()
H.equal(addon.CounterattackOverlay.entries[world.env.ActionButton2].frame.visible, false, "stop hides overlay")
H.equal(feature.frame.scripts.OnUpdate, nil, "stop removes polling")
print("hunter reactive feature passed")
