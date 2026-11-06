local _, root = ...
local addon = root.modules.Quests
local Client = root.Client
local unpack = unpack or table.unpack
local Viewport = {rows = setmetatable({}, {__mode = 'k'}), offset = 0, maximum = 0}
addon.QuestViewport = Viewport

local function points(frame)
    local result = {}
    for index = 1, frame:GetNumPoints() do result[index] = {frame:GetPoint(index)} end
    return result
end

local function topPoint(frame)
    for _, point in ipairs(points(frame)) do
        if point[1] == 'TOP' then return point end
    end
end

local function same(a, b)
    if not a or not b then return false end
    for index = 1, 5 do
        if a[index] ~= b[index] then return false end
    end
    return true
end

function Viewport:NativeAnchor(block)
    if block then self.rows[block] = nil end
end

function Viewport:RestoreRows()
    if InCombatLockdown() then return end
    for block, record in pairs(self.rows) do
        if Client.Number(block.id) == record.id and same(topPoint(block), record.applied) then
            block:SetPoint(unpack(record.original))
        end
        self.rows[block] = nil
    end
end

function Viewport:OffsetRow(block, nativeOffset, extra)
    local original = topPoint(block)
    if not original then return false end

    local applied = {'TOP', self.contents, 'TOP', 0, nativeOffset - extra}
    self.rows[block] = {id = Client.Number(block.id), original = original, applied = applied}
    block:SetPoint(unpack(applied))
    return true
end

function Viewport:Scroll(offset)
    if InCombatLockdown() or not self.attached then return end
    self.offset = math.max(0, math.min(self.maximum, offset))
    self.frame:SetVerticalScroll(self.offset)
    self.updating = true
    self.slider:SetValue(self.offset)
    self.updating = false
end

function Viewport:Attach(tracker)
    if InCombatLockdown() then return false end
    local contents = tracker.ContentsFrame
    if self.attached and self.contents == contents then return true end
    self:Restore()
    if not contents or type(contents.GetNumPoints) ~= 'function' then return false end

    self.contents = contents
    self.original = {parent = contents:GetParent(), points = points(contents),
        width = contents:GetWidth(), height = contents:GetHeight()}
    local frame = self.frame or CreateFrame('ScrollFrame', nil, tracker)
    self.frame = frame
    frame:SetParent(tracker)
    frame:ClearAllPoints()
    frame:SetSize(self.original.width, self.original.height)
    for _, point in ipairs(self.original.points) do frame:SetPoint(unpack(point)) end
    frame:EnableMouseWheel(true)
    frame:SetScript('OnMouseWheel', function(_, delta) self:Scroll(self.offset - delta * 30) end)
    frame:SetScript('OnSizeChanged', function() addon:RequestRefresh() end)

    local slider = self.slider or CreateFrame('Slider', nil, frame)
    self.slider = slider
    slider:ClearAllPoints()
    slider:SetWidth(8)
    slider:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 4, -2)
    slider:SetPoint('BOTTOMLEFT', frame, 'BOTTOMRIGHT', 4, 2)
    slider:SetOrientation('VERTICAL')
    slider:SetThumbTexture('Interface\\Buttons\\UI-ScrollBar-Knob')
    if slider.GetThumbTexture then slider:GetThumbTexture():SetSize(8, 20) end
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetMinMaxValues(0, 0)
    slider:SetScript('OnValueChanged', function(_, value)
        if not self.updating then self:Scroll(value) end
    end)

    contents:SetParent(frame)
    contents:ClearAllPoints()
    contents:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
    frame:SetScrollChild(contents)
    self.attached = true
    self.offset = 0
    frame:Show()
    return true
end

function Viewport:Resize(height)
    if InCombatLockdown() or not self.attached then return end
    local visibleHeight = Client.Number(self.frame:GetHeight()) or 0
    self.contents:SetWidth(self.frame:GetWidth())
    self.contents:SetHeight(math.max(visibleHeight, height))
    self.maximum = math.max(0, height - visibleHeight)
    self.slider:SetMinMaxValues(0, self.maximum)
    self.slider:SetShown(self.maximum > 0)
    self.slider:SetEnabled(true)
    self:Scroll(self.offset)
end

function Viewport:Restore()
    if InCombatLockdown() then return end
    self:RestoreRows()
    if not self.attached then return end

    if not self.empty then
        self.empty = CreateFrame('Frame', nil, self.frame)
        self.empty:SetSize(1, 1)
    end
    self.frame:SetScrollChild(self.empty)
    self.contents:SetParent(self.original.parent)
    self.contents:ClearAllPoints()
    self.contents:SetSize(self.original.width, self.original.height)
    for _, point in ipairs(self.original.points) do self.contents:SetPoint(unpack(point)) end
    self.frame:Hide()
    self.attached = false
    self.offset, self.maximum = 0, 0
end
