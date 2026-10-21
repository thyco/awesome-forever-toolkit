local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:load({"Core/Addon", "Core/Config", "Core/Bootstrap"})
local starts = 0
addon.RegisterModule("Utilities", { legacy = "UtilsAssistForever", Start = function() starts = starts + 1 end })
addon.RegisterModule("Warrior", { class = "WARRIOR", legacy = "WarriorAssistForever", Start = function() error("wrong class activated") end })
world.class = "HUNTER"

world:fire("PLAYER_LOGIN")
world:fire("PLAYER_LOGIN")

assert(starts == 1)
assert(addon.modules.Warrior.status == "wrong class")
assert(not pcall(addon.RegisterModule, "Utilities", {}))

local other = H.new()
local root = other:load({"Core/Addon", "Core/Config", "Core/Bootstrap"})
other.loaded.UtilsAssistForever = true
root.RegisterModule("Utilities", {legacy = "UtilsAssistForever", Start = function() error("duplicate started") end})

other:fire("PLAYER_LOGIN")

assert(root.modules.Utilities.status:match("disable"))
print("core: PASS")
