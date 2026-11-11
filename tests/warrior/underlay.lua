local H = dofile("tests/helpers.lua")
local w = H.new()
local root = w:loadManifest()
w:fire("PLAYER_LOGIN")
local warrior = root.modules.Warrior
local icon = warrior.BattleShoutIcon

assert(warrior.Config.Get("battleShoutMode") == "underlay")
assert(not icon.frame:IsShown(), "underlay is hidden outside combat")
assert(icon.frame.strata == "BACKGROUND", "underlay is below other addon icons")
assert(icon.frame.clips == true, "glow is confined to the coverable rectangle")
assert(icon.texture.desaturation == 1, "underlay uses cooldown grayscale")

local refresh, status, observe = warrior.BattleShoutAura.Refresh, warrior.BattleShoutAura.Status, warrior.BattleShoutAura.ObservePlayerCast
warrior.BattleShoutAura.Refresh = function() error("underlay must not query auras") end
warrior.BattleShoutAura.Status = function() error("underlay must not inspect aura state") end
warrior.BattleShoutAura.ObservePlayerCast = function() error("underlay must not observe casts") end
w.combat = true
w:fire("PLAYER_REGEN_DISABLED")
w:fire("UNIT_AURA", "player", {})
w:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 6673)
w:tick(200)
assert(icon.frame:IsShown(), "casts and combat do not hide the underlay")

w.combat = false
w:fire("PLAYER_REGEN_ENABLED")
assert(not icon.frame:IsShown(), "leaving combat hides the underlay")
icon:SetPreview(true)
assert(icon.frame:IsShown(), "positioning preview works outside combat")
assert(icon.frame.strata == "TOOLTIP")
icon:SetPreview(false)
assert(icon.frame.strata == "BACKGROUND")
assert(not icon.frame:IsMouseEnabled(), "locked underlay is click-through")
assert(not icon.frame:IsShown(), "outside combat only preview can show the underlay")

-- A separate consumer owns its own settings and glow, without Warrior-specific logic.
local other = root.ReminderIcon.New({
    owner = "test:second-underlay", texture = 123,
    canPreview = function() return true end, onMoved = function() end,
})
other:ApplySettings({size = 36, x = 50, y = 0, underlay = true, color = {1, 0, 0, 1}})
other:SetVisible(true)
assert(other.frame ~= icon.frame and other.frame:IsShown())

warrior.Config.Set("battleShoutEnabled", false)
assert(not icon.frame:IsShown())
assert(other.frame:IsShown(), "disabling Battle Shout does not hide another underlay")
warrior.Config.Set("battleShoutEnabled", true)
assert(not icon.frame:IsShown(), "outside combat only preview can show the underlay")
warrior.BattleShoutAura.Refresh = refresh
warrior.BattleShoutAura.Status = status
warrior.BattleShoutAura.ObservePlayerCast = observe
warrior.Config.Set("battleShoutMode", "tracked")
assert(not icon.frame:IsShown(), "tracked mode restores combat-only behavior")
assert(icon.texture.desaturation == 0)
assert(not icon.frame.clips)
warrior.Config.Set("battleShoutMode", "underlay")
assert(not icon.frame:IsShown(), "outside combat only preview can show the underlay")

w.combat = true
w:fire("PLAYER_REGEN_DISABLED")
assert(icon.frame:IsShown(), "entering combat shows the underlay again")

warrior:Stop()
assert(not icon.frame:IsShown())
print("Battle Shout underlay: PASS")
