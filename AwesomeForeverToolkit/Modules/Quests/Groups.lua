local _, root = ...
local addon = root.modules.Quests
local Client = root.Client
local Groups = {labels = {}, dividers = {}, skipped = 0, Viewport = addon.QuestViewport}
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

function Groups:Restore()
    self:Hide()
    self.Viewport:Restore()
end

function Groups:Refresh()
    self:Hide()
    self.skipped = 0
    if InCombatLockdown() then return end
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
    local used, extra, height = 0, 0, 0
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
            extra = extra + labelHeight + 10 + (used > 1 and 5 or 0)

            label:ClearAllPoints()
            label:SetPoint('BOTTOMLEFT', row.block, 'TOPLEFT', 0, 10)
            divider:ClearAllPoints()
            divider:SetPoint('BOTTOMLEFT', label, 'TOPLEFT', 0, 4)
            divider:SetPoint('BOTTOMRIGHT', label, 'TOPRIGHT', 0, 4)
            divider:SetShown(used > 1)
            label:Show()
        end

        if not self.Viewport:OffsetRow(row.block, row.top - contentTop, extra) then
            self:Restore()
            self.skipped = 1
            return
        end
        height = math.max(height, contentTop - row.bottom + extra)
        previousGroup = info and info.group
    end
    self.Viewport:Resize(height)
end
