local _, root = ...
local addon = root.modules.Gamepad
local M = {}
addon.ActionModel = M

function M.Copy(config)
    local result = {}
    for key, value in pairs(config or {}) do
        if key == "stances" then
            result.stances = {}
            for id, profile in pairs(value) do result.stances[id] = M.Copy(profile) end
        else
            result[key] = value
        end
    end
    return result
end

function M.Profile(config, stanceID)
    if stanceID and config.stances and config.stances[stanceID] then
        return M.Copy(config.stances[stanceID]), false
    end

    local profile = M.Copy(config)
    profile.stances = nil
    return profile, stanceID ~= nil
end

function M.WithProfile(config, stanceID, profile)
    local result = M.Copy(config)
    if stanceID then
        result.stances = result.stances or {}
        result.stances[stanceID] = profile and M.Copy(profile) or nil
    else
        result = M.Copy(profile or { mode = "native" })
        result.stances = M.Copy(config).stances
    end
    return result
end

function M.Forms()
    local forms = {}
    for index = 1, (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) do
        local icon, _, _, spellID = GetShapeshiftFormInfo(index)
        if spellID then
            local info = C_Spell.GetSpellInfo(spellID)
            forms[#forms + 1] = { index = index, spellID = spellID, iconID = icon,
                name = info and info.name or ("Stance " .. index) }
        end
    end
    return forms
end

local function Macro(name)
    local account, character = GetNumMacros()
    local found
    for _, range in ipairs({ {1, account}, {(MAX_ACCOUNT_MACROS or 120) + 1, (MAX_ACCOUNT_MACROS or 120) + character} }) do
        for index = range[1], range[2] do
            local macroName, icon = GetMacroInfo(index)
            if macroName == name then
                if found then return nil, "Give this macro a unique name across account and character macros." end
                found = { kind = "macro", macroName = name, name = name, iconID = icon, macroIndex = index }
            end
        end
    end
    if found then return found end

    return nil, "Macro is missing or renamed; drop it onto the button again.", "missing-macro"
end

function M.Resolve(config)
    if config.kind == "macro" then return Macro(config.macroName) end

    local info = config.spellID and C_Spell.GetSpellInfo(config.spellID)
    local body = info and addon.Overlay.BuildMacro(info.name)
    if not body then return nil, "Choose a valid spell or macro." end

    return { kind = "spell", spellID = config.spellID, name = info.name, iconID = info.iconID, macrotext = body }
end

function M.FromCursor(kind, cursorID, _, spellID)
    if kind == "macro" then
        local name = GetMacroInfo(cursorID)
        if not name then return nil, "Invalid macro." end

        local action, message = Macro(name)
        if not action then return nil, message end
        return { kind = "macro", macroName = name }
    elseif kind == "spell" and spellID and C_Spell.GetSpellInfo(spellID) then
        return { kind = "spell", spellID = spellID }
    end
    return nil, "Drop a spell from your spellbook or a macro from /macro onto this button."
end

function M.Driver(config, forms)
    local rules = {}
    for _, form in ipairs(forms) do
        local profile = config.stances and config.stances[form.spellID]
        if profile then
            local key = "form" .. form.spellID
            local condition = "form:" .. form.index
            if profile.mode == "always" then
                rules[#rules + 1] = "[" .. condition .. "] " .. key
            elseif profile.mode == "context" then
                rules[#rules + 1] = "[" .. condition .. ",combat][@target," .. condition .. ",harm,nodead] " .. key
                rules[#rules + 1] = "[@target," .. condition .. ",exists] native"
                rules[#rules + 1] = "[@mouseover," .. condition .. ",harm,nodead] " .. key
            end
            -- Explicit native also blocks inheritance from the basis.
            rules[#rules + 1] = "[" .. condition .. "] native"
        end
    end
    rules[#rules + 1] = addon.Overlay.BuildDriver(config.mode or "native")
    return table.concat(rules, "; ")
end

function M.Prepare(config)
    local actions = {}
    if config.mode and config.mode ~= "native" then
        local action, message, reason = M.Resolve(config)
        if not action then return nil, message, reason end
        actions.override = action
    end

    local forms = M.Forms()
    for _, form in ipairs(forms) do
        local profile = config.stances and config.stances[form.spellID]
        if profile and profile.mode ~= "native" then
            local action, message, reason = M.Resolve(profile)
            if not action then return nil, form.name .. ": " .. message, reason end
            actions["form" .. form.spellID] = action
        end
    end
    return actions, M.Driver(config, forms)
end
