local _, root = ...
local addon = root.modules.Warrior
local ReactiveAbilities = { running = false, elapsed = 0 }
addon.ReactiveAbilities = ReactiveAbilities

local executeStyle = { native = "executeNativeColor", custom = "executeGlowColor" }
local victoryRushStyle = { native = "victoryRushNativeColor", custom = "victoryRushGlowColor" }
local shieldBlockStyle = { native = "shieldBlockNativeColor", custom = "shieldBlockGlowColor" }
local definitions = {
    overpower = { owner = "warrior:overpower", enabled = "overpowerEnabled",
        bar = "overpowerBar", button = "overpowerButton",
        modes = { battle = "usable", berserker = "overlay" },
        colors = {
            battle = { native = "overpowerBattleNativeColor", custom = "overpowerBattleGlowColor" },
            berserker = { native = "overpowerBerserkerNativeColor", custom = "overpowerBerserkerGlowColor" },
        } },
    revenge = { owner = "warrior:revenge", enabled = "revengeEnabled",
        bar = "revengeBar", button = "revengeButton",
        modes = { defensive = "usable" },
        colors = {
            defensive = { native = "revengeNativeColor", custom = "revengeGlowColor" },
        } },
    execute = { owner = "warrior:execute", enabled = "executeEnabled",
        bar = "executeBar", button = "executeButton",
        modes = { battle = "usable", berserker = "usable" },
        colors = { battle = executeStyle, berserker = executeStyle } },
    victoryRush = { owner = "warrior:victoryRush", enabled = "victoryRushEnabled",
        bar = "victoryRushBar", button = "victoryRushButton",
        combatOnly = "victoryRushCombatOnly",
        modes = { battle = "usable", defensive = "usable", berserker = "usable" },
        colors = { battle = victoryRushStyle, defensive = victoryRushStyle,
            berserker = victoryRushStyle } },
    shieldBlock = { owner = "warrior:shieldBlock", enabled = "shieldBlockEnabled",
        bar = "shieldBlockBar", button = "shieldBlockButton",
        requiresCombat = true, requiresShield = true,
        modes = { defensive = "usable" },
        colors = { defensive = shieldBlockStyle } },
}
local order = { "overpower", "revenge", "execute", "victoryRush", "shieldBlock" }
local events = {
    "UPDATE_SHAPESHIFT_FORM", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELL_DATA_LOAD_RESULT",
    "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "ACTIONBAR_PAGE_CHANGED", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE",
    "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_TARGET_CHANGED",
    "INPUT_DEVICE_INTERFACE_TRANSITION", "GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "ADDON_LOADED",
}
local rebuildEvents = {
    SPELLS_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    SPELL_DATA_LOAD_RESULT = true,
}

local function emptyStatus()
    return { ready = false, signal = "unknown", cooldown = "unknown", range = "unknown", active = false }
end

local function selected(kind, definition, uiMode)
    if uiMode == "gamepad" then
        return addon.Buttons.GamepadSelected(
            addon.Config.Get(kind .. "GamepadPage"),
            addon.Config.Get(kind .. "GamepadBar"),
            addon.Config.Get(kind .. "GamepadButton"))
    elseif uiMode ~= "keyboard" then
        return nil
    end

    local bar = addon.Config.Get(definition.bar)
    local index = addon.Config.Get(definition.button)
    if bar == 0 then
        return nil
    end

    return addon.Buttons.Selected(bar, index)
end

local function pollingNeeded()
    if ReactiveAbilities.preview then return true end

    for _, kind in ipairs(order) do
        local definition = definitions[kind]
        if addon.Config.Get(definition.enabled) and (addon.Config.Get(definition.bar) ~= 0
            or addon.Config.Get(kind .. "GamepadPage") ~= 0) then
            return true
        end
    end

    return false
end

local function visible(button)
    if not addon.Client.Readable(button) then
        return false
    end

    local ok, shown = pcall(function() return button:IsVisible() end)
    return ok and addon.Client.Boolean(shown) == true
end

function ReactiveAbilities:ClearPreview()
    if self.preview then
        addon.Glow.ClearOwner("warrior:preview")
        self.preview = nil
    end
end

function ReactiveAbilities:Preview(kind, requestedMode)
    if not self.running or not definitions[kind] then return false, "Warrior reminders are not active." end
    if InCombatLockdown() or addon.Client.InCombat() then
        return false, "Preview is available outside combat."
    end
    local uiMode = addon.Buttons.Mode()
    if requestedMode and uiMode ~= requestedMode then return false, "Switch to the gamepad UI first." end
    if uiMode ~= "keyboard" and uiMode ~= "gamepad" then
        return false, "The active action-bar UI is unavailable."
    end

    local button = selected(kind, definitions[kind], uiMode)
    if not button or not visible(button) then
        return false, uiMode == "gamepad"
            and "Select a gamepad destination, then show its page and set."
            or "Select a standard action bar and button, then show that bar."
    end

    self:ClearPreview()
    addon.Glow.Prepare(button)
    self.preview = { kind = kind, button = button, uiMode = uiMode, expires = GetTime() + 3 }
    self:Refresh()

    return true
end

function ReactiveAbilities:PreviewGamepad(kind)
    return self:Preview(kind, "gamepad")
end

