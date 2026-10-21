local _, addon = ...
local Config = {}
addon.Config = Config

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function Config.GetSection(scope, id)
    assert(scope == "account" or scope == "character", "Invalid configuration scope")
    local name = scope == "account" and "AwesomeForeverToolkitDB" or "AwesomeForeverToolkitCharacterDB"
    if not readable(_G[name]) or type(_G[name]) ~= "table" then _G[name] = {} end
    local database = _G[name]
    database.schemaVersion = 1

    if not readable(database[id]) or type(database[id]) ~= "table" then database[id] = {} end
    return database[id]
end

function Config.NewStore(scope, id, defaults, validate, normalize)
    local values = Config.GetSection(scope, id)
    local listeners = {}
    local store = {}
    normalize = normalize or function(_, value) return value end

    for key, default in pairs(defaults) do
        if readable(values[key]) and validate(key, values[key]) then
            values[key] = normalize(key, values[key])
        else
            values[key] = default
        end
    end

    function store.Get(key) return values[key] end
    function store.GetDefault(key) return defaults[key] end
    function store.Subscribe(listener) listeners[#listeners + 1] = listener end
    function store.GetColor(key)
        local hex = store.Get(key)
        return {tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255,
            tonumber(hex:sub(7, 8), 16) / 255, 1}
    end

    function store.Set(key, value)
        assert(defaults[key] ~= nil, "Unknown configuration key: " .. tostring(key))
        assert(readable(value) and validate(key, value), "Invalid configuration value: " .. key)
        value = normalize(key, value)
        if values[key] == value then return false end

        values[key] = value
        for _, listener in ipairs(listeners) do listener(key, value) end
        return true
    end

    return store
end
