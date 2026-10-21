local _, root = ...
local addon = root.modules.Utilities
local Config = {}
addon.Config = Config
local defaults = {
    checkRangedAbilities = true,
    checkMeleeAbilities = true,
    highlightQueuedAttacks = true,
    queuedGlowNativeColor = false,
    queuedGlowColor = "ff26d9ff",
    greyOnCooldown = true,
    greyUnusableActions = true,
    greyWithoutResources = false,
    greyPetActions = true,
}
for index = 1, 8 do
    defaults["clickThroughBar" .. index] = false
end

local function validValue(key, value)
    if not addon.Client.Readable(value) then
        return false
    end

    if key == "queuedGlowColor" then
        return addon.Client.String(value) and #value == 8 and value:match("^%x+$") ~= nil
    end

    return type(value) == "boolean"
end

local function normalize(key, value)
    if key == "queuedGlowColor" then
        return "ff" .. value:sub(3):lower()
    end

    return value
end


local store
function Config.Initialize()
    if store then return end
    store = root.Config.NewStore("character", "utilities", defaults, validValue, normalize)
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
