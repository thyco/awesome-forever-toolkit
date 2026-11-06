local H = dofile('tests/helpers.lua')
local function setup(enabled, legacy)
    local w = H.new()
    w.env.AwesomeForeverToolkitCharacterDB.quests = {enabled = enabled == true}
    w.loaded.QuestTagsForever = legacy
    w.questInfo = {questID = 100, title = 'A difficult task', level = 12}
    w.questTag = {tagID = 81}
    w.env.C_QuestLog = {
        GetLogIndexForQuestID = function(id) return id == 100 and 1 or nil end,
        GetInfo = function() return w.questInfo end,
        GetQuestTagInfo = function() return w.questTag end,
        IsEliteQuest = function() return false end,
        GetNumQuestLogEntries = function() return 2, 1 end,
        SortQuestWatches = function() w.sortCalls = (w.sortCalls or 0) + 1 end,
    }
    w.env.MAX_QUESTS = 25
    w.block = w:newFrame()
    w.block.id = 100
    w.block.HeaderText = w:newFrame()
    w.block.HeaderText.GetText = function(self) return self.text end
    w.block.HeaderText:SetText('A difficult task')
    w.native = w:newFrame()
    w.native.Header = w:newFrame()
    w.native.Header.Text = w:newFrame()
    w.native.GetExistingBlock = function() return w.block end
    w.native.EnumerateActiveBlocks = function(_, callback) callback(w.block) end
    w.native.Update = function() w.nativeCalls = (w.nativeCalls or 0) + 1 end
    w.native.UpdateSingle = function() w.block.HeaderText:SetText('A difficult task') end
    w.native.BuildQuestWatchInfos = function() return 'native' end
    w.native.EnumQuestWatchData = function() return 'native' end
    w.native.GetContentsHeight = function() return 50 end
    w.native.OnBlockHeaderClick = function() return 'native' end
    w.originalBuild = w.native.BuildQuestWatchInfos
    w.originalEnum = w.native.EnumQuestWatchData
    w.originalHeight = w.native.GetContentsHeight
    w.originalClick = w.native.OnBlockHeaderClick
    w.env.QuestObjectiveTracker = w.native
    w.env.ObjectiveTrackerFrame = {Update = function() error('must not call container Update') end,
        MarkDirty = function() error('must not dirty shared tracker from addon execution') end}
    w.root = w:loadManifest()
    w:fire('PLAYER_LOGIN')
    assert(w.root.modules.Quests, 'native quest enhancement module must exist')
    w.quests = w.root.modules.Quests
    return w
end

do
    local w = setup(false)
    assert(w.block.HeaderText.text == 'A difficult task')
    w.quests.Config.Set('enabled', true)
    w:tick(0.2)
    assert(w.block.HeaderText.text == '[12D] A difficult task')
    assert(w.quests.countLabel.text == '1 / 25')
    assert(w.native.BuildQuestWatchInfos == w.originalBuild)
    assert(w.native.EnumQuestWatchData == w.originalEnum)
    assert(w.native.GetContentsHeight == w.originalHeight)
    assert(w.native.OnBlockHeaderClick == w.originalClick)
    assert(not w.nativeCalls, 'enabling must not call native layout')

    w.quests:RequestRefresh()
    w:tick(0.2)
    assert(w.block.HeaderText.text == '[12D] A difficult task', 'prefix must not stack')
    w.quests.Config.Set('enabled', false)
    w:tick(0.2)
    assert(w.block.HeaderText.text == 'A difficult task')
    assert(not w.quests.countLabel:IsShown())
end

do
    local w = setup(true)
    w:tick(0.2)
    w.block.HeaderText:SetText('|cffffff00[12+] A difficult task|r')
    w.quests:RequestRefresh()
    w:tick(0.2)
    assert(w.block.HeaderText.text == '|cffffff00[12D] A difficult task|r')

    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    w.native:UpdateSingle({GetID = function() return 100 end})
    w.questInfo.level = 13
    w:fire('PLAYER_LEVEL_UP', 13)
    w:tick(0.2)
    assert(w.block.HeaderText.text == 'A difficult task', 'native text writes are deferred in combat')
    assert(w.quests.pending)

    w.combat = false
    w:fire('PLAYER_REGEN_ENABLED')
    w:tick(0.2)
    assert(w.block.HeaderText.text == '[13D] A difficult task')
end

do
    local w = setup(true)
    w:tick(0.2)
    w.block.id = 101
    w.block.HeaderText:SetText('Another quest')
    w.quests.Config.Set('enabled', false)
    w:tick(0.2)
    assert(w.block.HeaderText.text == 'Another quest', 'do not restore a recycled header')
end

do
    local w = setup(true, true)
    w:tick(0.2)
    assert(not w.quests.active)
    assert(w.block.HeaderText.text == 'A difficult task')
end

do
    local w = setup(true)
    w:tick(0.2)
    w.quests:Diagnostics('test')
    assert(not w.sortCalls, 'test command requires explicit arming')
    w.quests:Diagnostics('debug on')
    w.combat = true
    w.quests:Diagnostics('test')
    assert(w.sortCalls == 1)
    assert(not w.nativeCalls, 'test must not directly invoke native layout')
    w.native:Update()
    assert(w.quests.nativeUpdates == 1)
    w.quests:Diagnostics('debug off')
    w.quests:Diagnostics('test')
    assert(w.sortCalls == 1)
end

do
    local w = setup(true)
    w.env.QuestObjectiveTracker = nil
    w:tick(0.2)
    assert(w.block.HeaderText.text == 'A difficult task')

    w.env.QuestObjectiveTracker = w.native
    w:fire('ADDON_LOADED', 'Blizzard_ObjectiveTracker')
    w:tick(0.2)
    assert(w.block.HeaderText.text == '[12D] A difficult task')
    w.native:Update()
    assert(w.quests.nativeUpdates == 1)

    w.quests.Config.Set('showTags', false)
    w:tick(0.2)
    assert(w.block.HeaderText.text == 'A difficult task')
    assert(w.quests.countLabel:IsShown())
    w.quests.Config.Set('showCount', false)
    w:tick(0.2)
    assert(not w.quests.countLabel:IsShown())
end

do
    local w = setup(true)
    w.questTag = {tagID = 62}
    w:tick(0.2)
    assert(w.block.HeaderText.text == '[12R] A difficult task')
    w.questTag = {isElite = true}
    w:fire('QUEST_LOG_UPDATE')
    w:tick(0.2)
    assert(w.block.HeaderText.text == '[12E] A difficult task')

    w.combat = true
    w.quests.Config.Set('enabled', false)
    w:tick(0.2)
    assert(w.block.HeaderText.text == '[12E] A difficult task')
    w.combat = false
    w:fire('PLAYER_REGEN_ENABLED')
    w:tick(0.2)
    assert(w.block.HeaderText.text == 'A difficult task')
end


-- Decorations must fit the height already reserved by Blizzard's layout.
do
    local w = setup(true)
    w.block.HeaderText.GetHeight = function(self)
        return self.text:find('[12D]', 1, true) and 28 or 14
    end

    w:tick(0.2)

    assert(w.block.HeaderText.text == 'A difficult task', 'a wrapping prefix must not change native layout height')

    w.block.HeaderText.GetHeight = function() return 14 end
    w.quests:RequestRefresh()
    w:tick(0.2)

    assert(w.block.HeaderText.text == '[12D] A difficult task', 'a fitting prefix should still be applied')
end

print('native quest tracker: PASS')
