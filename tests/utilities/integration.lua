local H = dofile('tests/utilities/helpers.lua')
local equal = H.equal
local passed, failed = 0, 0

local function test(name, run)
    local ok, message = pcall(run)
    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(message))
    end
end

local function setup(configure)
    local world = H.new()
    world.main = world:button('ActionButton1', 1)
    world.side = world:button('MultiBarLeftButton7', 67)
    world.actions = { [1] = { 'spell', 10 }, [67] = { 'spell', 10 } }
    if configure then configure(world) end

    local manifest = io.open('tests/utilities/manifest.txt')
    assert(manifest, 'addon manifest is not implemented')
    for line in manifest:lines() do
        if line:match('%.lua$') and not line:match('^Libs/') then
            local chunk = assert(loadfile('AwesomeForeverToolkit/' .. line, 't', world.env))
            chunk('AwesomeForeverToolkit', world.root)
        end
    end
    manifest:close()
    world:fire('PLAYER_LOGIN')
    return world, world.addon
end

local function tinted(button)
    equal(button.icon.desaturation, 1, 'icon must be desaturated')
    equal(button.icon.color[1], 1, 'red component')
    equal(button.icon.color[2], 0.25, 'green component')
    equal(button.icon.color[3], 0.25, 'blue component')
end

local function native(button)
    equal(button.icon.desaturation, 0, 'icon saturation restored')
    equal(button.icon.color[1], 1)
    equal(button.icon.color[2], 1)
    equal(button.icon.color[3], 1)
end

test('login colors a shot on both main and side bars', function()
    local world = setup()

    tinted(world.main)
    tinted(world.side)
    equal(world.queries[10], 1, 'duplicate abilities share queries')
end)

test('all eight default bar prefixes participate', function()
    local prefixes = { 'ActionButton', 'MultiBarBottomLeftButton', 'MultiBarBottomRightButton',
        'MultiBarRightButton', 'MultiBarLeftButton', 'MultiBar5Button', 'MultiBar6Button', 'MultiBar7Button' }
    local world = setup(function(w)
        for index, prefix in ipairs(prefixes) do
            w:button(prefix .. '12', index + 100)
            w.actions[index + 100] = { 'spell', 10 }
        end
    end)

    for _, prefix in ipairs(prefixes) do tinted(world.env[prefix .. '12']) end
end)

test('custom bars are left untouched', function()
    local world = setup(function(w)
        w.custom = w:button('BT4Button1', 1)
    end)

    native(world.custom)
end)

