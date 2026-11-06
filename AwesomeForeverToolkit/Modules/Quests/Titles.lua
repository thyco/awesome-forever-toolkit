local _, root = ...
local addon = root.modules.Quests
local Client = root.Client
local Titles = {}
addon.Titles = Titles
local records = setmetatable({}, {__mode = 'k'})

local function prefix(id)
    local index = Client.Number(Client.Read(C_QuestLog and C_QuestLog.GetLogIndexForQuestID, id))
    if not index or index <= 0 then return nil end
    local info = Client.Read(C_QuestLog and C_QuestLog.GetInfo, index)
    if not Client.Table(info) then return nil end
    local level = Client.Number(info.difficultyLevel) or Client.Number(info.level)
    if not level or level <= 0 or level % 1 ~= 0 then return nil end

    local tag = Client.Read(C_QuestLog and C_QuestLog.GetQuestTagInfo, id)
    local tagID = Client.Table(tag) and Client.Number(tag.tagID)
    local suffix = ''
    if tagID == 62 then
        suffix = 'R'
    elseif tagID == 81 then
        suffix = 'D'
    elseif Client.Boolean(Client.Read(C_QuestLog and C_QuestLog.IsEliteQuest, id)) == true
        or (Client.Table(tag) and Client.Boolean(tag.isElite) == true) then
        suffix = 'E'
    end

    return string.format('[%d%s] ', level, suffix)
end

local function format(text, tag)
    local color = text:match('^(|c%x%x%x%x%x%x%x%x)') or ''
    local body = text:sub(#color + 1)
    body = body:gsub('^%[%d+[EDR+]?%]%s*', '', 1)
    return color .. tag .. body
end

function Titles:Apply(block)
    if InCombatLockdown() or not block then return end
    local id = Client.Number(block.id)
    local font = block.HeaderText
    if not id or not font or type(font.SetText) ~= 'function' then return end
    local current = Client.Read(font.GetText, font)
    if not Client.String(current) then return end

    local record = records[font]
    local original = record and record.id == id and current == record.decorated and record.original or current
    local tag = prefix(id)
    if not tag then return end
    local decorated = format(original, tag)
    if current ~= decorated then
        local height = Client.Number(Client.Read(font.GetHeight, font))
        font:SetText(decorated)

        -- Native layout has already reserved space for this header.
        local decoratedHeight = Client.Number(Client.Read(font.GetHeight, font))
        if height and decoratedHeight and decoratedHeight ~= height then
            font:SetText(current)
            return
        end
    end

    records[font] = {id = id, original = original, decorated = decorated}
end

function Titles:RestoreAll()
    if InCombatLockdown() then return end
    for font, record in pairs(records) do
        if Client.Read(font.GetText, font) == record.decorated then
            font:SetText(record.original)
        end
        records[font] = nil
    end
end