function ReactiveAbilities:Initialize()
    if not self.frame then
        self.frame = CreateFrame("Frame")
        for _, event in ipairs(events) do
            self.frame:RegisterEvent(event)
        end

        self.frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")

        self.frame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_LEAVING_WORLD" then
                self:Stop()
                return
            end

            if event == "PLAYER_ENTERING_WORLD" then
                self:Initialize()
                return
            end

            if rebuildEvents[event] then
                addon.ReactiveSpells.Rebuild()
            end

            if event == "SPELL_UPDATE_COOLDOWN" then
                addon.ReactiveSpells.ObserveCooldownEvent()
            end

            self:Refresh()
        end)
    end

    self.running = true
    addon.ReactiveSpells.Rebuild()
    for _, kind in ipairs(order) do
        addon.Glow.ConfigureOwner(definitions[kind].owner, {})
    end

    self:Refresh()
end

function ReactiveAbilities:Refresh()
    if not self.running then
        return
    end

    local stance = addon.Stance.Current()
    local uiMode = addon.Buttons.Mode()
    self.status = { stance = stance, uiMode = uiMode }
    local canPrepare = not InCombatLockdown()

    local preview = self.preview
    if preview and (not canPrepare or GetTime() >= preview.expires or uiMode ~= preview.uiMode
        or selected(preview.kind, definitions[preview.kind], uiMode) ~= preview.button
        or not visible(preview.button)) then
        self:ClearPreview()
    end

    for _, kind in ipairs(order) do
        local definition = definitions[kind]
        local style = definition.colors[stance]
        local color
        if style and not addon.Config.Get(style.native) then
            color = addon.Config.GetColor(style.custom)
        end

        addon.Glow.ConfigureOwner(definition.owner, { color = color })

        if canPrepare and addon.Config.Get(definition.enabled) then
            local keyboard = addon.Buttons.Selected(addon.Config.Get(definition.bar),
                addon.Config.Get(definition.button))
            if keyboard and addon.Client.Readable(keyboard) then addon.Glow.Prepare(keyboard) end

            if addon.Config.Get(kind .. "GamepadPage") ~= 0 then
                for _, candidate in ipairs(addon.Buttons.GamepadCandidates(
                    addon.Config.Get(kind .. "GamepadBar"), addon.Config.Get(kind .. "GamepadButton"))) do
                    addon.Glow.Prepare(candidate)
                end
            end
        end

        local button = selected(kind, definition, uiMode)
        local previous = self.buttons and self.buttons[kind]
        if previous and previous ~= button then
            addon.Glow.Set(previous, definition.owner, false)
        end

        self.buttons = self.buttons or {}
        self.buttons[kind] = button

        local shown = button and visible(button)
        if button and shown and canPrepare then
            addon.Glow.Prepare(button)
        end

        local status = emptyStatus()
        local mode = definition.modes[stance]
        local combatAllowed = not definition.combatOnly
            or not addon.Config.Get(definition.combatOnly) or addon.Client.InCombat()
        if addon.Config.Get(definition.enabled) and mode and shown
            and combatAllowed
            and (not definition.requiresCombat or addon.Client.InCombat())
            and (not definition.requiresShield or addon.Client.HasShield()) then
            local result = addon.ReactiveSpells.Evaluate(kind, mode)
            status.ready = result.ready
            status.signal = result.signal
            status.cooldown = result.cooldown
            status.range = result.range
            status.active = result.ready and addon.Glow.IsPrepared(button)
        end

        if button then
            addon.Glow.Set(button, definition.owner, status.active)
            if uiMode == "gamepad" then addon.Glow.RefreshGeometry(button) end
        end

        self.status[kind] = status
    end

    preview = self.preview
    if preview then
        local colors = definitions[preview.kind].colors
        local style = colors[stance] or colors.battle or colors.defensive
        local color = not addon.Config.Get(style.native) and addon.Config.GetColor(style.custom) or nil
        addon.Glow.ConfigureOwner("warrior:preview", { color = color, priority = 100 })
        addon.Glow.Set(preview.button, "warrior:preview", true)
        addon.Glow.RefreshGeometry(preview.button)
    end

    if pollingNeeded() then
        if not self.polling then
            self.elapsed = 0
            self.frame:SetScript("OnUpdate", function(_, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= 0.1 then
                    self.elapsed = 0
                    self:Refresh()
                end
            end)
            self.polling = true
        end
    elseif self.polling then
        self.frame:SetScript("OnUpdate", nil)
        self.polling = false
        self.elapsed = 0
    end
end

function ReactiveAbilities:Stop()
    self:ClearPreview()
    self.running = false
    self.elapsed = 0
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
    self.polling = false

    for _, kind in ipairs(order) do
        addon.Glow.ClearOwner(definitions[kind].owner)
    end

    self.buttons = {}
    self.status = { stance = "unknown", overpower = emptyStatus(),
        revenge = emptyStatus(), execute = emptyStatus(), victoryRush = emptyStatus(),
        shieldBlock = emptyStatus() }
end

function ReactiveAbilities:Status()
    return self.status or { stance = "unknown", overpower = emptyStatus(),
        revenge = emptyStatus(), execute = emptyStatus(), victoryRush = emptyStatus(),
        shieldBlock = emptyStatus() }
end
