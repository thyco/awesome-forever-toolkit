local H = dofile('tests/helpers.lua')

local function setup(prepend)
    local w = H.new()
    w.watches = {101, 102, 103, 104}
    w.infos = {
        {isHeader = true, title = 'Westfall'},
        {questID = 101, title = 'Westfall higher', level = 18},
        {questID = 102, title = 'Westfall lower', level = 12},
        {isHeader = true, title = 'Elwynn Forest'},
        {questID = 103, title = 'Elwynn quest', level = 9},
        {isHeader = true, title = 'Redridge Mountains'},
        {questID = 104, title = 'Redridge quest', level = 16},
    }
    w.env.GetRealZoneText = function() return w.zone or 'Elwynn Forest' end
    w.env.C_QuestLog = {
        GetNumQuestLogEntries = function() return #w.infos, 4 end,
        GetInfo = function(i) return w.infos[i] end,
        GetNumQuestWatches = function() return #w.watches end,
        GetQuestIDForQuestWatchIndex = function(i) return w.watches[i] end,
        RemoveQuestWatch = function(id)
            assert(not w.combat, 'watch mutation during combat')
            w.moves = (w.moves or 0) + 1
            for i, value in ipairs(w.watches) do
                if value == id then table.remove(w.watches, i); return true end
            end
            return false
        end,
        AddQuestWatch = function(id)
            assert(not w.combat, 'watch mutation during combat')
            if w.reject then return false end
            table.insert(w.watches, prepend and 1 or #w.watches + 1, id)
            return true
        end,
        SortQuestWatches = function() w.nativeSorts = (w.nativeSorts or 0) + 1 end,
    }
    w.env.AwesomeForeverToolkitCharacterDB.quests = {enabled = true}
    w.root = w:loadManifest()
    w:fire('PLAYER_LOGIN')
    w.quests = w.root.modules.Quests
    return w
end

for _, prepend in ipairs({false, true}) do
    local w = setup(prepend)
    w:tick(1)

    assert(table.concat(w.watches, ',') == '103,102,101,104', 'current zone first; other zones separate; ascending within each')
    local moves = w.moves
    w:fire('QUEST_LOG_UPDATE')
    w:tick(1)
    assert(w.moves == moves, 'already sorted watches must not be removed again')

    w.quests.Config.Set('sortOrder', 'descending')
    w:tick(1)
    assert(table.concat(w.watches, ',') == '103,101,102,104')

    w.zone = 'Westfall'
    w:fire('ZONE_CHANGED_NEW_AREA')
    w:tick(1)
    assert(table.concat(w.watches, ',') == '101,102,103,104', 'new current zone first')

    w.quests.Config.Set('groupZones', false)
    w.quests.Config.Set('sortOrder', 'ascending')
    w.combat = true
    w:tick(1)
    assert(table.concat(w.watches, ',') == '101,102,103,104', 'combat defers ordering')

    w.combat = false
    w:fire('PLAYER_REGEN_ENABLED')
    w:tick(1)
    assert(table.concat(w.watches, ',') == '103,102,104,101', 'ungrouped global level order')
end

do
    local w = setup(false)
    w.reject = true
    w:tick(1)

    assert(w.quests.Order.failure, 'rejecting an API mutation must suspend sorting')
    assert(w.env.AwesomeForeverToolkitCharacterDB.questWatchRecovery, 'removed watch must be retained for recovery')

    w.reject = false
    w:fire('PLAYER_REGEN_ENABLED')
    w:tick(1)

    assert(#w.watches == 4, 'failed re-add must recover without losing a tracked quest')
    assert(not w.env.AwesomeForeverToolkitCharacterDB.questWatchRecovery)
end

do
    local w = setup(false)
    w.infos[2].level = nil
    w:tick(1)

    assert(table.concat(w.watches, ',') == '103,102,101,104', 'unknown levels sort last within their zone')
    w.watches = {104, 103, 102, 101}
    local moves = w.moves
    w:fire('QUEST_LOG_UPDATE')
    w:tick(1)

    assert(w.moves == moves, 'do not fight repeated native resorting for the same requested order')
    assert(w.quests.Order.failure)
end

do
    local w = setup(false)
    local remove = w.env.C_QuestLog.RemoveQuestWatch
    w.env.C_QuestLog.RemoveQuestWatch = function(id)
        remove(id)
        error('synchronous native callback failed after removing the watch')
    end

    w:tick(1)

    assert(#w.watches == 4, 'an error after successful removal must not lose a quest watch')
end

do
    local w = setup(false)
    local add = w.env.C_QuestLog.AddQuestWatch
    w.env.C_QuestLog.AddQuestWatch = function(id)
        local result = add(id)
        w:fire('QUEST_WATCH_LIST_CHANGED', id, true)
        return result
    end
    w.infos[2].level = 12

    w:tick(1)
    local moves = w.moves
    w:tick(1)

    assert(table.concat(w.watches, ',') == '103,101,102,104', 'equal levels retain quest-log order')
    assert(w.moves == moves, 'synchronous watch callbacks do not cause another sorting pass to mutate watches')

    w.quests.Config.Set('enabled', false)
    w:tick(1)

    assert(w.nativeSorts == 1, 'disabling requests native order without replacing native methods')
end

do
    local w = setup(false)
    w.infos[2] = {title = 'Data loading'}

    w:tick(1)

    assert(not w.moves, 'incomplete quest metadata must not mutate the watch list')
end

do
    local w = setup(false)
    w:tick(1)
    w.env.C_QuestLog.SortQuestWatches = function()
        w.nativeSorts = (w.nativeSorts or 0) + 1
        w.watches = {101, 102, 104, 103}
    end

    w.quests.Config.Set('sortOrder', 'native')
    w:tick(1)

    assert(w.nativeSorts == 1, 'native order must be requested even while zone grouping remains enabled')
    assert(table.concat(w.watches, ',') == '103,101,102,104', 'grouped native order uses Blizzard order within zones')
end

print('quest ordering: PASS')
