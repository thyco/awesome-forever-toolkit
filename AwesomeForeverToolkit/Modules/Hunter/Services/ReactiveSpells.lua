local _, root = ...
local addon = root.modules.Hunter
local ReactiveSpells = { ids = { mongoose = {}, counterattack = {} }, gcdOnly = {},
    procUsable = {}, consumedUntil = {} }
addon.ReactiveSpells = ReactiveSpells

local seeds = { mongoose = 1495, counterattack = 19306 }
local gcdEvidenceSeconds = 1.6

local function read(api, ...)
    if type(api) ~= "function" then return nil end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then return value end
end

local function member(container, key)
    if not addon.Client.Readable(container) or type(container) ~= "table" then
        return nil
    end

    local ok, value = pcall(function() return container[key] end)
    if ok and addon.Client.Readable(value) then return value end
end

local function spellAPI(name)
    return member(C_Spell, name)
end

local function spellName(id)
    local info = read(spellAPI("GetSpellInfo"), id)
    local name = member(info, "name")

    if type(name) == "string" and name ~= "" then
        return name
    end
end

local function nonnegative(value)
    local number = addon.Client.Number(value)
    if number and number >= 0 then return number end
end

local function durationBoolean(duration, name)
    local ok, method = pcall(function() return duration[name] end)
    if not ok or not addon.Client.Readable(method) or type(method) ~= "function" then
        return nil
    end

    return addon.Client.Boolean(read(method, duration))
end

function ReactiveSpells.ResetEvidence()
    ReactiveSpells.gcdOnly, ReactiveSpells.procUsable, ReactiveSpells.consumedUntil = {}, {}, {}
end

function ReactiveSpells.Rebuild()
    ReactiveSpells.ids = { mongoose = {}, counterattack = {} }
    ReactiveSpells.ResetEvidence()
    local names, seen = {}, {}

    for kind, seed in pairs(seeds) do
        local name = spellName(seed)
        if name then names[name] = kind end
    end

    local entries = addon.Client.PlayerSpells()
    if not addon.Client.Readable(entries) or type(entries) ~= "table" then return end

    for _, entry in ipairs(entries) do
        local id = nonnegative(member(entry, "id"))
        if id and id == math.floor(id) and not seen[id] then
            local name = spellName(id)
            local kind = name and names[name]
            if kind then
                table.insert(ReactiveSpells.ids[kind], id)
                seen[id] = true
            end
        end
    end
end

function ReactiveSpells.ObserveCooldownEvent()
    ReactiveSpells.gcdOnly = {}
    local now = nonnegative(read(GetTime))
    local deadline = now and addon.Client.Number(now + gcdEvidenceSeconds)
    if not deadline then return end

    for _, ranks in pairs(ReactiveSpells.ids) do
        for _, id in ipairs(ranks) do
            local info = read(spellAPI("GetSpellCooldown"), id)
            if addon.Client.Boolean(member(info, "isOnGCD")) == true then
                ReactiveSpells.gcdOnly[id] = deadline
            end
        end
    end
end

function ReactiveSpells.ReactiveCast(unit, spellID)
    if not addon.Client.Readable(unit) or unit ~= "player"
        or not addon.Client.Number(spellID) then return false end

    for kind, ranks in pairs(ReactiveSpells.ids) do
        for _, id in ipairs(ranks) do
            if id == spellID then
                for _, rank in ipairs(ranks) do
                    ReactiveSpells.gcdOnly[rank], ReactiveSpells.procUsable[rank] = nil, nil
                end

                -- Cover the cast event before cooldown/usability catches up. This always
                -- expires, so a missed cooldown event cannot suppress the next opening.
                local now = nonnegative(read(GetTime))
                ReactiveSpells.consumedUntil[kind] = now and now + gcdEvidenceSeconds

                return true
            end
        end
    end

    return false
end

local function signalFor(id)
    local api = spellAPI("IsSpellUsable")
    if type(api) ~= "function" then return "unknown" end

    local ok, usableValue, powerValue = pcall(api, id)
    if not ok then return "unknown" end

    local usable = addon.Client.Boolean(usableValue)
    if usable == true then return "usable" end
    if usable == false then
        if not addon.Client.Readable(powerValue) then return "unknown" end

        local insufficientPower = addon.Client.Boolean(powerValue)
        if insufficientPower == true then return "low-power" end
        if insufficientPower == false or powerValue == nil then return "inactive" end
    end

    return "unknown"
