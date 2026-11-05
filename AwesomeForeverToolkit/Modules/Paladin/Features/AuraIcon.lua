local _, root = ...
local addon = root.modules.Paladin
local feature = {
    owner = 'paladin:aura-icon',
    settingKey = 'auraIconEnabled',
    preview = false,
}
addon.AuraIcon = feature
addon:RegisterFeature(feature)

local devotionAura = 465
local fallbackTexture = 'Interface\\Icons\\Spell_Holy_DevotionAura'

function feature:EnsurePopup()
    if self.popup then
        return
    end

    self.popup = addon.PopupIcons.New(self.owner, function(x, y)
        addon.Config.Set('auraIconX', x)
        addon.Config.Set('auraIconY', y)
    end)
    self.popup.frame:SetFrameStrata('LOW')
    self.popup.frame:SetClampedToScreen(true)
end

function feature:ApplySettings()
    self:EnsurePopup()
    self.popup:SetSize(addon.Config.Get('auraIconSize'))
    self.popup:SetPosition(addon.Config.Get('auraIconX'), addon.Config.Get('auraIconY'))
    addon.Glow.ConfigureOwner(self.owner, { color = {1, 0, 0, 1}, priority = 10 })
end

function feature:Refresh()
    if not addon.Config.Get(self.settingKey) then
        self:Stop()
        return
    end

    self:EnsurePopup()
    local status, texture = addon.Client.CurrentAura()
    local missing = status == 'absent' or (self.preview and status == 'unknown')

    if missing then
        texture = addon.Client.SpellIcon(devotionAura)
        if not (root.Client.Number(texture) or root.Client.String(texture)) then
            texture = fallbackTexture
        end
    end

    self.popup:SetIcon(texture)
    -- Match cooldown greying: full desaturation without darkening or fading.
    self.popup.texture:SetDesaturated(missing)
    self.popup:SetVisible(status ~= 'unknown', self.preview, missing)
    addon.Glow.RefreshGeometry(self.popup.frame)
end

function feature:SetPreview(show)
    if not addon.started then
        return
    end

    self.preview = show == true and addon.active and addon.Config.Get(self.settingKey)
        and not InCombatLockdown() and not root.Client.InCombat()
    if self.popup then
        if not self.preview then
            self.popup.frame:StopMovingOrSizing()
            self.popup:SetPosition(addon.Config.Get('auraIconX'), addon.Config.Get('auraIconY'))
        end
        self.popup.frame:SetFrameStrata(self.preview and 'TOOLTIP' or 'LOW')
    end

    self:Refresh()
end

function feature:Stop()
    self.preview = false
    if self.popup then
        self.popup.frame:StopMovingOrSizing()
        self.popup.frame:SetFrameStrata('LOW')
        self.popup:SetVisible(false, false, false)
    end
end
