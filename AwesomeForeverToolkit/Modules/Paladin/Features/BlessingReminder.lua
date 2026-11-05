local _, root = ...
local addon = root.modules.Paladin
local feature = {
    owner = 'paladin:blessing-reminder',
    settingKey = 'blessingReminderEnabled',
    preview = false,
}
addon.BlessingReminder = feature
addon:RegisterFeature(feature)

function feature:EnsurePopup()
    if self.popup then return end

    self.tracker = root.BuffTracker.New(addon.Blessings.groups)
    self.popup = addon.PopupIcons.New(self.owner, function(x, y)
        addon.Config.Set('blessingIconX', x)
        addon.Config.Set('blessingIconY', y)
    end)
    self.popup.frame:SetFrameStrata('LOW')
    self.popup.frame:SetClampedToScreen(true)
end

function feature:ApplySettings()
    self:EnsurePopup()
    self.popup:SetSize(addon.Config.Get('blessingIconSize'))
    self.popup:SetPosition(addon.Config.Get('blessingIconX'), addon.Config.Get('blessingIconY'))
    self.popup.texture:SetAlpha(addon.Config.Get('blessingHideIcon') and 0 or 1)
    self.popup.texture:SetDesaturated(true)
    addon.Glow.ConfigureOwner(self.owner, {color = {1, 0, 0, 1}, priority = 10})
end

function feature:OnEvent(event)
    if self.tracker and (event == 'UNIT_AURA' or event == 'PLAYER_ENTERING_WORLD'
        or event == 'PLAYER_REGEN_DISABLED' or event == 'PLAYER_REGEN_ENABLED'
        or event == 'PLAYER_DEAD' or event == 'SPELLS_CHANGED') then
        self.tracker:Invalidate()
    end
end

function feature:Refresh()
    if not addon.Config.Get(self.settingKey) then
        self:Stop()
        return
    end

    self:EnsurePopup()
    local texture = addon.Client.SpellIcon(20217)
    if not (root.Client.Number(texture) or root.Client.String(texture)) then
        texture = 'Interface\\Icons\\Spell_Magic_MageArmor'
    end
    self.popup:SetIcon(texture)

    self.state, self.detail = self.tracker:Sample()
    self.popup:SetVisible(self.state == 'missing', self.preview, true)
    addon.Glow.RefreshGeometry(self.popup.frame)
end

function feature:SetPreview(show)
    if not addon.started then return end

    self.preview = show == true and addon.active and addon.Config.Get(self.settingKey)
        and not InCombatLockdown() and not root.Client.InCombat()
    if self.popup then
        if not self.preview then
            self.popup.frame:StopMovingOrSizing()
            self.popup:SetPosition(addon.Config.Get('blessingIconX'), addon.Config.Get('blessingIconY'))
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

function feature:Diagnostics()
    self:EnsurePopup()
    self.tracker:Invalidate()
    local state, detail = self.tracker:Sample()
    print('Awesome Forever Toolkit: Kings/Freedom ' .. state .. ' (' .. detail.source .. ')')
    for _, group in ipairs(detail.groups) do
        print(group.key .. ': ' .. group.state .. ' | aura=' .. group.aura .. ' | tracked=' .. group.tracked
            .. ' (' .. group.trackedDetail .. ')')
    end
    print('Unknown means insufficient readable data. Hidden own-cast tracked icons cannot rule out Kings from other Paladins.')
end
