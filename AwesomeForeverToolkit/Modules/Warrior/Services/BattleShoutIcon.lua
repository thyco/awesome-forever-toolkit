local _, root = ...
local addon = root.modules.Warrior
local Icon = {}
addon.BattleShoutIcon = Icon

function Icon:Initialize()
    if self.popup then return end

    self.popup = root.ReminderIcon.New({
        name = "AwesomeForeverToolkitBattleShoutIcon",
        owner = "battle-shout-icon",
        texture = addon.Client.SpellTexture(6673) or "Interface\\Icons\\Ability_Warrior_BattleShout",
        canPreview = function() return addon.active and addon.Config.Get("battleShoutEnabled") end,
        onMoved = function(x, y)
            addon.Config.Set("iconX", x)
            addon.Config.Set("iconY", y)
        end,
    })
    self.frame, self.texture = self.popup.frame, self.popup.texture
    self:ApplySettings()
end

function Icon:ApplySettings()
    if not self.popup then return end

    local color
    if not addon.Config.Get("battleShoutNativeColor") then
        color = addon.Config.GetColor("glowColor")
    end

    self.popup:ApplySettings({
        size = addon.Config.Get("iconSize"),
        x = addon.Config.Get("iconX"), y = addon.Config.Get("iconY"),
        hideArtwork = addon.Config.Get("battleShoutHideIcon"),
        underlay = addon.Config.Get("battleShoutMode") == "underlay",
        color = color,
    })
end

function Icon:SetVisible(visible)
    self.visible = visible
    if self.popup then self.popup:SetVisible(visible) end
end

function Icon:SetPreview(enabled)
    if self.popup then
        self.popup:SetPreview(enabled)
        self.preview = self.popup.preview
    end
end
