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

root.Window:RegisterPage({
    id = "targetCastbar", label = "Target castbar", available = available,
    build = function(parent, context)
        local mover = addon.TargetCastbar
        local layout = root.Widgets.Layout(parent, context, "targetCastbar", mover)
        local function report(ok, reason)
            if not ok then print("Awesome Forever Toolkit: " .. tostring(reason)) end
        end

        layout:Heading("Target castbar")
        layout:Text("Moves Blizzard's target castbar. Position and scale are account-wide. Disable ForeverTargetCastbar before enabling this feature.")
        layout:Field("Checkbox", "enabled", "Enable target castbar positioning")
        layout:Field("ChoiceDropdown", "scale", "Scale", root.Widgets.Options(50, 300, 5, "", "%"))
        layout:Text("Drag the preview outside combat. The bar's centre is anchored to a percentage of the screen, independently of the target frame. Scaling is relative to its native size.")
        layout:Button("preview", "Move / preview castbar", function() report(mover:Preview()) end)
        layout:Button("lock", "Lock / hide preview", function() mover:ClosePreview() end)
        layout:Button("reset", "Reset position and scale", function()
            report(mover:Reset())
            root.Window:Refresh()
        end)
        layout:Finish()
    end,
})
