local _, root = ...
local addon = {name = root.name, class = "WARRIOR", legacy = "WarriorAssistForever"}
root.RegisterModule("Warrior", addon)
addon.Client = root.Client
addon.Buttons = root.Buttons
addon.Glow = root.Glow

addon.features = {}
addon.started = false

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:Start()
    if self.started then
        return
    end

    self.started = true
    self.Config.Initialize()
    self.active = self.Client.IsWarrior()
    if not self.active then
        return
    end

    self:StartRuntime()
    self.BattleShoutAura.Initialize()
    self.BattleShoutIcon:Initialize()
    self.StanceIcon:Initialize()
    self:RegisterFeature(self.BattleShoutReminder)
    self.BattleShoutReminder:Initialize()
    self.ReactiveAbilities:Initialize()

    self.Config.Subscribe(function()
        self.BattleShoutIcon:ApplySettings()
        self.StanceIcon:ApplySettings()
        self.BattleShoutReminder:Refresh(false)
        self.ReactiveAbilities:Refresh()
    end)
    self.BattleShoutReminder:Refresh()
end

function addon:ClearPreviews()
    self.BattleShoutIcon:SetPreview(false)
    self.StanceIcon:SetPreview(false)
    self.ReactiveAbilities:ClearPreview()
end

function addon:Stop()
    self.BattleShoutReminder:Stop()
    self.ReactiveAbilities:Stop()
    self:ClearPreviews()
    self.active = false
end
