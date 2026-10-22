local _, root = ...
local addon = root.modules.Paladin
local feature = {
    spells = {},
    owner = "paladin:holy-strike-ready",
    settingKey = "cooldownGlowEnabled",
}
addon.HolyStrikeGlow = feature
addon:RegisterFeature(feature)

function feature:ApplySettings()
    self.activeStyle = nil

    if not addon.Config.Get("holyStrikeCheckEnabled") and self.spells.holyStrike then
        addon.Cooldowns.Invalidate(self.spells.holyStrike)
    end
end

function feature:Refresh(discover, cooldownEvent)
    if discover then
        self.spells = {
            holyStrike = addon.Client.SpellID("Holy Strike"),
            judgement = addon.Client.SpellID("Judgement"),
        }
    end

    local button = addon:Selected("holyStrike")
    if self.button and self.button ~= button then
        addon.Glow.Set(self.button, self.owner, false)
    end

    self.button = button

    -- Evaluate both enabled spells so each receives its cooldown-event snapshot.
    local judgementReady = addon.Cooldowns.IsReady(self.spells.judgement, cooldownEvent) == true
    local holyStrikeReady = false
    if addon.Config.Get("holyStrikeCheckEnabled") then
        holyStrikeReady = addon.Cooldowns.IsReady(self.spells.holyStrike, cooldownEvent) == true
    end

    local style = judgementReady and "judgement" or (holyStrikeReady and "holyStrike" or nil)
    if style and self.activeStyle ~= style then
        local nativeKey = style == "judgement" and "judgementNativeColor" or "glowNativeColor"
        local colorKey = style == "judgement" and "judgementGlowColor" or "glowColor"
        local color = not addon.Config.Get(nativeKey) and addon.Config.GetColor(colorKey) or nil
        addon.Glow.ConfigureOwner(self.owner, { color = color, priority = 0 })
    end

    self.activeStyle = style
    local ready = style ~= nil
    local combat = UnitAffectingCombat("player")
    local inCombat = addon.Client.Readable(combat) and combat == true
    local judgementContext = addon.Client.CanAttack("target") or addon.Client.CanAttack("mouseover")
    local showGlow = ready and (inCombat or (judgementReady and judgementContext))

    if button then
        addon.Glow.Set(button, self.owner, addon:IsVisible(button) and showGlow)
    end
end

function feature:Stop()
    addon.Glow.ClearOwner(self.owner)
    for _, id in pairs(self.spells) do
        addon.Cooldowns.Invalidate(id)
    end

    self.button = nil
    self.activeStyle = nil
end
