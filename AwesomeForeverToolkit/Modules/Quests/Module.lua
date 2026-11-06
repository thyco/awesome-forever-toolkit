local _, root = ...
local addon = {legacy = 'QuestTagsForever', nativeUpdates = 0, combatUpdates = 0, levelUps = 0}
root.RegisterModule('Quests', addon)
local Client = root.Client
local hooked = setmetatable({}, {__mode = 'k'})

function addon:RequestRefresh()
    self.pending = true
end

function addon:InstallHooks()
    if InCombatLockdown() or not self.Config.Get('enabled') then return end

    for _, name in ipairs({'QuestObjectiveTracker', 'CampaignQuestObjectiveTracker'}) do
        local tracker = _G[name]
        if tracker and not hooked[tracker] and type(hooksecurefunc) == 'function' then
            hooked[tracker] = {}
        end
        local methods = tracker and hooked[tracker]
        if methods then
            for _, method in ipairs({'Update', 'UpdateSingle'}) do
                if not methods[method] and type(tracker[method]) == 'function' then
                    hooksecurefunc(tracker, method, function()
                        if not self.active or not self.Config.Get('enabled') then return end

                        if method == 'Update' then
                            self.nativeUpdates = self.nativeUpdates + 1
                            if InCombatLockdown() then self.combatUpdates = self.combatUpdates + 1 end
                        end
                        self:RequestRefresh()
                    end)
                    methods[method] = true
                end
            end
        end
    end
end

function addon:RefreshCount()
    local tracker = QuestObjectiveTracker
    if not tracker or not tracker.Header then return end

    if not self.countLabel or self.countHeader ~= tracker.Header then
        if self.countLabel then self.countLabel:Hide() end
        self.countHeader = tracker.Header
        self.countLabel = tracker.Header:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        self.countLabel:SetPoint('RIGHT', tracker.Header.MinimizeButton or tracker.Header,
            tracker.Header.MinimizeButton and 'LEFT' or 'RIGHT', -6, 0)
    end

    local api = C_QuestLog and C_QuestLog.GetNumQuestLogEntries
    local ok, _, count = pcall(api or function() end)
    count = ok and Client.Number(count) or nil
    local maximum = Constants and Constants.QuestLogConsts and Client.Number(Constants.QuestLogConsts.MAXIMUM_NUM_QUESTS_LOG_CAN_ACCEPT)
        or Client.Number(MAX_QUESTS)
    if count then
        self.countLabel:SetText(maximum and string.format('%d / %d', count, maximum) or tostring(count))
    end
    self.countLabel:SetShown(count ~= nil and self.Config.Get('showCount'))
end

function addon:Refresh()
    if InCombatLockdown() then
        self.pending = true
        return
    end

    self.pending = false
    if not self.Config.Get('enabled') then
        self.Titles:RestoreAll()
        if self.countLabel then self.countLabel:Hide() end
        return
    end

    self:InstallHooks()
    if not self.Config.Get('showTags') then
        self.Titles:RestoreAll()
    else
        for _, name in ipairs({'QuestObjectiveTracker', 'CampaignQuestObjectiveTracker'}) do
            local tracker = _G[name]
            if tracker and type(tracker.EnumerateActiveBlocks) == 'function' then
                local ok, reason = pcall(tracker.EnumerateActiveBlocks, tracker, function(block)
                    self.Titles:Apply(block)
                end)
                if not ok then self.lastError = Client.String(reason) and reason or 'Tracker decoration failed' end
            end
        end
    end
    self:RefreshCount()
end

function addon:Start()
    if self.started then return end
    self.started = true
    local defaults = {enabled = false, showTags = true, showCount = true}
    self.Config = root.Config.NewStore('character', 'quests', defaults, function(_, value)
        return type(value) == 'boolean'
    end)
    self.Config.Subscribe(function() self:RequestRefresh() end)

    local frame = CreateFrame('Frame')
    self.frame = frame
    for _, event in ipairs({'ADDON_LOADED', 'PLAYER_ENTERING_WORLD', 'QUEST_LOG_UPDATE',
        'QUEST_WATCH_LIST_CHANGED', 'QUEST_DATA_LOAD_RESULT', 'PLAYER_LEVEL_UP',
        'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'ZONE_CHANGED_NEW_AREA'}) do
        frame:RegisterEvent(event)
    end
    frame:SetScript('OnEvent', function(_, event)
        if not self.active then return end
        if event == 'PLAYER_LEVEL_UP' then self.levelUps = self.levelUps + 1 end
        self:RequestRefresh()
    end)
    frame:SetScript('OnUpdate', function()
        if self.active and self.pending and not InCombatLockdown() then self:Refresh() end
    end)
    self:RequestRefresh()
end

function addon:Diagnostics(command)
    if command == 'config' then
        root.Window:Open()
        root.Window:ShowPage('quests')
        return
    elseif command == 'debug on' or command == 'debug off' then
        self.testing = command == 'debug on'
        print('Awesome Forever Toolkit: quest refresh test commands ' .. (self.testing and 'enabled for this session.' or 'disabled.'))
        return
    elseif command == 'test' then
        if not self.testing or not self.Config.Get('enabled') then
            print('Awesome Forever Toolkit: enable Quest tracker enhancements and use /aft quests debug on first.')
            return
        end

        self:RequestRefresh()
        local api = C_QuestLog and C_QuestLog.SortQuestWatches
        if type(api) ~= 'function' then
            print('Awesome Forever Toolkit: native quest-sort request is unavailable; only addon refresh queued.')
            return
        end

        local before = self.nativeUpdates
        local ok, reason = pcall(api)
        print('Awesome Forever Toolkit: ' .. (ok and 'requested native quest-watch sorting' or 'native request failed')
            .. '; observed updates before request=' .. before .. '. Check /aft quests status after a moment.')
        if not ok and Client.String(reason) then print(reason) end
        print('This is a refresh request, not a simulated level-up. No observed update means the native path was not exercised.')
        return
    end

    print('Awesome Forever Toolkit: native quest tracker | enabled=' .. tostring(self.Config.Get('enabled'))
        .. ' | pending=' .. tostring(self.pending) .. ' | native updates=' .. self.nativeUpdates
        .. ' | combat updates=' .. self.combatUpdates .. ' | real level-up events=' .. self.levelUps)
    if self.lastError then print('Last decoration error: ' .. self.lastError) end
    if type(issecurevariable) == 'function' and QuestObjectiveTracker then
        for _, method in ipairs({'Update', 'GetContentsHeight', 'BuildQuestWatchInfos', 'EnumQuestWatchData', 'OnBlockHeaderClick'}) do
            local ok, secure, source = pcall(issecurevariable, QuestObjectiveTracker, method)
            local state = ok and Client.Boolean(secure)
            print(method .. ': ' .. (state == true and 'secure' or 'insecure/unknown')
                .. (Client.String(source) and (' (' .. source .. ')') or ''))
        end
    end
end
