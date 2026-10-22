local H = dofile("tests/gamepad/helpers.lua")
local addon = {}
H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/ActionModel.lua")("AFT", addon)
local current, combat = {}, false
C_Spell = {IsCurrentSpell = function(spell) return current[spell] or false end}
SecureCmdOptionParse = function() return combat and "Heroic Strike" or "Shoot" end
local action = {kind = "macro", macroName = "Swing", macroBody = "#showtooltip Hamstring\n/cast [combat] Heroic Strike; Shoot"}

current["Heroic Strike"] = true
combat = true

assert(addon.ActionModel.IsCurrent(action, 1715), "queued macro command must override unrelated tooltip")

combat = false

assert(not addon.ActionModel.IsCurrent(action, 1715), "inactive macro branch must not show checked")

current[78] = true

assert(addon.ActionModel.IsCurrent({spellID = 78}, 78))
current[78] = false
assert(not addon.ActionModel.IsCurrent({spellID = 78}, 78))

local secret = {}
issecretvalue = function(value) return value == secret end
C_Spell.IsCurrentSpell = function() return secret end
assert(not addon.ActionModel.IsCurrent({spellID = 78}, 78))
print("gamepad current spell: PASS")