test('gamepad ability bars and stance override share range checks', function()
    local world = setup(function(w)
        w.padButtons = {}
        for _, key in ipairs({ 'topBar', 'leftBar', 'rightBar', 'bottomBar', 'stanceBar' }) do
            local buttons = w:gamepadBar(key, { 201, 202, 203, 204, 205, 206, 207, 208 })
            for _, button in ipairs(buttons) do
                w.padButtons[#w.padButtons + 1] = button
                w.actions[button.action] = { 'spell', 10 }
            end
        end
    end)

    for _, button in ipairs(world.padButtons) do
        tinted(button)
    end
    equal(world.queries[10], 1, 'gamepad duplicates share the existing range sample')

    world.ranges[10] = true
    world:tick(0.1)

    for _, button in ipairs(world.padButtons) do
        native(button)
    end
end)

test('gamepad buttons follow their live paged action slot', function()
    local world = setup(function(w)
        w.pad = w:gamepadBar('topBar', { 201 })[1]
        w.actions[201] = { 'spell', 10 }
        w.actions[225] = { 'spell', 20 }
    end)
    tinted(world.pad)

    world.pad.action = 225
    world:tick(0.1)

    native(world.pad)
end)

test('gamepad buttons created after login are discovered by the fallback', function()
    local world = setup()
    local pad = world:gamepadBar('bottomBar', { 201 })[1]
    world.actions[201] = { 'spell', 10 }

    world:tick(0.5)

    tinted(pad)
end)

test('gamepad targeting controls and pet buttons are not player range buttons', function()
    local world, addon = setup(function(w)
        w.targetControl = w:gamepadBar('hostileTargetingBar', { 201 })[1]
        w.petControl = w:gamepadBar('possessBar', { 202 })[1]
        w.actions[201] = { 'spell', 10 }
        w.actions[202] = { 'spell', 10 }
    end)

    native(world.targetControl)
    native(world.petControl)
    equal(#addon.RangeCheck.buttons, 2)
end)

test('in-range target restores all tracked icons', function()
    local world = setup()
    world.ranges[10] = true

    world:tick(0.1)

    native(world.main)
    native(world.side)
end)

test('new target clears prior evidence immediately', function()
    local world = setup()
    world.exists = false

    world:fire('PLAYER_TARGET_CHANGED')

    native(world.main)
    native(world.side)
end)

test('paged main slot checks the current melee action', function()
    local world = setup()
    world.actions[13] = { 'spell', 40 }
    world.main.action = 13

    world:fire('ACTIONBAR_PAGE_CHANGED')
    world:tick(0.1)

    tinted(world.main)
    tinted(world.side)
end)

test('replacing spell in the same slot removes tint', function()
    local world = setup()
    world.actions[67] = { 'item', 10 }

    world:fire('ACTIONBAR_SLOT_CHANGED', 67)
    world:tick(0.1)

    native(world.side)
end)

test('macro follows the client-reported displayed spell', function()
    local world = setup(function(w)
        w.actions[67] = { 'macro', 10, 'spell' }
    end)
    tinted(world.side)
    world.actions[67] = { 'macro', 20, 'spell' }

    world:tick(0.1)

    native(world.side)
end)

test('unknown macro payload is not confused with a spell ID', function()
    local world = setup(function(w)
        w.actions[67] = { 'macro', 10 }
    end)

    native(world.side)
end)

test('restricted action identifiers clear previous tint', function()
    local world = setup()
    world.actions[67] = { 'spell', world.secret }

    world:tick(0.1)

    native(world.side)
end)

test('hidden button releases its tint', function()
    local world = setup()
    world.side:Hide()

    world:tick(0.1)

    native(world.side)
end)

test('native color updates retain red but restore the latest mana color', function()
    local world, addon = setup()
    world.side.icon:SetVertexColor(0.5, 0.5, 1, 0.8)
    tinted(world.side)

    addon.Config.Set('checkRangedAbilities', false)

    equal(world.side.icon.color[1], 0.5)
    equal(world.side.icon.color[2], 0.5)
    equal(world.side.icon.color[3], 1)
    equal(world.side.icon.color[4], 0.8)
    equal(world.side.icon.desaturation, 0)
end)

test('native desaturation refresh does not erase an active tint', function()
    local world = setup()

    world.side.icon:SetDesaturated(false)

    tinted(world.side)
end)

test('partial native desaturation is restored on disable', function()
    local world, addon = setup()
    world.side.icon:SetDesaturation(0.4)

    addon.Config.Set('checkRangedAbilities', false)

    equal(world.side.icon.desaturation, 0.4)
end)

test('unchanged range polls do not rewrite icon textures', function()
    local world = setup()
    local writes = world.side.icon.writes
    local bookReads = world.bookReads

    for _ = 1, 20 do world:tick(0.1) end

    equal(world.side.icon.writes, writes)
    equal(world.bookReads, bookReads, 'spellbook is not rescanned by polling')
end)

test('range diagnostics are collected only when requested', function()
    local world, addon = setup()

    equal(addon.Range.checks, nil)
    world:tick(0.1)
    equal(addon.Range.checks, nil)

    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT('utilities ')

    assert(addon.Range.checks[10])
    assert(table.concat(world.messages, '\n'):find('spellbook=', 1, true))
end)

test('range checks read each visible action once per refresh', function()
    local reads = {}
    local world = setup(function(w)
        w.env.AwesomeForeverToolkitCharacterDB.utilities = { greyOnCooldown = false }
        w.empty = w:button('ActionButton2', 2)
        w.env.GetActionInfo = function(slot)
            reads[slot] = (reads[slot] or 0) + 1

            local action = w.actions[slot]
            if action then
                return action[1], action[2], action[3]
            end
        end
    end)
    local mainReads, sideReads, emptyReads = reads[1], reads[67], reads[2]

    world:tick(0.1)

    equal(reads[1], mainReads + 1)
    equal(reads[67], sideReads + 1)
    equal(reads[2], emptyReads + 1)
    tinted(world.main)
    tinted(world.side)
end)

test('updates are throttled rather than running on every frame', function()
    local world = setup()
    local queries = world.queries[10]

    world:tick(0.02)
    world:tick(0.02)
    world:tick(0.02)

    equal(world.queries[10], queries)
    world:tick(0.05)
    equal(world.queries[10], queries + 1)
end)

test('disabled checkbox stops range polling', function()
    local world, addon = setup()
    addon.Config.Set('checkRangedAbilities', false)
    local queries = world.queries[10]

    for _ = 1, 100 do world:tick(0.1) end

    equal(world.queries[10], queries)
    native(world.side)
end)

test('invalid saved setting gets the enabled default', function()
    local world, addon = setup(function(w)
        w.env.AwesomeForeverToolkitCharacterDB.utilities = { checkRangedAbilities = 'false' }
    end)

    equal(addon.Config.Get('checkRangedAbilities'), true)
    tinted(world.side)
end)

test('all classes run range checks', function()
    for _, class in ipairs({ 'WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID' }) do
        local world, addon = setup(function(w) w.class = class end)

        world:tick(0.1)

        tinted(world.main)
        assert(addon.started)
    end
end)

test('late-created button waits for combat to end before preparing hooks', function()
    local world = setup()
    world.combat = true
    local late = world:button('MultiBar7Button8', 88)
    world.actions[88] = { 'spell', 10 }
    world:tick(0.5)
    native(late)
    world.combat = false

    world:fire('PLAYER_REGEN_ENABLED')

    tinted(late)
end)

test('prepared buttons continue updating in combat', function()
    local world = setup()
    world.combat = true
    world.ranges[10] = true
    world:tick(0.1)
    native(world.side)
    world.ranges[10] = false

    world:tick(0.1)

    tinted(world.side)
end)

test('newly learned spell is discovered', function()
    local world = setup(function(w) w.learned = { 20, 30 } end)
    native(world.side)
    world.learned = { 10, 20, 30 }

    world:fire('SPELLS_CHANGED')
    world:tick(0.1)

    tinted(world.side)
end)

test('attackable mouseover colors without a selected target', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
    end)

    tinted(world.side)
end)

test('selected target takes precedence without mixing mouseover evidence', function()
    local world = setup()
    world.ranges[10] = true
    world.mouseover = { exists = true, attackable = true, dead = false,
        ranges = { [10] = false, [20] = true, [40] = false } }

    world:fire('UPDATE_MOUSEOVER_UNIT')

    native(world.side)
end)

test('mouseover departure clears tint on the next poll when no target is selected', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
    end)
    tinted(world.side)
    world.mouseover.exists = false

    world:tick(0.1)

    native(world.side)
end)

