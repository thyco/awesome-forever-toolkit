local _, root = ...
local Client = {}
root.modules.Paladin.Client = Client
Client.Readable = root.Client.Readable
local read = root.Client.Read
local number = root.Client.Number

function Client.SpellID(name)
    local info = read(C_Spell and C_Spell.GetSpellInfo, name)
    if root.Client.Table(info) then return number(info.spellID) end

    if type(GetSpellInfo) == 'function' then
        local ok, _, _, _, _, _, _, id = pcall(GetSpellInfo, name)
        if ok then return number(id) end
    end
end

function Client.SpellName(id)
    return root.Client.SpellName(id)
end

function Client.SpellIcon(id)
    if not number(id) then return nil end
    return read((C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture, id)
end

Client.HasShieldEquipped = root.Client.HasShield

function Client.PlayerAuraExpiration(spellID)
    if not number(spellID) then return 'unknown' end

    local secretAPI = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
    if secretAPI then
        if root.Client.Boolean(read(secretAPI, spellID)) ~= false then return 'unknown' end
    elseif InCombatLockdown() then
        return 'unknown'
    end

    local api = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(api) ~= 'function' then return 'unknown' end
    local ok, aura = pcall(api, spellID)
    if not ok or not Client.Readable(aura) then return 'unknown' end
    if aura == nil then return 'absent' end
    if not root.Client.Table(aura) then return 'unknown' end

    local expiration = number(aura.expirationTime)
    if expiration and expiration > 0 then return 'present', expiration end
    return 'unknown'
end

function Client.IsKnown(id)
    if not number(id) then return false end
    local api = C_SpellBook and C_SpellBook.IsSpellKnown or IsSpellKnownOrOverridesKnown or IsSpellKnown
    return root.Client.Boolean(read(api, id)) == true
end

function Client.Cooldown(id)
    if not number(id) then return nil end
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = read(C_Spell.GetSpellCooldown, id)
        return root.Client.Table(info) and info or nil
    end

    if type(GetSpellCooldown) == 'function' then
        local ok, startTime, duration, enabled, modRate = pcall(GetSpellCooldown, id)
        if ok and number(startTime) and number(duration) then
            return { startTime = startTime, duration = duration,
                isEnabled = root.Client.Boolean(enabled), modRate = number(modRate) or 1 }
        end
    end
end

function Client.HasUnit(unit)
    return root.Client.Boolean(read(UnitExists, unit)) == true
end

function Client.CanAttack(unit)
    return Client.HasUnit(unit) and root.Client.Boolean(read(UnitIsDeadOrGhost, unit)) == false
        and root.Client.Boolean(read(UnitCanAttack, 'player', unit)) == true
end

function Client.CanSpellTargetUnit(spellID, unit)
    if not number(spellID) then return false end
    local result = read(C_Spell and C_Spell.IsSpellInRange, spellID, unit)
    -- Both in and out of range prove target eligibility; unknown does not.
    return type(result) == 'boolean'
end

function Client.HasAttackableCreatureType(unit, acceptedTypes, spellID)
    if not Client.CanAttack(unit) then return false end

    if type(UnitCreatureType) == 'function' then
        local ok, name, id = pcall(UnitCreatureType, unit)
        if ok and number(id) then return acceptedTypes[id] == true end
        if ok and root.Client.String(name) and C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo then
            for acceptedID in pairs(acceptedTypes) do
                local info = read(C_CreatureInfo.GetCreatureTypeInfo, acceptedID)
                if root.Client.Table(info) and root.Client.String(info.name) and name == info.name then
                    return true
                end
            end
            return false
        end
    end

    return Client.CanSpellTargetUnit(spellID, unit)
end

function Client.HasGlowContext()
    return root.Client.InCombat() or Client.CanAttack('target') or Client.CanAttack('mouseover')
end
