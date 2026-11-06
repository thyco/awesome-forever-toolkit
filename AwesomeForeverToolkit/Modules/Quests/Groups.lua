local _, root = ...
local addon = root.modules.Quests
local Client = root.Client
local Groups = {labels = {}, dividers = {}, associations = {}, skipped = 0, Viewport = addon.QuestViewport}
addon.Groups = Groups

function Groups:Hide()
    for _, label in ipairs(self.labels) do label:Hide() end
    for _, divider in ipairs(self.dividers) do divider:Hide() end
    if self.Viewport.slider then
        self.Viewport.slider:SetEnabled(not InCombatLockdown())
        local contents = self.Viewport.contents
        if contents and Client.Read(contents.IsShown, contents) ~= true then self.Viewport.slider:Hide() end
    end
end

-- Combat validation changes only our own artwork, never native rows or anchors.
function Groups:Validate()
    if self.Viewport.slider then self.Viewport.slider:SetEnabled(not InCombatLockdown()) end
    local tracker = QuestObjectiveTracker
    local contents = tracker and tracker.ContentsFrame
    if not addon.Config.Get('enabled') or not addon.Config.Get('groupZones')
        or contents ~= self.parent or Client.Read(tracker and tracker.IsShown, tracker) ~= true
        or Client.Read(contents and contents.IsShown, contents) ~= true then
        self:Hide()
        return
    end

    local contentTop = Client.Number(Client.Read(contents.GetTop, contents))
    local rows, readable = {}, contentTop ~= nil
    local ok = pcall(tracker.EnumerateActiveBlocks, tracker, function(block)
        if Client.Read(block.IsShown, block) == true then
            local top = Client.Number(Client.Read(block.GetTop, block))
            local bottom = Client.Number(Client.Read(block.GetBottom, block))
            if not top or not bottom then readable = false; return end
            rows[block] = {top = top, bottom = bottom}
        end
    end)

    for index, record in pairs(self.associations) do
        local block = record.block
        local row = rows[block]
        local valid = record.valid and ok and readable and row ~= nil
            and Client.Number(block.id) == record.id
            and Client.Read(block.GetParent, block) == record.parent
        if valid then
            local boundary = contentTop
            for other, position in pairs(rows) do
                if other ~= block and position.top >= row.top then
                    boundary = math.min(boundary, position.bottom)
                end
            end
            valid = row.top + record.space <= boundary
        end

        if not valid then
            record.valid = false
            self.labels[index]:Hide()
            self.dividers[index]:Hide()
        end
    end
end

function Groups:OnChange()
    if InCombatLockdown() then self:Validate() else self:Hide() end
end

function Groups:Restore()
    self:Hide()
    self.Viewport:Restore()
end

function Groups:Refresh()
    if InCombatLockdown() then self:Validate(); return end
    self:Hide()
    self.associations = {}
    self.skipped = 0
    if not addon.Config.Get('enabled') or not addon.Config.Get('groupZones') then
        self.Viewport:Restore()
        return
    end

    local tracker = QuestObjectiveTracker
    if not tracker or not tracker.ContentsFrame or Client.Read(tracker.IsShown, tracker) ~= true
        or Client.Read(tracker.ContentsFrame.IsShown, tracker.ContentsFrame) ~= true then
        self.Viewport:Restore()
        return
    end
    local metadata = addon.Order:Metadata()
    if not metadata or type(tracker.EnumerateActiveBlocks) ~= 'function' then
        self.Viewport:Restore()
        return
    end

    self.Viewport:RestoreRows()
    local contents = tracker.ContentsFrame
    local contentTop = Client.Number(Client.Read(contents.GetTop, contents))
    if not contentTop then return end
    local rows = {}
    tracker:EnumerateActiveBlocks(function(block)
        local top = Client.Number(Client.Read(block.GetTop, block))
        local bottom = Client.Number(Client.Read(block.GetBottom, block))
        if top and bottom and Client.Read(block.IsShown, block) == true then
            local id = Client.Number(block.id)
            rows[#rows + 1] = {block = block, top = top, bottom = bottom, info = id and metadata[id]}
        end
    end)
    table.sort(rows, function(a, b) return a.top > b.top end)

    -- Native display order can differ from the watch list after a tracker update.
    -- Apply the same zone-first ordering to the visible quest rows as well.
    local ids, byID = {}, {}
    for _, row in ipairs(rows) do
        if row.info then
            local id = Client.Number(row.block.id)
            ids[#ids + 1], byID[id] = id, row
        end
    end
    local desired = addon.Order:Desired(ids, metadata)
    if desired then
        local index = 1
        for position, row in ipairs(rows) do
            if row.info then
                rows[position] = byID[desired[index]]
                index = index + 1
            end
        end
    end

    if #rows == 0 then
        self.Viewport:Restore()
        return
    end
    if not self.Viewport:Attach(tracker) then return end

    if self.parent ~= contents then
        self.labels, self.dividers = {}, {}
        self.parent = contents
    end
    local previousGroup
    local used, cursor, height = 0, 10, 0
    for _, row in ipairs(rows) do
        local info = row.info
        if info and info.group ~= previousGroup then
            used = used + 1
            local label, divider = self.labels[used], self.dividers[used]
            if not label then
                label = contents:CreateFontString(nil, 'ARTWORK', 'ObjectiveTrackerLineFont')
                label:SetFontObject('ObjectiveTrackerLineFont')
                label:SetJustifyH('LEFT')
                label:SetWordWrap(true)
                label:SetTextColor(1, 0.82, 0)
                divider = contents:CreateTexture(nil, 'ARTWORK')
                divider:SetHeight(1)
                divider:SetColorTexture(1, 0.82, 0, 0.35)
                self.labels[used], self.dividers[used] = label, divider
            end
            label:SetWidth(Client.Number(Client.Read(row.block.GetWidth, row.block)) or 200)
            label:SetText(info.zone)
            local labelHeight = Client.Number(Client.Read(label.GetStringHeight, label)) or 14
            local space = labelHeight + 10 + (used > 1 and 5 or 0)
            cursor = cursor + space
            self.associations[used] = {block = row.block, id = Client.Number(row.block.id),
                parent = Client.Read(row.block.GetParent, row.block), space = space, valid = true}

            label:ClearAllPoints()
            label:SetPoint('BOTTOMLEFT', row.block, 'TOPLEFT', 0, 10)
            divider:ClearAllPoints()
            divider:SetPoint('BOTTOMLEFT', label, 'TOPLEFT', 0, 4)
            divider:SetPoint('BOTTOMRIGHT', label, 'TOPRIGHT', 0, 4)
            divider:SetShown(used > 1)
            label:Show()
        end

        if not self.Viewport:OffsetRow(row.block, -cursor, 0) then
            self:Restore()
            self.skipped = 1
            return
        end
        -- Native updates may inherit our previous visual offsets through chained anchors.
        -- Only use the row's size; never carry its old vertical position into the new layout.
        height = cursor + math.max(0, row.top - row.bottom)
        cursor = height + 10
        previousGroup = info and info.group
    end
    self.Viewport:Resize(height)
end
