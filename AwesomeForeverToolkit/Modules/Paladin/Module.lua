local _, root = ...
local addon = { name = root.name, class = 'PALADIN', legacy = 'PaladinAssistForever', features = {} }
root.RegisterModule('Paladin', addon)
addon.Buttons, addon.Glow = root.Buttons, root.Glow

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:IsFeatureEnabled(feature)
    return not feature.settingKey or self.Config.Get(feature.settingKey) == true
end

function addon:IsVisible(button)
    return button and root.Client.Boolean(root.Client.Read(button.IsVisible, button)) == true
end

function addon:Selected(kind)
    local mode = self.Buttons.Mode()
    if mode == 'keyboard' then
        return self.Buttons.Selected(self.Config.Get(kind .. 'Bar'), self.Config.Get(kind .. 'Button'))
    elseif mode ~= 'gamepad' then
        return nil
    end

    local native = self.Buttons.GamepadSelected(self.Config.Get(kind .. 'GamepadPage'),
        self.Config.Get(kind .. 'GamepadBar'), self.Config.Get(kind .. 'GamepadButton'))
    local gamepad = root.modules.Gamepad
    if native and gamepad and gamepad.active and gamepad.Visuals then
        for _, entry in ipairs(gamepad.Visuals.GetEntries()) do
            if entry.nativeButton == native then return entry.button end
        end
    end
    return native
end

function addon:PrepareButtons()
    local buttons = self.Buttons.All()
    local gamepad = root.modules.Gamepad
    if gamepad and gamepad.active and gamepad.Visuals then
        for _, button in ipairs(gamepad.Visuals.GetFrames()) do buttons[#buttons + 1] = button end
    end
    for _, button in ipairs(buttons) do
        self.Glow.Prepare(button)
        self.ButtonDesaturation.Prepare(button)
    end
end

function addon:ApplySettings()
    for _, feature in ipairs(self.features) do
        feature:ApplySettings()
        if not self:IsFeatureEnabled(feature) then feature:Stop() end
    end
    self:Refresh(true)
end

function addon:Refresh(discover, cooldownEvent)
    if not self.active then return end
    if discover then self:PrepareButtons() end

    for _, feature in ipairs(self.features) do
        if self:IsFeatureEnabled(feature) then
            feature:Refresh(discover, cooldownEvent)
            if feature.button then self.Glow.RefreshGeometry(feature.button) end
        end
    end

    if self.preview and (GetTime() >= self.preview.expires or InCombatLockdown()
        or self.Buttons.Mode() ~= self.preview.mode or self:Selected(self.preview.kind) ~= self.preview.button
        or not self:IsVisible(self.preview.button)) then
        self:ClearPreviews()
    elseif self.preview then
        self.Glow.RefreshGeometry(self.preview.button)
    end
end

function addon:ClearPreviews()
    self.Glow.ClearOwner('paladin:preview')
    self.preview = nil
    self.RighteousFuryReminder:SetPreview(false)
end

function addon:Preview(kind)
    if not self.active or InCombatLockdown() or root.Client.InCombat() then
        return false, 'Preview is available outside combat.'
    end
    local button = self:Selected(kind)
    if not self:IsVisible(button) then return false, 'Select a destination and show its action bar or gamepad page.' end

    self:ClearPreviews()
    self.Glow.Prepare(button)
    local native = kind == 'holyStrike' and 'glowNativeColor' or 'exorcismNativeColor'
    local colorKey = kind == 'holyStrike' and 'glowColor' or kind .. 'GlowColor'
    local color = (kind == 'seal' or not self.Config.Get(native)) and self.Config.GetColor(colorKey) or nil
    self.Glow.ConfigureOwner('paladin:preview', { color = color, priority = 100 })
    self.Glow.Set(button, 'paladin:preview', true)
    self.preview = { kind = kind, button = button, mode = self.Buttons.Mode(), expires = GetTime() + 3 }
    return true
end

function addon:Start()
    if self.started then return end
    self.started = true
    self.Config.Initialize()
    self.Config.Subscribe(function() self:ApplySettings() end)
    self:ApplySettings()
    self:StartRuntime()
end

function addon:Stop()
    self:ClearPreviews()
    for _, feature in ipairs(self.features) do feature:Stop() end
    self.active = false
    if self.frame then self.frame:UnregisterAllEvents() end
end

function addon:Diagnostics(command)
    if command == 'config' then
        root.Window:Open()
        root.Window:ShowPage('paladin.abilities')
        return
    end
    print('Awesome Forever Toolkit: Paladin / ' .. self.Buttons.Mode())
    for _, kind in ipairs({'holyStrike', 'exorcism', 'seal'}) do
        print(kind .. ': ' .. self.Buttons.SelectionLabel(self.Config, kind))
    end
    print('Seal refresh due in: ' .. string.format('%.1fs', self.SealReminder.timer:Remaining()))
    print('Righteous Fury due in: ' .. string.format('%.1fs', self.RighteousFuryReminder.timer:Remaining()))
end
