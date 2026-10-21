local _, root = ...
local addon = root.modules.Warrior
local Config = {}
addon.Config = Config

local defaults = {
    battleShoutEnabled = true,
    leadSeconds = 10,
    battleShoutNativeColor = false,
    battleShoutHideIcon = false,
    glowColor = "ff00ff00",
    iconSize = 64,
    iconX = 0,
    iconY = -270,
    stanceIconEnabled = true,
    stanceIconSize = 64,
    stanceIconX = 0,
    stanceIconY = -180,
    shieldCornerEnabled = true,
    shieldCornerColor = "ff00ff00",
    shieldCornerPosition = "TOPLEFT",
    overpowerEnabled = true,
    overpowerBar = 0,
    overpowerButton = 1,
    overpowerBattleNativeColor = true,
    overpowerBattleGlowColor = "ffffd24a",
    overpowerBerserkerNativeColor = true,
    overpowerBerserkerGlowColor = "ffff0000",
    revengeEnabled = true,
    revengeBar = 0,
    revengeButton = 1,
    revengeNativeColor = true,
    revengeGlowColor = "ff00bfa5",
    executeEnabled = true,
    executeBar = 0,
    executeButton = 1,
    executeNativeColor = true,
    executeGlowColor = "ffffd24a",
    victoryRushEnabled = true,
    victoryRushCombatOnly = true,
    victoryRushBar = 0,
    victoryRushButton = 1,
    victoryRushNativeColor = true,
    victoryRushGlowColor = "ffffd24a",
    shieldBlockEnabled = true,
    shieldBlockBar = 0,
    shieldBlockButton = 1,
    shieldBlockNativeColor = true,
    shieldBlockGlowColor = "ffffd24a",
}
for _, kind in ipairs({ "overpower", "revenge", "execute", "victoryRush", "shieldBlock" }) do
    defaults[kind .. "GamepadPage"] = 1
    defaults[kind .. "GamepadBar"] = 1
    defaults[kind .. "GamepadButton"] = 1
end

local colorKeys = {
    glowColor = true,
    overpowerBattleGlowColor = true,
    overpowerBerserkerGlowColor = true,
    revengeGlowColor = true,
    executeGlowColor = true,
    victoryRushGlowColor = true,
    shieldBlockGlowColor = true,
    shieldCornerColor = true,
}

local function validValue(key, value)
    if issecretvalue and issecretvalue(value) then
        return false
    end

    if type(value) ~= type(defaults[key]) then
        return false
    end

    if key:match("GamepadPage$") then
        return value >= 0 and value <= 3 and value == math.floor(value)
    end
    if key:match("GamepadBar$") then
        return value >= 1 and value <= 4 and value == math.floor(value)
    end
    if key:match("GamepadButton$") then
        return value >= 1 and value <= 8 and value == math.floor(value)
    end

    if key == "overpowerBar" or key == "revengeBar" or key == "executeBar"
        or key == "victoryRushBar" or key == "shieldBlockBar" then
        return value >= 0 and value <= 8 and value == math.floor(value)
    end

    if key == "overpowerButton" or key == "revengeButton" or key == "executeButton"
        or key == "victoryRushButton" or key == "shieldBlockButton" then
        return value >= 1 and value <= 12 and value == math.floor(value)
    end

    if key == "leadSeconds" then
        return value >= 1 and value <= 60 and value == math.floor(value)
    end

    if key == "iconSize" or key == "stanceIconSize" then
        return value >= 16 and value <= 128 and value % 4 == 0
    end

    if key == "shieldCornerPosition" then
        return value == "TOPLEFT" or value == "TOPRIGHT"
            or value == "BOTTOMLEFT" or value == "BOTTOMRIGHT"
    end

    if colorKeys[key] then
        return #value == 8 and value:match("^%x+$") ~= nil
    end

    if key == "iconX" or key == "iconY" or key == "stanceIconX" or key == "stanceIconY" then
        return value == value and value >= -4096 and value <= 4096
    end

    return true
end

local function normalize(key, value)
    if colorKeys[key] then
        return "ff" .. value:sub(3):lower()
    end

    return value
end

local store
function Config.Initialize()
    if store then return end
    store = root.Config.NewStore("account", "warrior", defaults, validValue, normalize)
end

function Config.GetDefault(key) return defaults[key] end
function Config.Get(key)
    Config.Initialize()
    return store.Get(key)
end
function Config.GetColor(key)
    Config.Initialize()
    return store.GetColor(key)
end
function Config.Set(key, value)
    Config.Initialize()
    return store.Set(key, value)
end
function Config.Subscribe(listener)
    Config.Initialize()
    store.Subscribe(listener)
end
