local _, root = ...
local addon = root.modules.Paladin
local W = root.Widgets
local function available() return addon.active == true end
local className = select(2, UnitClass('player')) == 'PALADIN' and UnitClass('player') or 'Paladin'

local function preview(layout, kind)
    layout:Button(kind .. 'Preview', 'Preview glow (3s)', function()
        local ok, reason = addon:Preview(kind)
        if not ok then print('Awesome Forever Toolkit: ' .. reason) end
    end)
end

root.Window:RegisterPage({
    id = 'paladin.abilities', label = 'Ability glows', parent = className, available = available,
    build = function(parent, context)
        local layout = W.Layout(parent, context, 'paladin', addon.Config)
        layout:Heading('Holy Strike / Judgement')
        layout:Text('Judgement also glows outside combat with a living attackable target/mouseover. Optional Holy Strike is combat-only. Ignores mana and range; Judgement color takes priority.')
        layout:Field('Checkbox', 'cooldownGlowEnabled', 'Enable Holy Strike / Judgement glow')
        layout:Field('Checkbox', 'holyStrikeCheckEnabled', 'Also check Holy Strike')
        root.DisplayLocation.Create(layout, addon.Config, 'holyStrike', 'ChoiceDropdown')
        layout:Field('Checkbox', 'glowNativeColor', 'Holy Strike: use Blizzard native glow')
        layout:Field('Color', 'glowColor', 'Holy Strike custom color')
        layout:Field('Checkbox', 'judgementNativeColor', 'Judgement: use Blizzard native glow')
        layout:Field('Color', 'judgementGlowColor', 'Judgement custom color')
        preview(layout, 'holyStrike')

        layout:Heading('Exorcism')
        layout:Text('Glows in combat when ready against a living attackable Demon or Undead target/mouseover. Grays the icon when an attackable unit exists but the spell is cooling down or the target is ineligible.')
        layout:Field('Checkbox', 'exorcismGlowEnabled', 'Enable Exorcism assistance')
        root.DisplayLocation.Create(layout, addon.Config, 'exorcism', 'ChoiceDropdown')
        layout:Field('Checkbox', 'exorcismNativeColor', 'Use Blizzard native glow')
        layout:Field('Color', 'exorcismGlowColor', 'Custom glow color')
        preview(layout, 'exorcism')
        layout:Finish()
    end,
})

root.Window:RegisterPage({
    id = 'paladin.reminders', label = 'Paladin reminders', parent = className, available = available,
    build = function(parent, context)
        local layout = W.Layout(parent, context, 'paladin', addon.Config)
        layout:Heading('Seal refresh')
        layout:Text('Estimates seal duration from successful casts. Shows in combat or with a living attackable target/mouseover. After reload, a refresh is due until a seal cast is observed.')
        layout:Field('Checkbox', 'sealGlowEnabled', 'Enable seal reminder')
        layout:Field('ChoiceDropdown', 'sealReminderSeconds', 'Remind after (seconds)', W.Options(1, 30, 1))
        root.DisplayLocation.Create(layout, addon.Config, 'seal', 'ChoiceDropdown')
        layout:Field('Color', 'sealGlowColor', 'Seal glow color')
        preview(layout, 'seal')

        layout:Heading('Righteous Fury')
        layout:Text('With a shield equipped, shows when missing or at most five minutes remain. Uses readable aura timing with a cast-timer fallback.')
        layout:Field('Checkbox', 'righteousFuryEnabled', 'Enable Righteous Fury reminder')
        layout:Field('ChoiceDropdown', 'righteousFuryPopupSize', 'Icon size (px)', W.Options(32, 128, 8))
        layout:Button('righteousFuryPreview', 'Move / preview Righteous Fury icon', function()
            addon.RighteousFuryReminder:SetPreview(true)
        end)
        layout:Finish()
    end,
})
