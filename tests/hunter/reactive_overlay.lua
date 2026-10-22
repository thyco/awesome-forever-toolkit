local H = dofile("tests/hunter/reactive/helpers.lua")
local world = H.new()
local overlay = world:loadReactive("Services/CounterattackOverlay").CounterattackOverlay
local first, second = world.env.ActionButton1, world.env.ActionButton2
world.cooldowns[61304] = { startTime = 100, duration = 1.5 }

overlay:Prepare(first)
overlay:Prepare(second)
overlay:Set(first, true)
local entry = overlay.entries[first]
H.equal(entry.frame.visible, true)
H.equal(entry.cooldown.duration, 1.5, "overlay displays GCD swipe")
H.equal(entry.frame.mouse, false, "overlay never intercepts clicks")

overlay:Set(second, true)
H.equal(entry.frame.visible, false, "new destination hides old icon")
H.equal(overlay.entries[second].frame.visible, true)

world.cooldowns[61304] = { startTime = 0, duration = 0 }
overlay:Set(second, true)
H.equal(overlay.entries[second].cooldown.duration, nil, "finished GCD clears swipe")

overlay:Stop()
H.equal(overlay.entries[second].frame.visible, false)

world.combat = true
local third = world:newFrame()
overlay:Prepare(third)
H.equal(overlay.entries[third], nil, "unprepared destinations are not created in combat")
world.combat = false
local circular = world:newFrame()
circular.CircleMask = world:newFrame()
overlay:Prepare(circular)
local circularEntry = overlay.entries[circular]
H.equal(circularEntry.frame.points, circular.CircleMask, "native gamepad inset determines overlay bounds")
H.equal(circularEntry.texture.mask ~= nil, true, "gamepad icon is masked to the native circle")
H.equal(circularEntry.cooldown.swipeTexture, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "gamepad GCD swipe is circular")
print("hunter reactive overlay passed")
