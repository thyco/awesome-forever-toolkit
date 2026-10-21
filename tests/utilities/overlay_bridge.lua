local H = dofile('tests/utilities/helpers.lua')
local equal = H.equal
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end

local function setup(withProvider)
    local w = H.new()
    w.overlay = w:button('TestOverlay', nil)
    w.entries = {{button = w.overlay, spellID = 10}}
    w.env.C_Spell.IsSpellUsable = function() return true, false end
    if withProvider then
        w.env.GamepadAssistForeverVisuals = {version = 1, GetEntries = function() return w.entries end}
    end

    local manifest = assert(io.open('tests/utilities/manifest.txt'))
    for line in manifest:lines() do
        if line:match('%.lua$') and not line:match('^Libs/') then
            assert(loadfile('AwesomeForeverToolkit/' .. line, 't', w.env))('AwesomeForeverToolkit', w.root)
        end
    end
    manifest:close()
    w:fire('PLAYER_LOGIN')
    return w, w.addon
end

test('utils works without gamepad provider', function()
    local w, addon = setup(false)

    w:tick(1)

    equal(addon.started, true)
    equal(w.overlay.icon.color[2], 1)
end)

test('visible overlay uses existing range colouring', function()
    local w = setup(true)

    equal(w.overlay.icon.color[2], 0.25)
    equal(w.overlay.icon.desaturation, 1)
end)

test('stance action changes update range and unusable tint', function()
    local w = setup(true)
    w.entries[1].spellID = 20
    w.env.C_Spell.IsSpellUsable = function() return false, false end

    w:tick(1)

    equal(w.overlay.icon.color[2], 1)
    equal(w.overlay.icon.desaturation, 1)
    w.env.C_Spell.IsSpellUsable = function() return true, false end
    w:tick(1)
    equal(w.overlay.icon.desaturation, 0)
end)

test('macro displayed spell follows changes without touching macro contents', function()
    local w = setup(true)
    w.entries[1] = {button = w.overlay, macroName = 'Attack'}
    w.env.GetMacroSpell = function(name) assert(name == 'Attack'); return 20 end

    w:tick(1)

    equal(w.overlay.icon.color[2], 1)
    w.env.GetMacroSpell = function() return 10 end
    w:tick(1)
    equal(w.overlay.icon.color[2], 0.25)
end)

test('missing macro spell clears previous colour', function()
    local w = setup(true)
    equal(w.overlay.icon.color[2], 0.25)
    w.entries[1] = {button = w.overlay, macroName = 'Unknown'}
    w.env.GetMacroSpell = function() return nil end

    w:tick(1)

    equal(w.overlay.icon.color[2], 1)
    equal(w.overlay.icon.desaturation, 0)
end)

test('provider removal restores previous appearance', function()
    local w = setup(true)
    equal(w.overlay.icon.color[2], 0.25)
    w.env.GamepadAssistForeverVisuals = nil

    w:tick(1)

    equal(w.overlay.icon.color[2], 1)
    equal(w.overlay.icon.desaturation, 0)
end)

test('settings disable overlay tint just like native tint', function()
    local w, addon = setup(true)

    addon.Config.Set('checkRangedAbilities', false)
    addon.Config.Set('checkMeleeAbilities', false)
    addon.Config.Set('greyOnCooldown', false)

    equal(w.overlay.icon.color[2], 1)
    equal(w.overlay.icon.desaturation, 0)
end)

test('overlay uses mouseover only when no target exists', function()
    local w = setup(true)
    w.ranges[10] = true
    w.mouseover = {exists = true, attackable = true, dead = false, ranges = {[10] = false}}

    w:tick(1)
    equal(w.overlay.icon.color[2], 1)
    w.exists = false
    w:tick(1)
    equal(w.overlay.icon.color[2], 0.25)
end)

test('hidden overlays release their tint', function()
    local w = setup(true)
    equal(w.overlay.icon.color[2], 0.25)
    w.overlay:Hide()

    w:tick(1)

    equal(w.overlay.icon.color[2], 1)
    equal(w.overlay.icon.desaturation, 0)
end)

test('provider appearing after login is discovered without a dependency', function()
    local w = setup(false)
    w.env.GamepadAssistForeverVisuals = {version = 1, GetEntries = function() return w.entries end}

    w:tick(1)

    equal(w.overlay.icon.color[2], 0.25)
end)

test('friendly selected target prevents hostile mouseover colouring', function()
    local w = setup(true)
    w.attackable = false
    w.mouseover = {exists = true, attackable = true, dead = false, ranges = {[10] = false}}

    w:tick(1)

    equal(w.overlay.icon.color[2], 1)
end)

test('a new overlay waits for combat end before installing icon hooks', function()
    local w = setup(false)
    w.combat = true
    w.env.GamepadAssistForeverVisuals = {version = 1, GetEntries = function() return w.entries end}

    w:tick(1)

    equal(w.overlay.icon.color[2], 1)
    w.combat = false
    w:fire('PLAYER_REGEN_ENABLED')
    equal(w.overlay.icon.color[2], 0.25)
end)

test('hidden context overlay is prepared before its first combat appearance', function()
    local w = setup(false)
    w.overlay:Hide()
    local visibleEntries = {}
    w.env.GamepadAssistForeverVisuals = {
        version = 1,
        GetFrames = function() return {w.overlay} end,
        GetEntries = function() return visibleEntries end,
    }
    w:tick(1)
    w.combat = true
    w.overlay:Show()
    visibleEntries = w.entries

    w:tick(1)

    equal(w.overlay.icon.color[2], 0.25)
end)

test('real spell cooldown greys overlay but GCD alone does not', function()
    local w = setup(true)
    w.entries[1].spellID = 20
    w.env.GetTime = function() return 12 end
    w.env.C_Spell.GetSpellCooldown = function()
        return {startTime = 10, duration = 8, isEnabled = true, isOnGCD = false}
    end

    w:tick(1)

    equal(w.overlay.icon.desaturation, 1)
    w.env.C_Spell.GetSpellCooldown = function()
        return {startTime = 11, duration = 1.5, isEnabled = true, isOnGCD = true}
    end
    w:tick(1)
    equal(w.overlay.icon.desaturation, 0)
end)

print(passed .. ' passed, ' .. failed .. ' failed')
os.exit(failed == 0 and 0 or 1)
