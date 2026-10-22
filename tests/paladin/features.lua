local H = dofile('tests/paladin/helpers.lua')
local passed = 0
local function test(name, run)
    run()
    passed = passed + 1
    print('PASS ' .. name)
end

test('Judgement outside combat requires a living attackable unit and readiness', function()
    local w = H.new({holyStrikeCheckEnabled = true})
    assert(w:glowing(w.holy), 'ready Judgement glows with an attackable target')

    w.dead = true
    w:fire('PLAYER_TARGET_CHANGED')
    assert(not w:glowing(w.holy))
    w.dead, w.attackable = false, false
    w:fire('PLAYER_TARGET_CHANGED')
    assert(not w:glowing(w.holy))
    w.exists = false
    w:fire('PLAYER_TARGET_CHANGED')
    assert(not w:glowing(w.holy))

    w.mouseover.exists, w.mouseover.attackable, w.mouseover.dead = true, true, false
    w:fire('UPDATE_MOUSEOVER_UNIT')
    assert(w:glowing(w.holy), 'living attackable mouseover also qualifies')
    w.cooldowns[2] = {startTime = w.time, duration = 10}
    w:fire('SPELL_UPDATE_COOLDOWN')
    assert(not w:glowing(w.holy), 'ready Holy Strike cannot light it outside combat')

    w.cooldowns[2] = {startTime = w.time, duration = 1.5}
    w.cooldowns[61304] = {startTime = w.time, duration = 1.5}
    w:fire('SPELL_UPDATE_COOLDOWN')
    assert(w:glowing(w.holy), 'GCD is still ignored')
    w.paladin.Config.Set('cooldownGlowEnabled', false)
    assert(not w:glowing(w.holy))
end)

test('Holy Strike defaults off with native color while Judgement remains enabled', function()
    local w = H.new()
    assert(w.paladin.Config.Get('cooldownGlowEnabled'))
    assert(not w.paladin.Config.Get('holyStrikeCheckEnabled'))
    assert(w.paladin.Config.Get('glowNativeColor'))

    w.combat = true
    w.cooldowns[2] = {startTime = w.time, duration = 10}
    w:fire('SPELL_UPDATE_COOLDOWN')
    assert(not w:glowing(w.holy))
    w.paladin.Config.Set('holyStrikeCheckEnabled', true)
    assert(w:glowing(w.holy))
    assert(w:color(w.holy) == nil, 'enabled Holy Strike uses native appearance')
end)

test('existing Judgement appearance preferences remain intact', function()
    local w = H.new({judgementNativeColor = true, judgementGlowColor = 'ffff0000'})
    assert(w.paladin.Config.Get('judgementNativeColor') == true)
    assert(w.paladin.Config.Get('judgementGlowColor') == 'ffff0000')
end)

test('Holy Strike and Judgement keep priority and GCD semantics', function()
    local w = H.new({holyStrikeCheckEnabled = true, glowNativeColor = false})
    w.exists = false
    w.paladin:Refresh()
    assert(not w:glowing(w.holy))

    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(w:glowing(w.holy))
    assert(w:color(w.holy)[1] == 0 and w:color(w.holy)[2] == 1 and w:color(w.holy)[3] == 0, 'Judgement defaults to green')
    w.cooldowns[2] = {startTime = 100, duration = 10}
    w:fire('SPELL_UPDATE_COOLDOWN')
    assert(w:glowing(w.holy))
    assert(w:color(w.holy)[2] == 191 / 255, 'Holy Strike keeps teal')

    w.cooldowns[1] = {startTime = 100, duration = 1.5}
    w.cooldowns[61304] = {startTime = 100, duration = 1.5}
    w:fire('SPELL_UPDATE_COOLDOWN')
    assert(w:glowing(w.holy), 'GCD does not suppress readiness')
    w.paladin.Config.Set('holyStrikeCheckEnabled', false)
    assert(not w:glowing(w.holy))
end)

test('seal casts reset the timer while disabled and Command damage cannot reset it', function()
    local w = H.new({sealGlowEnabled = false})
    w:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast', 9)
    w:tick(20)
    w.paladin.Config.Set('sealGlowEnabled', true)
    assert(not w:glowing(w.seal))
    w:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'proc', 20424)
    w:tick(6)
    assert(w:glowing(w.seal))
    w:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast', 9)
    assert(not w:glowing(w.seal))
end)

test('Exorcism target eligibility and desaturation coexist with utility layers', function()
    local w = H.new()
    w.creatureType = 3
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(w:glowing(w.exorcism))

    w.creatureType = 7
    w:fire('PLAYER_TARGET_CHANGED')
    assert(not w:glowing(w.exorcism))
    assert(w.exorcism.icon.desaturation == 1)
    local tint = w.root.modules.Utilities.IconTint
    tint.SetCooldown(w.exorcism, true)
    w.paladin.Config.Set('exorcismGlowEnabled', false)
    assert(w.exorcism.icon.desaturation == 1, 'cooldown layer survives Exorcism cleanup')
    tint.SetCooldown(w.exorcism, false)
    assert(w.exorcism.icon.desaturation == 0)

    w.paladin.Config.Set('exorcismGlowEnabled', true)
    w.exists = false
    w:fire('PLAYER_TARGET_CHANGED')
    assert(w.exorcism.icon.desaturation == 0, 'no target means no Exorcism grayscale')
end)

