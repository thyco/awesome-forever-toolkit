local _, root = ...
local addon = root.modules.Quests
local Client = root.Client
local Groups = {labels = {}, skipped = 0}
addon.Groups = Groups

function Groups:Hide()
    for _, label in ipairs(self.labels) do label:Hide() end
end

function Groups:Refresh()
    self:Hide()
    self.skipped = 0
    if InCombatLockdown() or not addon.Config.Get('enabled') or not addon.Config.Get('groupZones') then return end

    local tracker = QuestObjectiveTracker
    if not tracker or not tracker.ContentsFrame or Client.Read(tracker.IsShown, tracker) ~= true then return end
    local metadata = addon.Order:Metadata()
    if not metadata or type(tracker.EnumerateActiveBlocks) ~= 'function' then return end

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

    if self.parent ~= tracker.ContentsFrame then
        self.labels = {}
        self.parent = tracker.ContentsFrame
    end
    local previousBottom = Client.Number(Client.Read(self.parent.GetTop, self.parent))
    local previousGroup
    local used = 0
    for _, row in ipairs(rows) do
        local info = row.info
        if info and info.group ~= previousGroup then
            used = used + 1
            local label = self.labels[used]
            if not label then
                label = self.parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
                label:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 9, '')
                label:SetJustifyH('LEFT')
                label:SetWordWrap(false)
                self.labels[used] = label
            end
            label:SetWidth(Client.Number(Client.Read(row.block.GetWidth, row.block)) or 200)
            label:SetText(info.zone)

            local height = Client.Number(Client.Read(label.GetStringHeight, label))
            local gap = previousBottom and previousBottom - row.top
            if height and gap and gap >= height + 1 then
                label:ClearAllPoints()
                label:SetPoint('BOTTOMLEFT', row.block, 'TOPLEFT', 0, 1)
                label:Show()
            else
                label:Hide()
                self.skipped = self.skipped + 1
            end
        end
        previousGroup = info and info.group
        previousBottom = row.bottom
    end
end
