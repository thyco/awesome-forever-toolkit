local _, root = ...
local addon = root.modules.Quests
local Client = root.Client
local unpack = unpack or table.unpack
local LEFT_GUTTER = 32
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

function Viewport:AnchorFrame(omitBottom)
    self.frame:ClearAllPoints()
    for _, original in ipairs(self.original.points) do
        if not omitBottom or not original[1]:find('BOTTOM', 1, true) then
            local point = {unpack(original)}
            if point[1]:find('LEFT', 1, true) then
                point[4] = (point[4] or 0) - LEFT_GUTTER
            elseif not point[1]:find('RIGHT', 1, true) then
                point[4] = (point[4] or 0) - LEFT_GUTTER / 2
            end
            self.frame:SetPoint(unpack(point))
        end
    end
end

function Viewport:Attach(tracker)
    if InCombatLockdown() then return false end
    local contents = tracker.ContentsFrame
    if self.attached and self.contents == contents then return true end
    self:Restore()
    if not contents or type(contents.GetNumPoints) ~= 'function' then return false end

    self.contents = contents
    self.tracker = tracker
    self.extended = nil
    self.original = {parent = contents:GetParent(), points = points(contents),
        width = contents:GetWidth(), height = contents:GetHeight()}
    local frame = self.frame or CreateFrame('ScrollFrame', nil, tracker)
    self.frame = frame
    frame:SetParent(tracker)
    frame:SetSize(self.original.width + LEFT_GUTTER, self.original.height)
    self:AnchorFrame(false)
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

    local canvas = self.canvas or CreateFrame('Frame', nil, frame)
    self.canvas = canvas
    canvas:SetSize(self.original.width + LEFT_GUTTER, self.original.height)
    canvas:ClearAllPoints()
    canvas:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
    contents:SetParent(canvas)
    contents:ClearAllPoints()
    contents:SetPoint('TOPLEFT', canvas, 'TOPLEFT', LEFT_GUTTER, 0)
    frame:SetScrollChild(canvas)
    self.attached = true
    self.offset = 0
    frame:Show()
    return true
end

-- Frame coordinates are converted to pixels before comparing different native scales.
function Viewport:AvailableHeight()
    local tracker = self.tracker
    local container = tracker and (tracker.parentContainer or Client.Read(tracker.GetParent, tracker))
    if not container or not Client.Table(container.modules) then return nil end
    local top = Client.Number(Client.Read(self.frame.GetTop, self.frame))
    local bottom = Client.Number(Client.Read(container.GetBottom, container))
    if not top or not bottom then return nil end

    local scale = Client.Number(Client.Read(self.frame.GetEffectiveScale, self.frame)) or 1
    local containerScale = Client.Number(Client.Read(container.GetEffectiveScale, container)) or scale
    if scale <= 0 or containerScale <= 0 then return nil end
    top = top * scale
    local padding = Client.Number(container.bottomModulePadding) or 10
    bottom = bottom * containerScale + math.max(0, padding) * containerScale
    local spacing = math.max(0, Client.Number(container.moduleSpacing) or 10) * containerScale

    for _, module in pairs(container.modules) do
        if module ~= tracker and Client.Read(module.IsShown, module) == true then
            local moduleTop = Client.Number(Client.Read(module.GetTop, module))
            local moduleScale = Client.Number(Client.Read(module.GetEffectiveScale, module)) or containerScale
            if not moduleTop or moduleScale <= 0 then return nil end
            moduleTop = moduleTop * moduleScale
            if moduleTop <= top then bottom = math.max(bottom, moduleTop + spacing) end
        end
    end
    return math.max(1, (top - bottom) / scale)
end

function Viewport:FitAvailableArea()
    local available = self:AvailableHeight()
    if available then
        if not self.extended then
            self:AnchorFrame(true)
            self.extended = true
        end
        if self.frame:GetHeight() ~= available then self.frame:SetHeight(available) end
    elseif self.extended then
        -- Unknown native geometry: return to the module's own rectangle instead of overlapping it.
        self:AnchorFrame(false)
        self.extended = nil
    end
end

function Viewport:Resize(height)
    if InCombatLockdown() or not self.attached then return end
    self:FitAvailableArea()
    local visibleHeight = Client.Number(self.frame:GetHeight()) or 0
    local width = self.frame:GetWidth()
    local contentHeight = math.max(visibleHeight, height)
    self.canvas:SetSize(width, contentHeight)
    self.contents:SetWidth(math.max(1, width - LEFT_GUTTER))
    self.contents:SetHeight(contentHeight)
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