test('restricted creature type uses readable eligibility without requiring range', function()
    local w = H.new()
    w.creatureType = nil
    w.rangeResult = false
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(w:glowing(w.exorcism), 'out-of-range but eligible still glows')

    w.rangeResult = nil
    w:fire('PLAYER_TARGET_CHANGED')
    assert(not w:glowing(w.exorcism))
end)

test('Righteous Fury uses shield, aura recovery, cast grace and disabled observations', function()
    local w = H.new()
    local feature = w.paladin.RighteousFuryReminder
    assert(not feature.popup.active)
    w.shield = true
    w:fire('PLAYER_EQUIPMENT_CHANGED')
    assert(feature.popup.active)

    w:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast', 8)
    assert(not feature.popup.active)
    w:tick(1)
    assert(not feature.popup.active, 'grace protects a newly cast aura')
    w.aura = {expirationTime = w.time + 1800}
    w:tick(2)
    assert(not feature.popup.active)
    w.aura = {expirationTime = w.time + 299}
    w:fire('UNIT_AURA', 'player')
    assert(feature.popup.active)

    w.paladin.Config.Set('righteousFuryEnabled', false)
    w.auraRestricted = true
    w:fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast', 8)
    w.paladin.Config.Set('righteousFuryEnabled', true)
    w:tick(3)
    assert(not feature.popup.active)
    w:tick(1500)
    assert(feature.popup.active)
    w.shield = false
    w:fire('PLAYER_EQUIPMENT_CHANGED')
    assert(not feature.popup.active)
end)

test('gamepad selection moves effects and supports override visuals', function()
    local w = H.new()
    local native, override = w:button('PaladinGamepad', 4), w:button('PaladinOverride', 5)
    w.env.Enum.InputDeviceInterfaceType = {Gamepad = 1, Mkb = 0}
    w.env.C_InputInterfaceStyle = {GetCurrentStyle = function() return 1 end}
    w.env.GamepadMainActionBarFrame = {PageUnit = {
        GetCurrentPage = function() return 1 end,
        actionBars = {topBar = {actionButtons = {[5] = native}}},
    }}
    w.root.modules.Gamepad.Visuals = {GetEntries = function() return {{nativeButton = native, button = override}} end,
        GetFrames = function() return {override} end}
    w.paladin.Config.Set('holyStrikeGamepadPage', 1)
    w.paladin.Config.Set('holyStrikeGamepadButton', 5)
    w.paladin:PrepareButtons()
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(w:glowing(override))
    assert(not w:glowing(w.holy))
    assert(not w:glowing(native))

    w.env.C_InputInterfaceStyle.GetCurrentStyle = function() return 0 end
    w:tick(0.1)
    assert(w:glowing(w.holy))
    assert(not w:glowing(override))
end)

test('previews time out and stop on combat without clearing live owners', function()
    local w = H.new()
    w.exists = false
    w.paladin:Refresh()
    assert(w.paladin:Preview('holyStrike'))
    assert(w:glowing(w.holy))
    w:tick(3.1)
    assert(not w:glowing(w.holy))

    w.paladin.RighteousFuryReminder:SetPreview(true)
    assert(w.paladin.RighteousFuryReminder.popup.preview)
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(not w.paladin.RighteousFuryReminder.preview)
    assert(not w.paladin.RighteousFuryReminder.popup.preview)
    assert(w:glowing(w.holy))
end)
test('active destinations and previews refresh geometry after resizing', function()
    local w = H.new()
    local refreshed = {}
    local refresh = w.root.Glow.RefreshGeometry
    w.root.Glow.RefreshGeometry = function(button)
        refreshed[button] = true
        refresh(button)
    end
    assert(w.paladin:Preview('holyStrike'))
    w:tick(0.1)
    assert(refreshed[w.holy], 'preview geometry is refreshed')

    refreshed = {}
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    w.holy:SetSize(48, 48)
    w:tick(0.1)
    assert(refreshed[w.holy], 'active ability geometry is refreshed')
end)

test('Righteous Fury glow defaults on and toggles without hiding reminder or preview', function()
    local w = H.new()
    local feature = w.paladin.RighteousFuryReminder
    local frame = feature.popup.frame
    assert(w.paladin.Config.Get('righteousFuryGlowEnabled') == true)
    assert(w.paladin.Config.Get('sealGlowColor') == 'ff00ff00')

    w.shield = true
    w:fire('PLAYER_EQUIPMENT_CHANGED')
    assert(frame:IsShown() and w:glowing(frame))
    w.paladin.Config.Set('righteousFuryGlowEnabled', false)
    assert(frame:IsShown() and not w:glowing(frame))
    w.paladin.Config.Set('righteousFuryGlowEnabled', true)
    assert(frame:IsShown() and w:glowing(frame))

    w.shield = false
    w:fire('PLAYER_EQUIPMENT_CHANGED')
    assert(not frame:IsShown() and not w:glowing(frame))
    feature:SetPreview(true)
    assert(frame:IsShown() and w:glowing(frame), 'preview matches Hunter aspect glow')
    w.paladin.Config.Set('righteousFuryGlowEnabled', false)
    assert(frame:IsShown() and not w:glowing(frame))
    feature:SetPreview(false)
    assert(not frame:IsShown() and not w:glowing(frame))
end)

print('Paladin features: ' .. passed .. ' passed')
