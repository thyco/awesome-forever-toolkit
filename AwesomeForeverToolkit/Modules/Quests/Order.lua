local _, root = ...
local addon = root.modules.Quests
local Client = root.Client
local Order = {}
addon.Order = Order

local function readWatches()
    local api = C_QuestLog
    local count = Client.Number(Client.Read(api and api.GetNumQuestWatches))
    if not count then return nil end

    local list, seen = {}, {}
    for index = 1, count do
        local id = Client.Number(Client.Read(api.GetQuestIDForQuestWatchIndex, index))
        if not id or seen[id] then return nil end
        list[index], seen[id] = id, true
    end
    return list
end

local function contains(list, id)
    for _, value in ipairs(list or {}) do
        if value == id then return true end
    end
    return false
end

local function currentZones()
    local names = {}
    for _, api in ipairs({GetRealZoneText or false, GetZoneText or false}) do
        local name = Client.Read(api)
        if Client.String(name) then names[name] = true end
    end

    local map = Client.Number(Client.Read(C_Map and C_Map.GetBestMapForUnit, 'player'))
    for _ = 1, 8 do
        if not map or map == 0 then break end
        local info = Client.Read(C_Map and C_Map.GetMapInfo, map)
        if not Client.Table(info) then break end
        if Client.String(info.name) then names[info.name] = true end
        map = Client.Number(info.parentMapID)
    end
    return names
end

function Order:Metadata()
    local entries = Client.Number(Client.Read(C_QuestLog and C_QuestLog.GetNumQuestLogEntries))
    if not entries then return nil end

    local result, names = {}, currentZones()
    local zone, group = 'Uncategorized', math.huge
    for index = 1, entries do
        local info = Client.Read(C_QuestLog.GetInfo, index)
        if Client.Table(info) then
            if Client.Boolean(info.isHeader) == true then
                zone = Client.String(info.title) and info.title or 'Uncategorized'
                group = index
            else
                local id = Client.Number(info.questID)
                if id then
                    local level = Client.Number(info.difficultyLevel) or Client.Number(info.level)
                    result[id] = {id = id, zone = zone, group = group, logIndex = index,
                        current = names[zone] == true, level = level and level > 0 and level or nil}
                end
            end
        end
    end
    return result
end

function Order:Desired(watches, metadata)
    local ordered = {}
    for index, id in ipairs(watches) do
        if not metadata[id] then return nil end
        ordered[index] = metadata[id]
    end

    local grouping = addon.Config.Get('groupZones')
    local direction = addon.Config.Get('sortOrder')
    local positions = {}
    for index, id in ipairs(watches) do positions[id] = index end
    table.sort(ordered, function(a, b)
        if grouping then
            if a.current ~= b.current then return a.current end
            if a.group ~= b.group then return a.group < b.group end
        end
        if direction ~= 'native' then
            if (a.level ~= nil) ~= (b.level ~= nil) then return a.level ~= nil end
            if a.level and a.level ~= b.level then
                if direction == 'descending' then return a.level > b.level end
                return a.level < b.level
            end
            return a.logIndex < b.logIndex
        end
        return positions[a.id] < positions[b.id]
    end)

    local ids = {}
    for index, info in ipairs(ordered) do ids[index] = info.id end
    return ids
end

function Order:Recover()
    local recovery = AwesomeForeverToolkitCharacterDB.questWatchRecovery
    if not recovery then return true end
    if InCombatLockdown() then return false end

    local watches = readWatches()
    if not watches then return false end
    if not contains(watches, recovery.id) then
        -- Keep the recovery record if the client rejects the re-add, even across reloads.
        local ok = pcall(C_QuestLog.AddQuestWatch, recovery.id)
        if not ok or not contains(readWatches(), recovery.id) then return false end
    end
    AwesomeForeverToolkitCharacterDB.questWatchRecovery = nil
    return true
end

function Order:Move(id)
    if InCombatLockdown() then return false end
    local before = readWatches()
    if not before or not contains(before, id) then return false end

    AwesomeForeverToolkitCharacterDB.questWatchRecovery = {id = id}
    pcall(C_QuestLog.RemoveQuestWatch, id)
    local removed = readWatches()
    if not removed then return false end
    if contains(removed, id) then
        AwesomeForeverToolkitCharacterDB.questWatchRecovery = nil
        return false
    end
    if not self:Recover() then return false end

    local after = readWatches()
    if not after or #after ~= #before then return false end
    for _, value in ipairs(before) do
        if not contains(after, value) then return false end
    end
    return true
end

function Order:Reset()
    self.failure, self.signature = nil, nil
end

function Order:Refresh()
    if InCombatLockdown() then return end
    if not self:Recover() then
        self.failure = 'A removed quest watch could not be restored; recovery will retry after a quest update or reload.'
        return
    end
    if self.failure then return end

    if self.nativeReset then
        self.nativeReset, self.applied, self.signature = nil, nil, nil
        local api = C_QuestLog and C_QuestLog.SortQuestWatches
        if type(api) == 'function' then pcall(api) end
    end

    if not addon.Config.Get('enabled') or
        (addon.Config.Get('sortOrder') == 'native' and not addon.Config.Get('groupZones')) then
        if self.applied then
            self.applied, self.signature = nil, nil
            local api = C_QuestLog and C_QuestLog.SortQuestWatches
            if type(api) == 'function' then pcall(api) end
        end
        return
    end

    local watches = readWatches()
    local metadata = self:Metadata()
    if not watches or not metadata or #watches < 2 then return end
    local desired = self:Desired(watches, metadata)
    if not desired then return end
    local signature = table.concat(desired, ',')
    if table.concat(watches, ',') == signature then
        self.signature = signature
        return
    end
    if self.signature == signature then
        self.failure = 'The client or another addon changed the requested order. Sorting paused; change a sorting option to retry.'
        return
    end
    self.signature = signature

    local api = C_QuestLog
    if type(api.RemoveQuestWatch) ~= 'function' or type(api.AddQuestWatch) ~= 'function' then
        self.failure = 'Native quest-watch ordering APIs are unavailable.'
        return
    end

    -- Discover the insertion end using an existing watch, preserving membership.
    if self.prepend == nil then
        local probe = watches[1]
        if not self:Move(probe) then
            self.failure = 'The client rejected a quest-watch reorder.'
            return
        end
        local after = readWatches()
        if after[1] == probe then self.prepend = true
        elseif after[#after] == probe then self.prepend = false
        else
            self.failure = 'The client does not retain insertion order for quest watches.'
            return
        end
    end

    self.applied = true
    local first, last, step = 1, #desired, 1
    if self.prepend then first, last, step = #desired, 1, -1 end
    for index = first, last, step do
        local current = readWatches()
        if current and table.concat(current, ',') == signature then break end
        local edge = current and current[self.prepend and 1 or #current]
        if edge ~= desired[index] and not self:Move(desired[index]) then
            self.failure = 'The client rejected a quest-watch reorder. Further sorting paused.'
            return
        end
    end

    local after = readWatches()
    if not after or table.concat(after, ',') ~= signature then
        self.failure = 'The client did not retain the requested order. Further sorting paused.'
    end
end
