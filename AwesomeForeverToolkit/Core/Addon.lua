local name, addon = ...
addon.name = name
addon.version = "0.1.0"
addon.modules = {}
addon.moduleOrder = {}

function addon.RegisterModule(id, module)
    assert(not addon.modules[id], "Duplicate module: " .. id)
    module.id = id
    addon.modules[id] = module
    addon.moduleOrder[#addon.moduleOrder + 1] = module
end

function addon.ClearPreviews()
    for _, module in ipairs(addon.moduleOrder) do
        if module.active and module.ClearPreviews then
            module:ClearPreviews()
        end
    end
end

function addon.Start()
    if addon.started then return end
    addon.started = true

    local _, class = UnitClass("player")
    for _, module in ipairs(addon.moduleOrder) do
        local loaded = false
        if module.legacy and C_AddOns and C_AddOns.IsAddOnLoaded then
            local ok, value = pcall(C_AddOns.IsAddOnLoaded, module.legacy)
            loaded = ok and value == true
        end

        if loaded then
            module.status = "disable " .. module.legacy .. " and reload"
        elseif module.class and (issecretvalue and issecretvalue(class) or class ~= module.class) then
            module.status = "wrong class"
        else
            module.active = true
            module.status = "active"
            module:Start()
        end
    end

    if addon.Window then addon.Window:Initialize() end
    if addon.Minimap then addon.Minimap:Initialize() end
end
