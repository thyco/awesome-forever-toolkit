local H = dofile("tests/fixtures/warrior/helpers.lua")
local world = H.new()
local root = {}
assert(loadfile("AwesomeForeverToolkit/Services/Glow.lua", "t", world.env))("AwesomeForeverToolkit", root)
local button = world:newFrame()

root.Glow.Prepare(button)
root.Glow.ConfigureOwner("warrior:test", {priority = 10})
root.Glow.ConfigureOwner("other:test", {priority = 1})
root.Glow.Set(button, "warrior:test", true)
root.Glow.Set(button, "other:test", true)
root.Glow.Set(button, "warrior:test", false)

assert(world.glowActive[button])
root.Glow.ClearOwner("other:test")
assert(world.glowActive[button] == false)

world.combat = true
local unprepared = world:newFrame()
assert(root.Glow.Prepare(unprepared) == nil)
root.Glow.Set(unprepared, "warrior:test", true)
assert(world.glowActive[unprepared] ~= true)
print("glow: PASS")
