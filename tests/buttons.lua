local H = dofile("tests/fixtures/utilities/helpers.lua")
local world = H.new()
local root = {}
for _, file in ipairs({"Core/Addon", "Services/Client", "Services/Buttons"}) do
    assert(loadfile("AwesomeForeverToolkit/" .. file .. ".lua", "t", world.env))("AwesomeForeverToolkit", root)
end

local standard = world:button("ActionButton1", 1)
assert(root.Buttons.Selected(1, 1) == standard)
assert(root.Buttons.GamepadSelected(0, 1, 1) == nil)
local initial = root.Buttons.All()
assert(#initial == 1)

local native = world:gamepadBar("topBar", {10, 11})
world.env.GamepadMainActionBarFrame.PageUnit.GetCurrentPage = function() return 1 end
assert(root.Buttons.GamepadSelected(1, 1, 1) == native[1])
assert(root.Buttons.GamepadSelected(2, 1, 1) == nil)
local seen = {}
for _, button in ipairs(root.Buttons.All()) do
    assert(not seen[button])
    seen[button] = true
end
assert(seen[standard] and seen[native[1]])

local replacement = world:gamepadBar("topBar", {12})
assert(root.Buttons.GamepadSelected(1, 1, 1) == replacement[1])
assert(root.Buttons.GamepadSelected(1, 1, 9) == nil)
world.env.GamepadMainActionBarFrame = world.secret
assert(root.Buttons.GamepadSelected(1, 1, 1) == nil)
assert(#root.Buttons.All() == 1)
assert(root.Client.Number(0) == 0)
assert(root.Client.Number(0/0) == nil)
assert(root.Client.Number(world.secret) == nil)
print("buttons: PASS")
