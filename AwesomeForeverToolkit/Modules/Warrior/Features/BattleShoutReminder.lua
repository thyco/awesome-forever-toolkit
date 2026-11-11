local _, root = ...
local addon = root.modules.Warrior
local Reminder = { output = "none", running = false }
addon.BattleShoutReminder = Reminder

function Reminder:Initialize()
    self.running = true
end

function Reminder:Refresh()
    if not self.running then return end

    local enabled = addon.Config.Get("battleShoutEnabled")
    local combat = addon.Client.InCombat()
    local visible = enabled and combat
    self.output = visible and "underlay" or "none"

    if not enabled or combat then
        addon.BattleShoutIcon:SetPreview(false)
    end
    addon.BattleShoutIcon:SetVisible(visible)
end

function Reminder:Stop()
    self.running = false
    self.output = "none"

    addon.BattleShoutIcon:SetPreview(false)
    addon.BattleShoutIcon:SetVisible(false)
end

function Reminder:Status()
    return { output = self.output }
end
