local _, addon = ...
addon.Window:RegisterPage({
    id = "general", label = "General",
    build = function(parent, context)
        local state = addon.Config.GetSection("character", "ui")
        local store = {
            Get = function() return state.minimapHidden ~= true end,
            Set = function(_, value)
                state.minimapHidden = not value
                if addon.Minimap then addon.Minimap:Refresh() end
            end,
        }
        local layout = addon.Widgets.Layout(parent, context, "general", store)
        layout:Heading("General")
        layout:Field("Checkbox", "showMinimap", "Show minimap button")
        layout:Text("Open this window with /aft or /af.")
        for _, module in ipairs(addon.moduleOrder) do
            if module.status and module.status:match("^disable") then
                layout:Text(module.id .. ": " .. module.status)
            end
        end
        layout:Finish()
    end,
})
