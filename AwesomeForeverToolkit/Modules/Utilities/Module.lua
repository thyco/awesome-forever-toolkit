local _, root = ...
local addon = {name = root.name, version = root.version, legacy = "UtilsAssistForever"}
root.RegisterModule("Utilities", addon)
addon.Client = root.Client
addon.Buttons = root.Buttons

addon.features = {}
addon.started = false
addon.running = false

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:StartFeatures()
    if self.started then
        return
    end

    self.started = true
    if self.TargetCastbar then self.TargetCastbar:Start() end
    self.Config.Subscribe(function(key)
        if key == "queuedGlowColor" or key == "queuedGlowNativeColor" then
            self.QueuedGlow.SetColor()
        else
            self:ApplySettings()
        end
    end)
    self:ApplySettings()
end

function addon:ApplySettings()
    self.running = false
    for _, feature in ipairs(self.features) do
        if feature:Enabled() then
            self.running = true
        else
            feature:Stop()
        end
    end

    self:SetPolling(self.running)
    if self.running then
        self:Refresh(true, true)
    end
end

function addon:Refresh(discover, rebuild, refreshCooldown)
    if not self.started or not self.running then
        return
    end

    for _, feature in ipairs(self.features) do
        if feature:Enabled() and (feature ~= self.CooldownGrey or refreshCooldown ~= false) then
            feature:Refresh(discover, rebuild)
        end
    end
end

function addon:ClearPreviews()
    if self.TargetCastbar then self.TargetCastbar:ClosePreview() end
end

function addon:Stop()
    if self.TargetCastbar then self.TargetCastbar:Stop() end
    for _, feature in ipairs(self.features) do feature:Stop() end
    self.running = false
    self:SetPolling(false)
end