end

local function eventGCDReady(id)
    local deadline = ReactiveSpells.gcdOnly[id]
    if not deadline then return false end

    local now = nonnegative(read(GetTime))
    if not now or now >= deadline then
        ReactiveSpells.gcdOnly[id] = nil

        return false
    end

    return true
end

local function cooldownFor(id)
    local info = read(spellAPI("GetSpellCooldown"), id)

    if type(info) ~= "table" then
        return "unknown"
    end

    local enabled = addon.Client.Boolean(member(info, "isEnabled"))
    if enabled == false then return "blocked" end

    local active = addon.Client.Boolean(member(info, "isActive"))
    if active == false then return "ready" end

    local ownDuration = read(spellAPI("GetSpellCooldownDuration"), id, true)
    if ownDuration then
        if durationBoolean(ownDuration, "HasSecretValues") == false then
            local zero = durationBoolean(ownDuration, "IsZero")
            if zero == true then return "ready" end

            if zero == false then
                local expired = durationBoolean(ownDuration, "HasExpired")
                if expired == true then return "ready" end
                if expired == false then
                    ReactiveSpells.gcdOnly[id] = nil

                    return "blocked"
                end
            end
        end
    end

    local start = nonnegative(member(info, "startTime"))
    local duration = nonnegative(member(info, "duration"))
    if not start or not duration then
        -- Only unknown timing needs the transient event fallback. Readable own
        -- cooldowns below take precedence, even when the event also reports GCD.
        return eventGCDReady(id) and "ready" or "unknown"
    end
    if start == 0 or duration == 0 then return "ready" end

    local gcd = read(spellAPI("GetSpellCooldown"), addon.gcdSpellID)
    local gcdStart = nonnegative(member(gcd, "startTime"))
    local gcdDuration = nonnegative(member(gcd, "duration"))
    if gcdStart and gcdDuration and gcdDuration > 0
        and start == gcdStart and duration == gcdDuration then
        return "ready"
    end

    local now = nonnegative(read(GetTime))
    local expires = addon.Client.Number(start + duration)
    if not now or not expires then return "unknown" end
    if now >= expires then return "ready" end

    ReactiveSpells.gcdOnly[id] = nil

    return "blocked"
end

local function gcdActive(id)
    if eventGCDReady(id) then return true end

    local gcd = read(spellAPI("GetSpellCooldown"), addon.gcdSpellID)
    local start, duration = nonnegative(member(gcd, "startTime")), nonnegative(member(gcd, "duration"))
    local now = nonnegative(read(GetTime))
    return start and duration and now and duration > 0 and now < start + duration
end

function ReactiveSpells.Evaluate(kind)
    local result = { ready = false, learned = false, id = nil, signal = "unknown", cooldown = "unknown" }
    if not addon.Client.Readable(kind) or type(kind) ~= "string" or not seeds[kind] then return result end

    local ranks = ReactiveSpells.ids[kind]
    result.learned = #ranks > 0
    local now = nonnegative(read(GetTime))
    local deadline = ReactiveSpells.consumedUntil[kind]
    if deadline and now and now >= deadline then
        ReactiveSpells.consumedUntil[kind] = nil
        deadline = nil
    end

    for _, id in ipairs(ranks) do
        local signal, cooldown = signalFor(id), cooldownFor(id)
        local opportunity = signal == "usable" or signal == "low-power"
        local cached = ReactiveSpells.procUsable[id]

        if deadline or cooldown ~= "ready" or signal == "unknown" then
            ReactiveSpells.procUsable[id] = nil
            opportunity = false
        elseif opportunity then
            ReactiveSpells.procUsable[id] = now and now + gcdEvidenceSeconds
        elseif signal == "inactive" and cached and now and now < cached and gcdActive(id) then
            opportunity = true
            signal = "gcd-opening"
        else
            ReactiveSpells.procUsable[id] = nil
        end

        if result.id == nil or opportunity then
            result.id, result.signal, result.cooldown = id, signal, cooldown
        end
        if opportunity then
            result.ready = true
            break
        end
    end

    return result
end
