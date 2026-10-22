local _, root = ...
local addon = root.modules.Gamepad
addon.Config = {}

function addon.Config.Initialize()
    local state = root.Config.GetSection("character", "gamepad")
    if type(state.bindings) ~= "table" then state.bindings = {} end
    if type(state.enabled) ~= "table" then state.enabled = {} end

    addon.Config.state = state
end

function addon.Config.Bindings()
    return addon.Config.state.bindings
end

function addon.Config.Enabled()
    return addon.Config.state.enabled
end
