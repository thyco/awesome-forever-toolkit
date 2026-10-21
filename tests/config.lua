local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:load({"Core/Addon", "Core/Config"})
local valid = function(_, value) return type(value) == "boolean" end

local first = addon.Config.NewStore("account", "first", {enabled = true}, valid)
local second = addon.Config.NewStore("character", "second", {enabled = true}, valid)
local changes = 0
first.Subscribe(function() changes = changes + 1 end)

assert(first.Set("enabled", false))
assert(first.Get("enabled") == false)
assert(second.Get("enabled") == true)
assert(first.Set("enabled", false) == false)
assert(changes == 1)
assert(not pcall(first.Set, "unknown", true))
assert(not pcall(first.Set, "enabled", "yes"))
assert(world.env.WarriorAssistForeverDB == nil)
assert(world.env.UtilsAssistForeverDB == nil)

world.env.AwesomeForeverToolkitDB.broken = "invalid"
local repaired = addon.Config.NewStore("account", "broken", {enabled = true}, valid)
assert(repaired.Get("enabled"))
assert(first.Get("enabled") == false)
print("config: PASS")
