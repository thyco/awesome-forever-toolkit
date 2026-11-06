local H = dofile('tests/helpers.lua')
local w = H.new()
local create = w.env.CreateFrame
w.env.CreateFrame = function(...)
    local frame = create(...)
    frame.anchors = {}
    frame.SetPoint = function(self, point, relative, relativePoint, x, y)
        assert(not (self.native and w.combat), 'native geometry changed during combat')
        self.anchors[point] = {point, relative, relativePoint, x, y}
    end
    frame.GetPoint = function(self, index)
        local keys = {}
        for key in pairs(self.anchors) do keys[#keys + 1] = key end
        table.sort(keys)
        return table.unpack(self.anchors[keys[index]] or {})
    end
    frame.GetNumPoints = function(self)
        local count = 0
        for _ in pairs(self.anchors) do count = count + 1 end
        return count
    end
    frame.ClearAllPoints = function(self) self.anchors = {} end
    frame.SetParent = function(self, parent)
        assert(not (self.native and w.combat), 'native reparent during combat')
        self.parent = parent
    end
    frame.GetParent = function(self) return self.parent end
    frame.SetScrollChild = function(self, child)
        assert(child, 'native SetScrollChild requires a frame')
        self.scrollChild = child
    end
    frame.SetFont = function(self, font) self.font = font end
    frame.SetWordWrap = function() end
    frame.GetStringHeight = function() return 14 end
    frame.EnableMouseWheel = function() end
    frame.SetOrientation = function() end
    frame.SetThumbTexture = function() end
    return frame
end
w.env.AwesomeForeverToolkitCharacterDB.quests = {enabled = true}
w.root = w:loadManifest()
w:fire('PLAYER_LOGIN')
local quests = w.root.modules.Quests
local tracker = w.env.CreateFrame('Frame')
tracker:SetHeight(240)
tracker.Header = w.env.CreateFrame('Frame')
tracker.ContentsFrame = w.env.CreateFrame('Frame', nil, tracker)
local contents = tracker.ContentsFrame
contents.native = true
contents:SetPoint('TOP', tracker.Header, 'BOTTOM', 0, 0)
contents:SetPoint('LEFT', tracker, 'LEFT', 0, 0)
contents:SetPoint('RIGHT', tracker, 'RIGHT', 0, 0)
contents:SetPoint('BOTTOM', tracker, 'BOTTOM', 0, 0)
contents:SetSize(260, 200)
contents.GetTop = function() return 500 - (quests.QuestViewport and quests.QuestViewport.offset or 0) end
tracker.IsShown = function() return true end
contents.IsShown = function() return true end
local blocks = {}
for index, id in ipairs({11, 12, 13, 14}) do
    local block = w.env.CreateFrame('Frame', nil, contents)
    block.id, block.native = id, true
    block:SetHeight(40)
    block:SetWidth(240)
    block:SetPoint('TOP', blocks[index - 1] or contents, index > 1 and 'BOTTOM' or 'TOP', 0, -10)
    block:SetPoint('LEFT', contents, 'LEFT', 20, 0)
    block:SetPoint('RIGHT', contents, 'RIGHT', 0, 0)
    block.GetTop = function(self)
        local point = self.anchors.TOP
        local top = point[3] == 'BOTTOM' and point[2]:GetBottom() or point[2]:GetTop()
        return top + point[5]
    end
    block.GetBottom = function(self) return self:GetTop() - 40 end
    block.IsShown = function(self) return not self.hidden end
    blocks[index] = block
end
tracker.EnumerateActiveBlocks = function(_, callback)
    for _, block in ipairs(blocks) do callback(block) end
end
tracker.AnchorBlock = function(_, block) block:SetPoint('TOP', contents, 'TOP', 0, -100) end
w.env.QuestObjectiveTracker = tracker
quests:InstallHooks()
quests.Order.Metadata = function()
    return {
        [11] = {zone = 'Westfall', group = 1},
        [12] = {zone = 'Westfall', group = 1},
        [13] = {zone = 'Elwynn Forest', group = 2},
        [14] = {zone = 'Redridge Mountains', group = 3},
    }
end

quests.Groups:Refresh()
local labels = quests.Groups.labels
assert(labels[1].font == 'ObjectiveTrackerLineFont', 'use original-size native heading font')
assert(labels[1].text == 'Westfall' and labels[2].text == 'Elwynn Forest' and labels[3].text == 'Redridge Mountains')
assert(not quests.Groups.dividers[1]:IsShown() and quests.Groups.dividers[2]:IsShown(), 'divider before every later zone')
assert(blocks[1]:GetTop() == 466, 'reserve heading height plus normal gap')
assert(blocks[2]:GetTop() == 416, 'preserve spacing within a zone')
assert(blocks[3]:GetTop() == 337, 'reserve divider plus full heading for next zone')
assert(tracker:GetHeight() == 240 and blocks[1]:GetHeight() == 40, 'do not change native layout heights')
assert(quests.Groups.Viewport.maximum > 0, 'headings overflow within scroll viewport, not into next module')

quests.Groups:Refresh()
assert(blocks[3]:GetTop() == 337, 'repeated refresh must not accumulate spacing')
quests.Groups.Viewport:Scroll(40)
assert(quests.Groups.Viewport.offset == 40)

w.combat = true
quests.Groups:Refresh()
quests.Groups.Viewport:Scroll(80)
assert(quests.Groups.Viewport.offset == 40, 'scroll geometry is frozen in combat')
for _, label in ipairs(labels) do assert(not label:IsShown()) end

w.combat = false
quests.Config.Set('groupZones', false)
quests.Groups:Refresh()
assert(contents:GetParent() == tracker, 'restore original native content parent')
assert(contents.anchors.BOTTOM[2] == tracker and contents:GetNumPoints() == 4, 'restore original anchors')
assert(blocks[1]:GetTop() == 490 and blocks[3]:GetTop() == 390, 'restore native quest positions')
assert(not quests.Groups.Viewport.frame:IsShown())

quests.Config.Set('groupZones', true)
quests.Groups:Refresh()
-- Simulate a native relayout/recycled block before disabling enhancements.
blocks[3].id = 999
tracker:AnchorBlock(blocks[3])
quests.Config.Set('enabled', false)
quests.Groups:Refresh()
assert(blocks[3]:GetTop() == 400, 'never overwrite a newer native anchor')

quests.Config.Set('enabled', true)
quests.Groups:Refresh()
local viewport = quests.Groups.Viewport
local frame = viewport.frame
assert(viewport.slider:IsShown())
contents.IsShown = function() return false end
for _, block in ipairs(blocks) do block.hidden = true end

quests.Groups:Refresh()

assert(not viewport.attached, 'collapse/empty native layout must detach the viewport')
assert(not viewport.frame:IsShown(), 'collapsed native section must not leave an orphan scrollbar')
contents.IsShown = function() return true end
for _, block in ipairs(blocks) do block.hidden = nil end
quests.Groups:Refresh()
assert(viewport.attached)
assert(viewport.frame == frame, 'reuse addon viewport frames across collapse/expand')

viewport:Scroll(40)
viewport.frame:SetHeight(400)
quests.Groups:Refresh()
assert(viewport.maximum == 0 and viewport.offset == 0, 'resize clamps scroll offset')

print('quest zone sections: PASS')
