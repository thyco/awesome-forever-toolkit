local _, root = ...
local addon = root.modules.Hunter
local W = root.Widgets
local function available() return addon.active == true end
local className = select(2, UnitClass("player")) == "HUNTER" and UnitClass("player") or "Hunter"

root.Window:RegisterPage({
    id = "hunter.reactive", label = "Reactive abilities", parent = className, available = available,
    build = function(parent, context)
        local layout = W.Layout(parent, context, "hunter", addon.Config)
        for _, item in ipairs({{"mongoose", "Mongoose Bite"}, {"counterattack", "Counterattack"}}) do
            local kind, label = item[1], item[2]
            layout:Heading(label)
            layout:Text(kind == "mongoose"
                and "Combat opportunity; ignores cooldowns like Overpower."
                or "Combat opportunity; ignores the GCD but respects its own cooldown, like Revenge.")
            layout:Field("Checkbox", kind .. "GlowEnabled", "Enable " .. label .. " glow")
            root.DisplayLocation.Create(layout, addon.Config, kind, "ChoiceDropdown")
            layout:Field("Checkbox", kind .. "NativeColor", "Use Blizzard native glow")
            layout:Field("Color", kind .. "GlowColor", "Custom glow color")
            if kind == "counterattack" then
                layout:Field("Checkbox", "counterattackOverlayEnabled", "Show Counterattack icon overlay")
            end
            layout:Button(kind .. "Preview", "Preview glow (3s)", function()
                local ok, reason = addon.ReactiveAbilities:Preview(kind)
                if not ok then print("Awesome Forever Toolkit: " .. tostring(reason)) end
            end)
        end
        layout:Finish()
    end,
})

root.Window:RegisterPage({
    id = "hunter.reminders", label = "Hunter reminders", parent = className, available = available,
    build = function(parent, context)
        local layout = W.Layout(parent, context, "hunter", addon.Config)
        local feedback = W.Text(parent, "", 20, -12)
        feedback:SetTextColor(1, 0.4, 0.3)
        feedback:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -12)
        layout.y = -52

        local function number(key, label, message)
            layout:Field("Number", key, label, {
                validate = function(value) return addon.Config.CanSet(key, value) end,
                feedback = feedback, message = message,
            })
        end

        layout:Heading("Ammunition")
        layout:Field("Checkbox", "ammoCheckEnabled", "Enable ammo check")
        layout:Field("Checkbox", "ammoShowCount", "Show ammunition count")
        layout:Text("Keep thresholds ordered: hide > yellow > red > warning.")
        for _, item in ipairs({{"ammoHideAbove", "Hide above"}, {"ammoYellowAt", "Yellow at or below"},
            {"ammoRedAt", "Red at or below"}, {"ammoWarnBelow", "Warn below"}}) do
            number(item[1], item[2], "Use positive whole numbers: hide > yellow > red > warning.")
        end
        layout:Button("resetAmmo", "Reset ammo thresholds", function()
            addon.Config.ResetAmmoThresholds()
            feedback:SetText("")
            root.Window:Refresh()
        end)
        layout:Button("moveAmmo", "Move / preview ammo icon", function() addon.AmmoIcon:SetPreview(true) end)

        layout:Heading("Pet health")
        layout:Field("Checkbox", "petHealthEnabled", "Show low pet health icon")
        layout:Field("Checkbox", "petShowPercent", "Show health percentage")
        number("petHealthThreshold", "Health threshold (%)", "Use a whole percentage between 1 and 100.")
        layout:Field("Checkbox", "petFlashEnabled", "Flash screen in combat at low health")
        layout:Field("Color", "petFlashColor", "Flash color")
        number("petFlashIntensity", "Pulse intensity (%)", "Use a whole percentage between 10 and 300.")
        layout:Button("previewPetFlash", "Toggle pulse preview", function()
            addon.PetWarning.SetPreview(not addon.PetWarning.preview)
        end)
        layout:Button("movePet", "Move / preview pet health icon", function() addon.PetHealthIcon:SetPreview(true) end)

        layout:Heading("Pet happiness")
        layout:Field("Checkbox", "petHappinessEnabled", "Show unhappy pet icon")
        layout:Button("moveHappiness", "Move / preview happiness icon", function() addon.PetHappinessIcon:SetPreview(true) end)

        layout:Heading("Movement aspects")
        layout:Field("Checkbox", "aspectCheckEnabled", "Show Cheetah / Pack icon in combat")
        layout:Field("Checkbox", "aspectGlowEnabled", "Glow around aspect icon")
        layout:Button("moveAspect", "Move / preview aspect icon", function() addon.AspectIcon:SetPreview(true) end)
        layout:Finish()
    end,
})