test('friendly mouseover cannot color when no attackable target exists', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = false, dead = false,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('dead mouseover cannot color when no attackable target exists', function()
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = true,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('restricted mouseover attackability safely falls back to attackable target', function()
    local world = setup(function(w)
        w.mouseover = { exists = true, attackable = w.secret, dead = false, ranges = {} }
    end)

    tinted(world.side)
end)

test('spellbook and spell-ID fallback both check the mouseover unit', function()
    local calls = 0
    local world = setup(function(w)
        w.exists = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
        w.env.C_SpellBook.IsSpellBookItemInRange = function(slot, bank, unit)
            equal(unit, 'mouseover')
            calls = calls + 1
            return nil
        end
    end)

    tinted(world.side)
    assert(calls > 0)
    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT('utilities ')
    assert(table.concat(world.messages, '\n'):find('Checking: mouseover', 1, true))
end)

test('friendly selected target blocks mouseover fallback', function()
    local world = setup(function(w)
        w.attackable = false
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('dead selected target blocks mouseover fallback', function()
    local world = setup(function(w)
        w.dead = true
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true } }
    end)

    native(world.side)
    equal(next(world.queries), nil)
end)

test('selecting then clearing a target switches evidence immediately', function()
    local world = setup(function(w)
        w.exists = false
        w.ranges[10] = true
        w.mouseover = { exists = true, attackable = true, dead = false,
            ranges = { [10] = false, [20] = true, [40] = false } }
    end)
    tinted(world.side)
    world.exists = true

    world:fire('PLAYER_TARGET_CHANGED')

    native(world.side)
    world.exists = false
    world:fire('PLAYER_TARGET_CHANGED')
    tinted(world.side)
end)

test('all utility features disabled remove the polling handler', function()
    local world, addon = setup()

    addon.Config.Set('checkRangedAbilities', false)
    addon.Config.Set('checkMeleeAbilities', false)
    addon.Config.Set('highlightQueuedAttacks', false)
    addon.Config.Set('greyOnCooldown', false)

    for _, frame in ipairs(world.frames) do equal(frame.scripts.OnUpdate, nil) end
    native(world.main)
end)

test('unknown result clears active tint', function()
    local world = setup()
    world.ranges[10] = nil

    world:tick(0.1)

    native(world.main)
end)

test('restricted result clears active tint', function()
    local world = setup()
    world.ranges[10] = world.secret

    world:tick(0.1)

    native(world.main)
end)

test('far target tints without proximity inference', function()
    local world = setup(function(w)
        w.ranges = { [10] = false, [20] = false, [30] = false, [40] = false }
        w.env.CheckInteractDistance = function() error('must never infer proximity') end
    end)

    tinted(world.main)
    equal(world.queries[20], nil)
    equal(world.queries[40], nil)
end)

print(string.format('%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
