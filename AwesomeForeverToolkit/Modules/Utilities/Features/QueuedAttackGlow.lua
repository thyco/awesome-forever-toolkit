local _, root = ...
local addon = root.modules.Utilities
local feature = { buttons = {}, dirty = true, active = 0 }
addon.QueuedAttackGlow = feature

function feature:Enabled()
    return addon.Config.Get('highlightQueuedAttacks')
end

function feature:MarkDirty()
    self.dirty = true
end

local function isQueued(spellID)
    local api = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
    return addon.Client.Boolean(addon.Client.Read(api, spellID)) == true
end

local function overrideVisuals()
    local gamepad = root.modules.Gamepad
    local provider = gamepad and gamepad.active and gamepad.Visuals
    if type(provider) ~= "table" or provider.version ~= 1 then return {}, {} end

    local function read(method)
        if type(method) ~= "function" then return {} end
        local ok, result = pcall(method)
        return ok and type(result) == "table" and result or {}
    end
    return read(provider.GetEntries), read(provider.GetFrames)
end

function feature:Refresh(discover, rebuild)
    if rebuild then
        self.dirty = true
    end

    if rebuild and not addon.RangeCheck:Enabled() then
        addon.NextSwing:Rebuild(addon.Client.PlayerSpells())
    end

    if discover then
        local current = addon.Buttons.All()
        addon.Buttons.ReleaseRemoved(self.buttons, current, function(button)
            addon.QueuedGlow.Set(button, false)
        end)
        self.buttons = current
        for _, button in ipairs(self.buttons) do
            addon.QueuedGlow.Prepare(button)
        end
        self.dirty = true
    end

    local overlays, frames = overrideVisuals()
    for _, button in ipairs(frames) do addon.QueuedGlow.Prepare(button) end

    local covered = {}
    for _, entry in ipairs(overlays) do
        if entry.nativeButton then covered[entry.nativeButton] = true end
    end
    for button in pairs(covered) do
        if not self.covered or not self.covered[button] then self.dirty = true end
    end
    for button in pairs(self.covered or {}) do
        if not covered[button] then self.dirty = true end
    end
    self.covered = covered

    if self.dirty then
        self.dirty = false
        self.nativeActive = 0
        for _, button in ipairs(self.buttons) do
            local queued = false
            if not covered[button] and addon.Client.Boolean(addon.Client.Read(button.IsVisible, button)) == true then
                local kind, id, subtype = addon.Client.ActionInfo(button.action)
                queued = addon.NextSwing:ForAction(button.action, nil, kind, id, subtype) ~= nil
                    and addon.Client.Boolean(addon.Client.Read(button.GetChecked, button)) == true
            end

            addon.QueuedGlow.Set(button, queued)
            if queued then self.nativeActive = self.nativeActive + 1 end
        end
    end

    -- Override visuals have no action slot or Blizzard checked state. Poll the
    -- actual spell, including macro branches, even without an action-bar event.
    self.active = self.nativeActive or 0
    local seen = {}
    for _, entry in ipairs(overlays) do
        local button = entry.button
        if button and addon.Client.Boolean(addon.Client.Read(button.IsVisible, button)) == true then
            seen[button] = true
            local queued = addon.NextSwing:ForOverlay(entry, isQueued) ~= nil
            addon.QueuedGlow.Set(button, queued)
            if queued then self.active = self.active + 1 end
        end
    end
    for button in pairs(self.overrideButtons or {}) do
        if not seen[button] then addon.QueuedGlow.Set(button, false) end
    end
    self.overrideButtons = seen
end

function feature:Stop()
    addon.QueuedGlow.Clear()
    self.active, self.nativeActive = 0, 0
    self.overrideButtons, self.covered = {}, {}
    self.dirty = true
end

addon:RegisterFeature(feature)
