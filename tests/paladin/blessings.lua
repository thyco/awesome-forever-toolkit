local H = dofile('tests/paladin/helpers.lua')
local passed = 0
local function test(name, run)
    run()
    passed = passed + 1
    print('PASS ' .. name)
end

local function setup(settings)
    local w = H.new(settings)
    assert(w.paladin.BlessingReminder, 'blessing reminder must exist')
    w.blessings = {}
    w.env.C_UnitAuras.GetPlayerAuraBySpellID = function(id) return w.blessings[id] end
    w:fire('UNIT_AURA', 'player')
    return w, w.paladin.BlessingReminder
end

test('Kings replaced by Freedom warns when Freedom expires', function()
    local w, feature = setup()
    local frame = feature.popup.frame
    assert(frame:IsShown() and w:glowing(frame))
    assert(frame:GetWidth() == 36 and feature.popup.texture.desaturation == 1)
    assert(w:color(frame)[1] == 1 and w:color(frame)[2] == 0 and w:color(frame)[3] == 0)

    w.blessings[20217] = {sourceUnit = 'player'}
    w:fire('UNIT_AURA', 'player')
    assert(not frame:IsShown())

    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    w.blessings[20217], w.blessings[1044] = nil, {sourceUnit = 'player'}
    w:fire('UNIT_AURA', 'player')
    assert(not frame:IsShown(), 'Freedom is still a blessing')

    w.blessings[1044] = nil
    w:fire('UNIT_AURA', 'player')
    assert(frame:IsShown() and w:glowing(frame), 'expiration is detected from buffs, not cast estimates')
end)

test('dispel causes a reminder and other Paladins Kings or Greater Kings suppress it', function()
    local w, feature = setup()
    w.blessings[20217] = {sourceUnit = 'party1'}
    w:fire('UNIT_AURA', 'player')
    assert(not feature.popup.frame:IsShown())

    w.blessings[20217] = nil
    w:fire('UNIT_AURA', 'player')
    assert(feature.popup.frame:IsShown())

    w.blessings[25898] = {sourceUnit = 'party2'}
    w:fire('UNIT_AURA', 'player')
    assert(not feature.popup.frame:IsShown(), 'a blessing need not be learned by this character')
end)

test('other blessings do not suppress the Kings reminder', function()
    local w, feature = setup()
    w.blessings[19740] = {sourceUnit = 'player'}
    w.blessings[19742] = {sourceUnit = 'party1'}

    w:fire('UNIT_AURA', 'player')

    assert(feature.popup.frame:IsShown(), 'Might and Wisdom are not Kings')
    assert(w:glowing(feature.popup.frame))
end)

test('reminder artwork uses Kings rather than Might', function()
    local w, feature = setup()
    w.env.C_Spell.GetSpellTexture = function(id)
        return id == 20217 and 135995 or 135906
    end

    feature:Refresh()

    assert(feature.popup.texture.texture == 135995)
end)

test('restricted combat state hides warnings and resumes when readable', function()
    local w, feature = setup()
    w.auraRestricted = true
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(not feature.popup.frame:IsShown() and feature.state == 'unknown')

    w.auraRestricted, w.combat = false, false
    w:fire('PLAYER_REGEN_ENABLED')
    assert(feature.popup.frame:IsShown() and feature.state == 'missing')
end)

test('glow-only mode hides artwork while preserving glow and draggable preview', function()
    local w, feature = setup({blessingHideIcon = true, blessingIconSize = 48, blessingIconX = 100, blessingIconY = -240})
    local popup = feature.popup
    assert(popup.texture.alpha == 0)
    assert(popup.frame:IsShown() and w:glowing(popup.frame))
    assert(popup.frame:GetWidth() == 48 and popup.x == 100 and popup.y == -240)

    w.blessings[20217] = {}
    w:fire('UNIT_AURA', 'player')
    feature:SetPreview(true)
    assert(popup.preview and w:glowing(popup.frame) and popup.texture.alpha == 0)

    w.paladin.Config.Set('blessingHideIcon', false)
    assert(popup.texture.alpha == 1)
    w.paladin:ClearPreviews()
    assert(not popup.preview and not popup.frame:IsShown())

    feature:SetPreview(true)
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(not popup.preview and not popup.frame:IsShown())
end)

test('disable clears live reminder and preview; invalid saved size resets', function()
    local w, feature = setup({blessingIconSize = 37})
    assert(feature.popup.frame:GetWidth() == 36)
    feature:SetPreview(true)

    w.paladin.Config.Set('blessingReminderEnabled', false)
    feature:SetPreview(true)
    assert(not feature.popup.frame:IsShown() and not feature.popup.preview)
    assert(not w:glowing(feature.popup.frame))

    w.paladin.Config.Set('blessingReminderEnabled', true)
    assert(feature.popup.frame:IsShown())
    w.paladin:Stop()
    assert(not feature.popup.frame:IsShown() and not w:glowing(feature.popup.frame))
end)

test('settings expose glow-only and diagnostic command reports detection', function()
    local w = setup()
    w.root.Window:Open()
    w.root.Window:ShowPage('paladin.reminders')
    w.root.Window.settings['paladin.blessingHideIcon']:SetValue(true)
    assert(w.paladin.Config.Get('blessingHideIcon'))

    local output = {}
    w.env.print = function(message) output[#output + 1] = message end
    w.env.SlashCmdList.AWESOMEFOREVERTOOLKIT('paladin buffs')
    local text = table.concat(output, '\n')
    assert(text:find('missing', 1, true))
    assert(text:find('freedom', 1, true), 'low-level transition can be diagnosed separately')
end)

print('Paladin blessings: ' .. passed .. ' passed')
