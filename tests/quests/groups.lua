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
tracker.AnchorBlock = function(_, block) block:SetPoint('TOP', contents, 'TOP', 0, w.nativeOffset or -100) end
tracker.Update = function() end
w.env.QuestObjectiveTracker = tracker
quests:InstallHooks()
quests.Order.Metadata = function()
    return {
        [11] = {id = 11, zone = 'Westfall', group = 1, current = true, level = 12, logIndex = 1},
        [12] = {id = 12, zone = 'Westfall', group = 1, current = true, level = 18, logIndex = 2},
        [13] = {id = 13, zone = 'Elwynn Forest', group = 2, current = false, level = 9, logIndex = 3},
        [14] = {id = 14, zone = 'Redridge Mountains', group = 3, current = false, level = 8, logIndex = 4},
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
w:fire('PLAYER_REGEN_DISABLED')
tracker:Update()
w:tick(0.2)
quests.Groups:Refresh()
quests.Groups.Viewport:Scroll(80)
assert(quests.Groups.Viewport.offset == 40, 'scroll geometry is frozen in combat')
for _, label in ipairs(labels) do assert(label:IsShown(), 'stable combat headers must remain visible') end
assert(not quests.Groups.Viewport.slider:IsEnabled(), 'scrolling still locks in combat')

blocks[3].id = 999
w:fire('QUEST_LOG_UPDATE')
w:tick(0.2)
assert(not labels[2]:IsShown() and not quests.Groups.dividers[2]:IsShown(), 'hide only recycled-row heading and divider')
assert(labels[1]:IsShown() and labels[3]:IsShown(), 'unaffected zone headers remain visible')
blocks[3].id = 13
blocks[4].hidden = true
w:tick(0.2)
assert(not labels[3]:IsShown() and labels[1]:IsShown(), 'a disappeared row invalidates only its own header')
blocks[4].hidden = nil

w.combat = false
w:fire('PLAYER_REGEN_ENABLED')
w:tick(0.2)
for _, label in ipairs(labels) do assert(label:IsShown(), 'rebuild invalidated headers after combat') end

w.combat = false
quests.Config.Set('groupZones', false)
quests.Groups:Refresh()
assert(contents:GetParent() == tracker, 'restore original native content parent')
assert(contents.anchors.BOTTOM[2] == tracker and contents:GetNumPoints() == 4, 'restore original anchors')
assert(contents.anchors.LEFT[4] == 0 and contents:GetWidth() == 260, 'restore original left edge and width')
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

-- Native relayout can leave large offsets; presentation must not preserve those gaps.
quests.Groups:Restore()
blocks[3].id = 13
for index, block in ipairs(blocks) do
    block:SetPoint('TOP', contents, 'TOP', 0, -160 - (index - 1) * 120)
end

quests.Groups:Refresh()

assert(blocks[1]:GetTop() == 466, 'first zone starts beneath header, ignoring old blank offsets')
assert(blocks[3]:GetTop() == 337, 'zone spacing is derived from row heights, not old positions')

-- Edit Mode gives the container more room than the native quest module used.
local container = w.env.CreateFrame('Frame')
container.bottom = 50
container.GetBottom = function(self) return self.bottom end
container.modules = {tracker}
container.bottomModulePadding = 10
container.moduleSpacing = 10
tracker.parentContainer = container
viewport.frame.GetTop = function() return 500 end

quests.Groups:Refresh()

assert(viewport.frame:GetHeight() == 440, 'use available Edit Mode height')
assert(viewport.maximum == 0 and not viewport.slider:IsShown(), 'do not scroll when all quest rows fit')
assert(tracker:GetHeight() == 240, 'do not write native module height')

local other = w.env.CreateFrame('Frame')
other.IsShown = function() return true end
other.GetTop = function() return 220 end
container.modules[2] = other
quests.Groups:Refresh()
assert(viewport.frame:GetHeight() == 270, 'reserve room for the following native tracker section')
assert(viewport.maximum > 0)

container.modules[2] = nil
container.bottom = 300
quests.Groups:Refresh()
assert(viewport.frame:GetHeight() == 190, 'shrinking Edit Mode height updates viewport')
assert(viewport.maximum > 0)

container.bottom = 0
quests.Groups:Refresh()
assert(viewport.frame:GetHeight() == 490 and viewport.maximum == 0, 'growing Edit Mode height removes unnecessary scrolling')

for update = 1, 20 do
    -- Simulate native relayout inheriting an already shifted position from an earlier row.
    for _, block in ipairs(blocks) do
        w.nativeOffset = block:GetTop() - contents:GetTop() - 30
        tracker:AnchorBlock(block)
    end

    w:tick(0.2)

    assert(blocks[1]:GetTop() == 466, 'quest update must not accumulate leading spacing')
    assert(blocks[3]:GetTop() == 337, 'quest update must not accumulate inter-zone spacing')
    assert(viewport.maximum == 0, 'quest update must not invent overflowing content')
end
w.nativeOffset = nil

-- The POI button is anchored outside the quest title's left edge.
local left = viewport.frame.anchors.LEFT[4]
local inset = contents.anchors.TOPLEFT[4]
assert(left <= -24 and inset == -left, 'clip area must include the native tracking button without shifting text')
assert(contents:GetWidth() == 260, 'left gutter must not change quest wrapping width')
assert(20 - 7 - 32 + inset >= 0, '32px POI button must fit inside scroll clipping')

quests.Groups:Restore()
-- Native layout can diverge from watch-list order; grouping must win in the visible rows too.
for index, block in ipairs({blocks[4], blocks[1], blocks[3], blocks[2]}) do
    block:SetPoint('TOP', contents, 'TOP', 0, -10 - (index - 1) * 50)
end
quests.Groups:Refresh()
assert(blocks[1]:GetTop() == 466 and blocks[2]:GetTop() == 416, 'current zone remains together before lower-level quests elsewhere')
assert(blocks[3]:GetTop() == 337 and blocks[4]:GetTop() == 258, 'zone order precedes levels across zones')

quests.Config.Set('sortOrder', 'descending')
quests.Groups:Refresh()
assert(blocks[2]:GetTop() == 466 and blocks[1]:GetTop() == 416, 'descending only reverses quests inside the zone')
assert(blocks[3]:GetTop() == 337 and blocks[4]:GetTop() == 258, 'descending levels do not reorder zones')

w.combat = true
w:fire('PLAYER_REGEN_DISABLED')
local originalTop = blocks[3].GetTop
blocks[3].GetTop = function() return blocks[1]:GetBottom() - 10 end
w:tick(0.2)
assert(not labels[2]:IsShown(), 'hide a header if native relayout removes its reserved space')
assert(labels[1]:IsShown() and labels[3]:IsShown(), 'space loss does not blanket-hide all zones')
blocks[3].GetTop = originalTop
w.combat = false
w:fire('PLAYER_REGEN_ENABLED')
w:tick(0.2)
assert(labels[2]:IsShown())

print('quest zone sections: PASS')
