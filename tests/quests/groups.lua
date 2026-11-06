local H = dofile('tests/helpers.lua')
local w = H.new()
w.env.AwesomeForeverToolkitCharacterDB.quests = {enabled = true}
w.root = w:loadManifest()
w:fire('PLAYER_LOGIN')
local quests = w.root.modules.Quests
local tracker = w:newFrame()
tracker.ContentsFrame = w:newFrame()
tracker.ContentsFrame.CreateFontString = function()
    local label = w:newFrame()
    label.SetFont = function(self, _, size) self.fontSize = size end
    label.SetWordWrap = function() end
    label.GetStringHeight = function(self) return self.fontSize end
    return label
end
tracker.ContentsFrame.GetTop = function() return 500 end
tracker.IsShown = function() return true end
local blocks = {}
for index, id in ipairs({11, 12, 13, 14}) do
    local block = w:newFrame()
    block.id = id
    block.top = 490 - (index - 1) * 50
    block.GetTop = function(self) return self.top end
    block.GetBottom = function(self) return self.top - 40 end
    block.IsShown = function(self) return not self.hidden end
    blocks[index] = block
end
tracker.EnumerateActiveBlocks = function(_, callback)
    for _, block in ipairs(blocks) do callback(block) end
end
w.env.QuestObjectiveTracker = tracker
local data = {
    [11] = {zone = 'Westfall', group = 1},
    [12] = {zone = 'Westfall', group = 1},
    [13] = {zone = 'Elwynn Forest', group = 2},
    [14] = {zone = 'Redridge Mountains', group = 3},
}
quests.Order.Metadata = function() return data end

assert(quests.Groups, 'zone heading renderer must exist')
quests.Groups:Refresh()
local labels = quests.Groups.labels
assert(#labels == 3)
assert(labels[1].text == 'Westfall' and labels[2].text == 'Elwynn Forest' and labels[3].text == 'Redridge Mountains')
assert(labels[1]:IsShown() and labels[3]:IsShown())

blocks[3].top = blocks[2]:GetBottom() - 3
quests.Groups:Refresh()
assert(quests.Groups.skipped == 1, 'do not overlap native rows when a heading cannot fit')

w.combat = true
quests.Groups:Refresh()
for _, label in ipairs(labels) do assert(not label:IsShown(), 'own headings must hide during combat') end

w.combat = false
quests.Config.Set('groupZones', false)
quests.Groups:Refresh()
for _, label in ipairs(labels) do assert(not label:IsShown()) end

quests.Config.Set('groupZones', true)
tracker.IsShown = function() return false end
quests.Groups:Refresh()
for _, label in ipairs(labels) do assert(not label:IsShown(), 'collapsed/hidden tracker has no headings') end

print('quest zone headings: PASS')
