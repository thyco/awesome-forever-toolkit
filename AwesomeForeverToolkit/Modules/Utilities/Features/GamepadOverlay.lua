local _, root = ...
local addon = root.modules.Utilities
local feature = { tracked = {} }
addon.GamepadOverlay = feature

function feature:Enabled()
    return addon.Config.Get("checkRangedAbilities") or addon.Config.Get("checkMeleeAbilities")
        or addon.Config.Get("greyOnCooldown")
end

local function clear(button)
    addon.IconTint.Set(button, false)
    addon.IconTint.SetCooldown(button, false)
end

local function entries()
    local provider = GamepadAssistForeverVisuals
    if type(provider) ~= "table" or provider.version ~= 1 or type(provider.GetEntries) ~= "function" then
        return {}, {}
    end

    local frames = {}
    if type(provider.GetFrames) == "function" then
        local ok, result = pcall(provider.GetFrames)
        if ok and type(result) == "table" then frames = result end
    end

    local ok, result = pcall(provider.GetEntries)
    return ok and type(result) == "table" and result or {}, frames
end

local function outOfRange(range, entry, spellID)
    local nextSwing = addon.NextSwing
    if entry.macroName then
        local queued, inspected = addon.Macros:NextSwingByName(entry.macroName, range.unit, nextSwing.names)
        if queued then return range:IsMeleeOutOfRange() end
        if inspected and addon.Client.Number(spellID) and nextSwing.ids[spellID] then return false end
    end

    if addon.Client.Number(spellID) and nextSwing.ids[spellID] then
        return range:IsMeleeOutOfRange()
    end
    return range:IsOutOfRange(spellID)
end

function feature:Refresh(_, rebuild)
    local current, frames = entries()
    -- Context overlays can first become visible in combat. Install the hooks on
    -- their already-created hidden visual frames while still outside combat.
    for _, button in ipairs(frames) do addon.IconTint.Prepare(button) end

    if #current > 0 then
        -- RangeCheck normally owns catalog rebuilding; keep this feature usable
        -- when only cooldown greying is enabled. Sampling stays independent.
        if rebuild and not addon.RangeCheck:Enabled() then addon.Range:Rebuild() end
        self.range = self.range or setmetatable({}, {__index = addon.Range})
        self.range.spells = addon.Range.spells
        self.range:BeginUpdate()
    end

    local seen = {}
    for _, entry in ipairs(current) do
        local button = entry.button
        if button and addon.Client.Boolean(button:IsVisible()) == true and addon.IconTint.Prepare(button) then
            seen[button] = true
            local spellID = entry.spellID
            if entry.macroName then spellID = addon.Client.Read(GetMacroSpell, entry.macroName) end

            addon.IconTint.Set(button, outOfRange(self.range, entry, spellID))
            local grey = false
            if addon.Config.Get("greyOnCooldown") then grey = addon.Cooldown.Action(nil, spellID) end
            addon.IconTint.SetCooldown(button, grey)
        end
    end

    for button in pairs(self.tracked) do
        if not seen[button] then clear(button) end
    end
    self.tracked = seen
end

function feature:Stop()
    for button in pairs(self.tracked) do clear(button) end
    self.tracked = {}
end

addon:RegisterFeature(feature)
