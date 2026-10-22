local _, root = ...
local addon = root.modules.Hunter
local ReactiveAbilities = { running = false, elapsed = 0 }
addon.ReactiveAbilities = ReactiveAbilities

local kinds = { "mongoose", "counterattack" }
local events = {
    "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
    "SPELL_DATA_LOAD_RESULT", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ACTIONBAR_PAGE_CHANGED",
    "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "PLAYER_TARGET_CHANGED",
    "INPUT_DEVICE_INTERFACE_TRANSITION", "GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "ADDON_LOADED",
}
local rebuildEvents = { SPELLS_CHANGED = true, PLAYER_TALENT_UPDATE = true, SPELL_DATA_LOAD_RESULT = true }

local function emptyStatus()
    return { ready = false, active = false, signal = "unknown", cooldown = "unknown" }
end

local function enabled(kind)
    return addon.Config.Get(kind .. "GlowEnabled")
        or (kind == "counterattack" and addon.Config.Get("counterattackOverlayEnabled"))
end

local function colorFor(kind)
    if not addon.Config.Get(kind .. "NativeColor") then
        local red, green, blue = addon.Config.GetColor(kind .. "GlowColor")
        return { red, green, blue, 1 }
    end
end

local function selected(kind, uiMode)
    if uiMode == "gamepad" then
        return addon.Buttons.GamepadSelected(addon.Config.Get(kind .. "GamepadPage"),
            addon.Config.Get(kind .. "GamepadBar"), addon.Config.Get(kind .. "GamepadButton"))
    elseif uiMode == "keyboard" then
        return addon.Buttons.Selected(addon.Config.Get(kind .. "Bar"), addon.Config.Get(kind .. "Button"))
    end
end

local function visible(button)
    if not addon.Client.Readable(button) or not button then return false end

    local ok, shown = pcall(function() return button:IsVisible() end)
    return ok and addon.Client.Boolean(shown) == true
end

local function prepare(kind, button)
    if not button or not addon.Client.Readable(button) then return end

    addon.Glow.Prepare(button)
    if kind == "counterattack" and addon.Config.Get("counterattackOverlayEnabled") then
        addon.CounterattackOverlay:Prepare(button)
    end
end

function ReactiveAbilities:ClearPreview()
    addon.Glow.ClearOwner("hunter:preview")
    self.preview = nil
end

function ReactiveAbilities:Preview(kind, requestedMode)
    if not self.running or (kind ~= "mongoose" and kind ~= "counterattack") then
        return false, "Hunter reminders are not active."
    end
    if InCombatLockdown() or addon.Client.InCombat() then
        return false, "Preview is available outside combat."
    end

    local uiMode = addon.Buttons.Mode()
    if requestedMode and requestedMode ~= uiMode then return false, "Switch to the gamepad UI first." end
    if uiMode ~= "keyboard" and uiMode ~= "gamepad" then
        return false, "The active action-bar UI is unavailable."
    end

    local button = selected(kind, uiMode)
    if not visible(button) then
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
        for _, event in ipairs(events) do self.frame:RegisterEvent(event) end
        self.frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self.frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        self.frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
            if event == "PLAYER_LEAVING_WORLD" then
                self:Stop()
                return
            elseif event == "PLAYER_ENTERING_WORLD" then
                self:Initialize()
                return
            end

            if rebuildEvents[event] then addon.ReactiveSpells.Rebuild() end
            if event == "PLAYER_REGEN_ENABLED" then addon.ReactiveSpells.ResetEvidence() end
            if event == "SPELL_UPDATE_COOLDOWN" then addon.ReactiveSpells.ObserveCooldownEvent() end
            if event == "UNIT_SPELLCAST_SUCCEEDED" then addon.ReactiveSpells.ReactiveCast(unit, spellID) end

            self:Refresh()
        end)
    end

    self.running = true
    addon.ReactiveSpells.Rebuild()
    self:Refresh()
end

function ReactiveAbilities:Refresh()
    if not self.running then return end

    local uiMode = addon.Buttons.Mode()
    local canPrepare = not InCombatLockdown()
    self.status = { uiMode = uiMode }
    self.buttons = self.buttons or {}
    local polling = false
    local preview = self.preview
    if preview and (not canPrepare or GetTime() >= preview.expires or uiMode ~= preview.uiMode
        or selected(preview.kind, uiMode) ~= preview.button or not visible(preview.button)) then
        self:ClearPreview()
    end

    for _, kind in ipairs(kinds) do
        local owner = "hunter:" .. kind
        addon.Glow.ConfigureOwner(owner, { color = colorFor(kind) })

        if enabled(kind) then
            polling = polling or addon.Config.Get(kind .. "Bar") ~= 0
                or addon.Config.Get(kind .. "GamepadPage") ~= 0
            if canPrepare then
                prepare(kind, selected(kind, "keyboard"))
                if addon.Config.Get(kind .. "GamepadPage") ~= 0 then
                    for _, candidate in ipairs(addon.Buttons.GamepadCandidates(
                        addon.Config.Get(kind .. "GamepadBar"), addon.Config.Get(kind .. "GamepadButton"))) do
                        prepare(kind, candidate)
                    end
                end
            end
        end

        local button = selected(kind, uiMode)
        local previous = self.buttons[kind]
        if previous and previous ~= button then addon.Glow.Set(previous, owner, false) end
        self.buttons[kind] = button

        local status = emptyStatus()
        if enabled(kind) and addon.Client.InCombat() and visible(button) then
            status = addon.ReactiveSpells.Evaluate(kind)
            status.active = status.ready and addon.Config.Get(kind .. "GlowEnabled")
                and addon.Glow.IsPrepared(button)
        end

        if button then
            addon.Glow.Set(button, owner, status.active)
            if uiMode == "gamepad" then addon.Glow.RefreshGeometry(button) end
        end
        if kind == "counterattack" then
            addon.CounterattackOverlay:Set(button,
                status.ready and addon.Config.Get("counterattackOverlayEnabled"))
        end
        self.status[kind] = status
    end

    preview = self.preview
    if preview then
        addon.Glow.ConfigureOwner("hunter:preview", { color = colorFor(preview.kind), priority = 100 })
        addon.Glow.Set(preview.button, "hunter:preview", true)
        addon.Glow.RefreshGeometry(preview.button)
        polling = true
    end

    if polling and not self.polling then
        self.elapsed = 0
        self.frame:SetScript("OnUpdate", function(_, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 0.1 then
                self.elapsed = 0
                self:Refresh()
            end
        end)
    elseif not polling then
        self.frame:SetScript("OnUpdate", nil)
        self.elapsed = 0
    end
    self.polling = polling
end

function ReactiveAbilities:Stop()
    self:ClearPreview()
    self.running, self.polling, self.elapsed = false, false, 0
    if self.frame then self.frame:SetScript("OnUpdate", nil) end

    for _, kind in ipairs(kinds) do addon.Glow.ClearOwner("hunter:" .. kind) end
    addon.CounterattackOverlay:Stop()
    addon.ReactiveSpells.ResetEvidence()
    self.buttons = {}
    self.status = { uiMode = "unknown", mongoose = emptyStatus(), counterattack = emptyStatus() }
end

function ReactiveAbilities:Status()
    return self.status or { uiMode = "unknown", mongoose = emptyStatus(), counterattack = emptyStatus() }
end
