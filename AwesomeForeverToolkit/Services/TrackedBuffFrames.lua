local _, root = ...
local Client = root.Client
local Frames = {}
root.TrackedBuffFrames = Frames
Frames.__index = Frames

function Frames.New()
    return setmetatable({records = {}}, Frames)
end

local function editing(item)
    for _, method in ipairs({'IsEditing', 'HasEditModeData'}) do
        if type(item[method]) == 'function' then
            local ok, value = pcall(item[method], item)
            if not ok or not Client.Readable(value) or (value ~= nil and value ~= false) then
                return true
            end
        end
    end
    return false
end

local function enumerate(viewer)
    local ok, items = pcall(function()
        local result = {}
        local pool = viewer.itemFramePool
        if not pool or type(pool.EnumerateActive) ~= 'function' then
            return nil
        end

        for item in pool:EnumerateActive() do
            result[#result + 1] = item
        end
        return result
    end)
    return ok and items or nil
end

local function identify(item)
    local cooldownID = Client.Number(Client.Read(item.GetCooldownID, item))
    local spellID = Client.Number(Client.Read(item.GetSpellID, item))
    local info = cooldownID and Client.Read(C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
    local ids = {}
    if spellID then ids[spellID] = true end

    if Client.Table(info) then
        for _, key in ipairs({'spellID', 'overrideSpellID'}) do
            local id = Client.Number(info[key])
            if id then ids[id] = true end
        end
    end

    if not next(ids) then return nil end
    return {cooldownID = cooldownID, ids = ids}
end

-- Only tracked-buff viewers qualify. An ability button's visibility says
-- nothing about buff presence. Refresh membership even during combat so a
-- released or recycled frame cannot retain a previous spell's identity.
function Frames:Refresh()
    local current = {}
    for _, name in ipairs({'BuffIconCooldownViewer', 'BuffBarCooldownViewer'}) do
        local viewer = _G[name]
        if viewer then
            local items = enumerate(viewer)
            for _, item in ipairs(items or {}) do
                local record = self.records[item]
                if not InCombatLockdown() then
                    record = identify(item)
                elseif record then
                    local id = Client.Number(Client.Read(item.GetCooldownID, item))
                    if not id or id ~= record.cooldownID then record = nil end
                end

                if record then
                    record.viewer = viewer
                    current[item] = record
                end
            end
        end
    end
    self.records = current
end

local function settingsOpen()
    for _, name in ipairs({'CooldownViewerSettings', 'EditModeManagerFrame'}) do
        local frame = _G[name]
        if frame and Client.Boolean(Client.Read(frame.IsShown, frame)) ~= false then
            return true
        end
    end
    return false
end

function Frames:Sample(group, selfOnly)
    if settingsOpen() then return 'unknown', 'settings-or-edit-mode' end

    local missing = false
    local reason = 'not-tracked'
    for item, record in pairs(self.records) do
        local matches = false
        for _, id in ipairs(group.spellIDs) do
            if record.ids[id] then matches = true; break end
        end

        if matches then
            if Client.Boolean(Client.Read(record.viewer.IsVisible, record.viewer)) ~= true then
                reason = 'viewer-hidden-or-unreadable'
            elseif editing(item) then
                reason = 'editing'
            elseif Client.Boolean(item.allowHideWhenInactive) ~= true
                or Client.Boolean(item.hideWhenInactive) ~= true then
                reason = 'not-configured-to-hide-when-inactive'
            else
                local shown = Client.Boolean(Client.Read(item.IsShown, item))
                if shown == true then
                    local unit = Client.Read(item.GetAuraDataUnit, item)
                    if selfOnly or (Client.String(unit) and unit == 'player') then
                        return 'present', 'shown-player-buff'
                    end
                    reason = 'shown-target-or-unknown-unit'
                elseif shown == false then
                    missing = missing or selfOnly
                    reason = 'hidden-own-cast-entry'
                else
                    reason = 'unreadable-visibility'
                end
            end
        end
    end

    -- Hidden own-cast frames cannot exclude buffs from other players. Only
    -- consumers declaring inherently self-only buffs may use this negative.
    return missing and 'missing' or 'unknown', reason
end
