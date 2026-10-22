local _, root = ...
local addon = {name = root.name, class = "HUNTER", legacy = "HunterAssistForever",
    gcdSpellID = 61304, features = {}, started = false}
root.RegisterModule("Hunter", addon)
addon.Client, addon.Buttons, addon.Glow = root.Client, root.Buttons, root.Glow

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:IsFeatureEnabled(feature)
    return not feature.settingKey or self.Config.Get(feature.settingKey) == true
end

function addon:ApplySettings()
    for _, feature in ipairs(self.features) do
        if self:IsFeatureEnabled(feature) then feature:ApplySettings() else feature:Stop() end
    end
    if self.ReactiveAbilities then self.ReactiveAbilities:Refresh() end
end

function addon:Start()
    if self.started then return end

    self.started = true
    self.Config.Initialize()
    for _, feature in ipairs(self.features) do feature:Initialize() end
    if self.ReactiveAbilities then self.ReactiveAbilities:Initialize() end

    self.Config.Subscribe(function(key)
        if key == "petFlashColor" or key == "petFlashIntensity" then
            self.PetWarning.ApplyFlashAppearance()
        else
            self:ApplySettings()
        end
    end)
    self:ApplySettings()
end

function addon:ClearPreviews()
    for _, key in ipairs({"AmmoIcon", "PetHealthIcon", "PetHappinessIcon", "AspectIcon"}) do
        if self[key] then self[key]:SetPreview(false) end
    end
    if self.PetWarning then self.PetWarning.SetPreview(false) end
    if self.ReactiveAbilities then self.ReactiveAbilities:ClearPreview() end
end

function addon:Stop()
    self:ClearPreviews()
    for _, feature in ipairs(self.features) do feature:Stop() end
    if self.ReactiveAbilities then self.ReactiveAbilities:Stop() end
    self.active = false
end

function addon:Diagnostics(command)
    if command == "config" then
        root.Window:Open()
        root.Window:ShowPage("hunter.reminders")
        return
    end

    self.ReactiveAbilities:Refresh()
    local status = self.ReactiveAbilities:Status()
    print("Awesome Forever Toolkit: Hunter / " .. status.uiMode)
    for _, item in ipairs({{"mongoose", "Mongoose Bite"}, {"counterattack", "Counterattack"}}) do
        local kind, title = item[1], item[2]
        local state = status[kind]
        print(title .. ": " .. (#self.ReactiveSpells.ids[kind] > 0 and "learned" or "not learned")
            .. " / signal " .. state.signal .. " / cooldown " .. state.cooldown
            .. " / glow " .. (state.active and "active" or "inactive"))
    end
end
