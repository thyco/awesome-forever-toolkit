local _, addon = ...
local Client = {}
addon.Client = Client

function Client.Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function Client.Number(value)
    if not Client.Readable(value) or type(value) ~= "number" then
        return nil
    end

    if value ~= value or value == math.huge or value == -math.huge then
        return nil
    end

    return value
end

function Client.Boolean(value)
    if not Client.Readable(value) then
        return nil
    end

    if value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end
end

function Client.HasShield()
    if not Client.Readable(GetInventoryItemID)
        or type(GetInventoryItemID) ~= "function" then
        return false
    end

    local itemOK, itemID = pcall(GetInventoryItemID, "player", 17)
    if not itemOK or not Client.Number(itemID) or itemID <= 0 then
        return false
    end

    if not Client.Readable(C_Item) or type(C_Item) ~= "table" then
        return false
    end

    local apiOK, itemInfo = pcall(function() return C_Item.GetItemInfoInstant end)
    if not apiOK or not Client.Readable(itemInfo) or type(itemInfo) ~= "function" then
        return false
    end

    local infoOK, _, _, _, equipLocation = pcall(itemInfo, itemID)
    return infoOK and Client.Readable(equipLocation)
        and equipLocation == "INVTYPE_SHIELD"
end

function Client.PlayerSpells()
    local spells = {}
    if not Client.Readable(C_SpellBook) or not Client.Readable(Enum)
        or type(C_SpellBook) ~= "table" or type(Enum) ~= "table" then
        return spells
    end

    local bookBank = Enum.SpellBookSpellBank
    local itemTypes = Enum.SpellBookItemType
    local countSpells = C_SpellBook.GetNumSpellBookSkillLines
    local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo
    local itemInfo = C_SpellBook.GetSpellBookItemInfo

    if not Client.Readable(bookBank) or not Client.Readable(itemTypes)
        or type(bookBank) ~= "table" or type(itemTypes) ~= "table"
        or not Client.Readable(countSpells) or not Client.Readable(lineInfo) or not Client.Readable(itemInfo)
        or type(countSpells) ~= "function" or type(lineInfo) ~= "function" or type(itemInfo) ~= "function" then
        return spells
    end

    local bank = bookBank.Player
    local spellType = itemTypes.Spell
    if not Client.Number(bank) or not Client.Number(spellType)
        or bank < 0 or bank ~= math.floor(bank)
        or spellType < 0 or spellType ~= math.floor(spellType) then
        return spells
    end

    local ok, count = pcall(countSpells)
    if not ok or not Client.Number(count) or count < 0 or count > 100 or count ~= math.floor(count) then
        return spells
    end

    for lineIndex = 1, count do
        local lineOK, line = pcall(lineInfo, lineIndex)
        if lineOK and Client.Readable(line) and type(line) == "table" then
            local offset = line.itemIndexOffset
            local length = line.numSpellBookItems

            if Client.Number(offset) and Client.Number(length) and offset >= 0 and length >= 0
                and offset == math.floor(offset) and length == math.floor(length) and length <= 1000 then
                for index = offset + 1, offset + length do
                    local itemOK, item = pcall(itemInfo, index, bank)
                    if itemOK and Client.Readable(item) and type(item) == "table"
                        and Client.Readable(item.itemType) and item.itemType == spellType
                        and Client.Boolean(item.isPassive) == false
                        and Client.Boolean(item.isOffSpec) == false
                        and Client.Number(item.spellID) then
                        spells[#spells + 1] = { id = item.spellID, baseID = item.actionID, slot = index, bank = bank }
                    end
                end
            end
        end
    end

    return spells
end

function Client.SpellName(id)
    if not Client.Readable(id) then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if Client.Readable(info) and info and Client.Readable(info.name) then
            return info.name
        end
    elseif GetSpellInfo then
        local name = GetSpellInfo(id)
        if Client.Readable(name) then
            return name
        end
    end
end

function Client.SpellTexture(id)
    if not Client.Readable(id) then
        return nil
    end

    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(id)
        if Client.Readable(texture) then
            return texture
        end
    elseif GetSpellTexture then
        local texture = GetSpellTexture(id)
        if Client.Readable(texture) then
            return texture
        end
    end
end

function Client.InCombat()
    if not UnitAffectingCombat then
        return false
    end

    local combat = UnitAffectingCombat("player")
    return Client.Readable(combat) and combat == true
end

function Client.IsWarrior()
    if not UnitClass then
        return false
    end

    local _, class = UnitClass("player")
    return Client.Readable(class) and class == "WARRIOR"
end

function Client.Table(value)
    return Client.Readable(value) and type(value) == "table"
end


local function read(api, ...)
    if type(api) ~= "function" then
        return nil
    end

    local ok, value = pcall(api, ...)
    if ok and Client.Readable(value) then
        return value
    end
end

Client.Read = read

function Client.String(value)
    return Client.Readable(value) and type(value) == "string"
end

function Client.CanAttack(unit)
    return Client.Boolean(read(UnitExists, unit)) == true
        and Client.Boolean(read(UnitCanAttack, "player", unit)) == true
        and Client.Boolean(read(UnitIsDeadOrGhost, unit)) == false
end

function Client.RangeUnit()
    local hasTarget = Client.Boolean(read(UnitExists, "target"))
    if hasTarget == true then
        if Client.CanAttack("target") then
            return "target"
        end
    elseif hasTarget == false and Client.CanAttack("mouseover") then
        return "mouseover"
    end
end

function Client.SpellInfo(id)
    if not Client.Number(id) or not C_Spell then
        return nil
    end

    local info = read(C_Spell.GetSpellInfo, id)
    if not Client.Table(info) or not Client.Number(info.minRange) or not Client.Number(info.maxRange)
        or info.minRange < 0 or info.maxRange < info.minRange
        or Client.Boolean(read(C_Spell.IsSpellHarmful, id)) ~= true then
        return nil
    end

    -- Range categories, not weapon/damage schools. Zero/zero may be melee;
    -- it is never evidence of distance. Only an explicit API false can tint it.
    local category = info.minRange == 0 and info.maxRange <= 5 and "melee" or "ranged"
    local name = "spell " .. id
    if Client.Readable(info.name) and type(info.name) == "string" then
        name = info.name:gsub("|", "||"):gsub("[\r\n]", " ")
    end

    return { id = id, name = name, minRange = info.minRange, maxRange = info.maxRange, category = category }
end


local function rangeCheck(api, ...)
    if type(api) ~= "function" then
        return nil, "missing API"
    end

    local ok, value = pcall(api, ...)
    if not ok then
        return nil, "error"
    elseif not Client.Readable(value) then
        return nil, "restricted"
    end

    local result = Client.Boolean(value)
    if result == nil then
        return nil, "unavailable"
    end

    return result, result and "in range" or "out of range"
end

function Client.InRange(id, slot, bank, unit)
    local result, bookStatus
    if Client.Number(slot) and Client.Number(bank) then
        result, bookStatus = rangeCheck(C_SpellBook and C_SpellBook.IsSpellBookItemInRange,
            slot, bank, unit)
    else
        bookStatus = "no spellbook slot"
    end

    if result ~= nil then
        return result, "spellbook", bookStatus, "not checked"
    end

    local idStatus
    result, idStatus = rangeCheck(C_Spell and C_Spell.IsSpellInRange, id, unit)

    return result, result ~= nil and "spell ID" or "none", bookStatus, idStatus
end

function Client.ActionInfo(slot)
    if not Client.Number(slot) or slot < 1 or slot ~= math.floor(slot) or not GetActionInfo then
        return nil
    end

    local ok, kind, id, subtype = pcall(GetActionInfo, slot)
    if not ok or not Client.String(kind) or not Client.Readable(id) or not Client.Readable(subtype) then
        return nil
    end

    return kind, id, subtype
end

function Client.ActionSpell(kind, id, subtype)
    if Client.Number(id) and (kind == "spell" or (kind == "macro" and subtype == "spell")) then
        return id
    end
end
