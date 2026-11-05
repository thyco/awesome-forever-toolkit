local _, root = ...
local Client = root.Client
local Tracker = {}
root.BuffTracker = Tracker
Tracker.__index = Tracker

function Tracker.New(groups, options)
    return setmetatable({groups = groups, options = options or {}, frames = root.TrackedBuffFrames.New()}, Tracker)
end

function Tracker:Invalidate()
    self.sampledAt = nil
end

local function directSpell(spellID)
    local secretAPI = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
    if secretAPI then
        if Client.Boolean(Client.Read(secretAPI, spellID)) ~= false then
            return 'unknown'
        end
    elseif InCombatLockdown() then
        return 'unknown'
    end

    local api = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(api) ~= 'function' then return 'unknown' end

    local ok, aura = pcall(api, spellID)
    if not ok or not Client.Readable(aura) then return 'unknown' end
    if aura == nil then return 'missing' end
    if Client.Table(aura) then return 'present' end
    return 'unknown'
end

local function directGroup(group)
    local complete = #group.spellIDs > 0
    for _, id in ipairs(group.spellIDs) do
        local state = directSpell(id)
        if state == 'present' then return state end
        if state ~= 'missing' then complete = false end
    end
    return complete and 'missing' or 'unknown'
end

function Tracker:Sample()
    local now = GetTime()
    local combat = InCombatLockdown()
    if not self.sampledAt or now - self.sampledAt >= 0.5 or combat ~= self.combat then
        self.direct = {}
        for _, group in ipairs(self.groups) do
            self.direct[group.key] = directGroup(group)
        end
        self.sampledAt, self.combat = now, combat
    end

    self.frames:Refresh()
    local detail = {groups = {}, source = 'unknown'}
    local present, complete = false, #self.groups > 0
    for _, group in ipairs(self.groups) do
        local direct = self.direct[group.key]
        local tracked, trackedDetail = self.frames:Sample(group, self.options.selfOnly == true)
        local state, source = direct, 'aura'
        if state == 'unknown' then
            state, source = tracked, 'cooldown-manager'
        end
        if state == 'unknown' then source = 'unknown' end

        detail.groups[#detail.groups + 1] = {
            key = group.key, state = state, source = source, aura = direct, tracked = tracked,
            trackedDetail = trackedDetail,
        }
        if state == 'present' then
            present = true
            detail.source = source
        end
        if state ~= 'missing' then complete = false end
    end

    if present then return 'present', detail end
    if complete then
        detail.source = 'confirmed-absence'
        return 'missing', detail
    end
    return 'unknown', detail
end
