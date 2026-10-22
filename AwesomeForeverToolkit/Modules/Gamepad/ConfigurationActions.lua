local _, root = ...
local addon = root.modules.Gamepad
local Actions = {}
addon.ConfigurationActions = Actions

function Actions.Drop(face, stanceID)
    if addon.Runtime.IsLocked() then
        return false, "Wijzigen kan alleen buiten combat."
    end

    local action, message = addon.ActionModel.FromCursor(GetCursorInfo())
    if not action then return false, message end

    local config = addon.Runtime.GetConfig(face, stanceID)
    local mode = config.mode == "always" and "always" or "context"
    local ok, message = addon.Runtime.Configure(face, mode, action, stanceID)
    if ok then ClearCursor() end

    return ok, message
end

function Actions.SetMode(face, mode, stanceID)
    if addon.Runtime.IsLocked() then
        return false, "Wijzigen kan alleen buiten combat."
    end

    local config = addon.Runtime.GetConfig(face, stanceID)
    if mode ~= "native" and not config.spellID and not config.macroName then
        return false, "Sleep eerst een spell of macro naar het vak van deze knop."
    end

    return addon.Runtime.Configure(face, mode, config, stanceID)
end

function Actions.Clear(face, stanceID)
    if addon.Runtime.IsLocked() then
        return false, "Wijzigen kan alleen buiten combat."
    end

    return addon.Runtime.Configure(face, "native", nil, stanceID, stanceID ~= nil)
end
