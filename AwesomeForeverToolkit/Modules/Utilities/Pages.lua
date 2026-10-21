local _, root = ...
local addon = root.modules.Utilities
local function available() return addon.active == true end

root.Window:RegisterPage({
    id = "utilities", label = "Action bars", available = available,
    build = function(parent, context)
        local layout = root.Widgets.Layout(parent, context, "utilities", addon.Config)
        layout:Heading("Range checks")
        layout:Field("Checkbox", "checkRangedAbilities", "Check ranged abilities")
        layout:Field("Checkbox", "checkMeleeAbilities", "Check melee abilities")
        layout:Heading("Queued attacks")
        layout:Field("Checkbox", "highlightQueuedAttacks", "Highlight queued next-swing attacks")
        layout:Field("Checkbox", "queuedGlowNativeColor", "Use glow's native color")
        layout:Field("Color", "queuedGlowColor", "Custom glow color")
        layout:Heading("Cooldown greying")
        layout:Field("Checkbox", "greyOnCooldown", "Grey actions on cooldown")
        layout:Field("Checkbox", "greyUnusableActions", "Grey unusable actions")
        layout:Field("Checkbox", "greyWithoutResources", "Grey actions without resources")
        layout:Field("Checkbox", "greyPetActions", "Grey pet actions")
        layout:Heading("Action bar click-through")
        layout:Text("Hold Shift outside combat to interact with selected bars.")
        for index = 1, 8 do
            layout:Field("Checkbox", "clickThroughBar" .. index, "Bar " .. index .. " click-through")
        end
        layout:Finish()
    end,
})

root.Window:RegisterPage({
    id = "graphics", label = "Graphics", available = available,
    build = function(parent, context)
        local layout = root.Widgets.Layout(parent, context, "graphics", addon.Config)
        layout:Heading("Graphics")
        layout:Text("Account-wide settings. Reset restores the client default.")
        for _, setting in ipairs(addon.Graphics.settings) do
            context.controls["graphics." .. setting.key] = root.Widgets.GraphicsSetting(parent, setting, layout.y, addon.Graphics)
            layout.y = layout.y - 112
        end
        layout:Finish()
    end,
})
