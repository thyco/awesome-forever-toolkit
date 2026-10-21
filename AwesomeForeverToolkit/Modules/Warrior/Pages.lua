local _, root = ...
local addon = root.modules.Warrior
local W = root.Widgets
local function available() return addon.active == true end
local sizes = W.Options(16, 128, 4, "", " pixels")
local abilities = {
    {value = "battleShout", label = "Battle Shout", description = "Combat reminder for your Battle Shout buff"},
    {value = "overpower", label = "Overpower", description = "Battle Stance usability or Berserker Stance opening"},
    {value = "revenge", label = "Revenge", description = "Defensive Stance usability"},
    {value = "execute", label = "Execute", description = "Battle or Berserker Stance usability"},
    {value = "victoryRush", label = "Victory Rush", description = "Usable and off its own cooldown"},
    {value = "shieldBlock", label = "Shield Block", description = "In combat, Defensive Stance, shield equipped, off cooldown"},
}

root.Window:RegisterPage({
    id = "warrior.reminders", label = "Reminders & glows", parent = "Warrior", available = available,
    build = function(parent, context)
        local frames = {}
        local state = root.Config.GetSection("character", "ui")
        local selected = state.warriorFeature
        local valid = false
        for _, item in ipairs(abilities) do if item.value == selected then valid = true end end
        if not valid then selected = "battleShout" end

        for _, item in ipairs(abilities) do
            local frame = CreateFrame("Frame", nil, parent)
            frame:SetPoint("TOPLEFT", 0, -60)
            frame:SetPoint("TOPRIGHT", 0, -60)
            local layout = W.Layout(frame, context, "warrior", addon.Config)
            layout:Heading(item.label)
            layout:Text(item.description)
            layout:Field("Checkbox", item.value .. "Enabled", "Enable " .. item.label .. " reminder")

            if item.value == "battleShout" then
                layout:Field("Dropdown", "leadSeconds", "Remind before expiry", W.Options(1, 60, 1, "", " seconds"))
                layout:Field("Checkbox", "battleShoutNativeColor", "Use Blizzard native glow")
                layout:Field("Color", "glowColor", "Custom glow color")
                layout:Field("Dropdown", "iconSize", "Icon size", sizes)
                layout:Field("Checkbox", "battleShoutHideIcon", "Hide icon artwork (keep glow)")
                layout:Button("moveBattleShout", "Move / preview icon", function() addon.BattleShoutIcon:SetPreview(true) end)
            else
                root.DisplayLocation.Create(layout, addon.Config, item.value)
                layout:Heading("Appearance")
                if item.value == "overpower" then
                    layout:Field("Checkbox", "overpowerBattleNativeColor", "Battle Stance: native glow")
                    layout:Field("Color", "overpowerBattleGlowColor", "Battle Stance color")
                    layout:Field("Checkbox", "overpowerBerserkerNativeColor", "Berserker Stance: native glow")
                    layout:Field("Color", "overpowerBerserkerGlowColor", "Berserker Stance color")
                else
                    layout:Field("Checkbox", item.value .. "NativeColor", "Use Blizzard native glow")
                    layout:Field("Color", item.value .. "GlowColor", "Custom glow color")
                end
                if item.value == "victoryRush" then
                    layout:Field("Checkbox", "victoryRushCombatOnly", "Only show in combat")
                end
                layout:Button(item.value .. "Preview", "Preview gamepad glow (3s)", function()
                    local ok, reason = addon.ReactiveAbilities:PreviewGamepad(item.value)
                    if not ok then print("Awesome Forever Toolkit: " .. tostring(reason)) end
                end)
            end

            layout:Finish()
            frames[item.value] = frame
        end

        local function select(value)
            addon:ClearPreviews()
            selected = value
            state.warriorFeature = value
            for key, frame in pairs(frames) do frame:SetShown(key == value) end
            parent:SetHeight(frames[value]:GetHeight() + 70)
            root.Window.scroll:SetVerticalScroll(0)
            local selector = context.controls["warrior.feature"]
            if selector then selector.refresh() end
        end
        local setting = {GetValue = function() return selected end, SetValue = function(_, value) select(value) end}
        context.controls["warrior.feature"] = W.Dropdown(parent, "Feature", -10, setting, abilities)
        select(selected)
    end,
})

root.Window:RegisterPage({
    id = "warrior.stance", label = "Stance indicator", parent = "Warrior", available = available,
    build = function(parent, context)
        local layout = W.Layout(parent, context, "warrior", addon.Config)
        layout:Heading("Current stance")
        layout:Field("Checkbox", "stanceIconEnabled", "Show current stance icon")
        layout:Field("Dropdown", "stanceIconSize", "Icon size", sizes)
        layout:Field("Checkbox", "shieldCornerEnabled", "Show shield corner when equipped")
        layout:Field("Color", "shieldCornerColor", "Shield corner color")
        layout:Field("Dropdown", "shieldCornerPosition", "Shield corner position", {
            {value = "TOPLEFT", label = "Top left"}, {value = "TOPRIGHT", label = "Top right"},
            {value = "BOTTOMLEFT", label = "Bottom left"}, {value = "BOTTOMRIGHT", label = "Bottom right"},
        })
        layout:Button("moveStance", "Move / preview stance icon", function() addon.StanceIcon:SetPreview(true) end)
        layout:Finish()
    end,
})
