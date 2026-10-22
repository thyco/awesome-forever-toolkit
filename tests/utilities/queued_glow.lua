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
    world.class = 'WARRIOR'
    world.spells[78] = { name = 'Heroic Strike', spellID = 78, minRange = 0, maxRange = 0 }
    world.spells[1715] = { name = 'Hamstring', spellID = 1715, minRange = 0, maxRange = 5 }
    world.learned = { 78, 1715 }
    world.exists = false
    world.actions[1] = { 'spell', 78 }
    world.main = world:button('ActionButton1', 1)
    world.main:SetChecked(false)
    world.env.AwesomeForeverToolkitCharacterDB.utilities = {
        checkRangedAbilities = false,
        checkMeleeAbilities = false,
        greyOnCooldown = false,
        greyUnusableActions = false,
        greyPetActions = false,
    }
    world.env.C_Spell.GetSpellSubtext = function() return '' end
    world.env.C_ActionBar = { GetActionText = function(slot) return world.actionNames and world.actionNames[slot] end }
    world.env.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120 } }
    world.env.GetNumMacros = function() return world.macros and 1 or 0, 0 end
    world.env.GetMacroInfo = function(index)
        local macro = world.macros and world.macros[index]
        if macro then return macro[1], 1, macro[2] end
    end
    world.env.SecureCmdOptionParse = function(args)
        equal(args, '[combat] Heroic Strike; Shoot Bow')
        return world.combat and 'Heroic Strike' or 'Shoot Bow'
    end

    world.glowStarts = 0
    local library = {}
    function library.PixelGlow_Start(frame, color, count, frequency, length, thickness, x, y, border, key)
        equal(count, 4)
        equal(border, true)
        world.glowStarts = world.glowStarts + 1
        world.glowStartColor = color and { color[1], color[2], color[3], color[4] } or nil
        if not frame['_PixelGlow' .. key] then
            local effect = world.env.CreateFrame('Frame', nil, frame)
            effect.textures = { effect:CreateTexture(), effect:CreateTexture() }
            frame['_PixelGlow' .. key] = effect
        end
        local applied = color or world.nativePixelColor or { 0.95, 0.95, 0.32, 1 }
        for _, texture in ipairs(frame['_PixelGlow' .. key].textures) do
            texture:SetVertexColor(applied[1], applied[2], applied[3], applied[4])
        end
    end
    world.env.LibStub = function(name)
        equal(name, 'LibCustomGlow-1.0')
        return library
    end
    world.env.ColorPickerFrame = {
        SetupColorPickerAndShow = function(self, info) self.info = info end,
        GetColorRGB = function(self) return self.r, self.g, self.b end,
    }

    if configure then configure(world) end

    local manifest = assert(io.open('tests/utilities/manifest.txt'))
    for line in manifest:lines() do
        if line:match('%.lua$') and not line:match('^Libs/') then
            assert(loadfile('AwesomeForeverToolkit/' .. line, 't', world.env))('AwesomeForeverToolkit', world.root)
        end
    end
    manifest:close()
    world:fire('PLAYER_LOGIN')

    return world, world.addon
end

local function visible(world)
    for _, child in ipairs(world.main.children) do
        local effect = child._PixelGlowAwesomeForeverToolkitQueued
        if effect then return effect:IsVisible() end
    end

    return false
end

local function effect(world)
    for _, child in ipairs(world.main.children) do
        if child._PixelGlowAwesomeForeverToolkitQueued then
            return child._PixelGlowAwesomeForeverToolkitQueued
        end
    end
end

test('queued direct Heroic Strike glows without a target', function()
    local world = setup()

    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)
end)

test('gamepad queued glow follows native checked state and live paging', function()
    local world = setup(function(w)
        w.main = w:gamepadBar('leftBar', { 201 })[1]
        w.actions[201] = { 'spell', 78 }
        w.actions[225] = { 'spell', 1715 }
    end)

    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)

    world.main:SetChecked(false)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)

    world.main:SetChecked(true)
    world.main.action = 225
    world:tick(0.5)

    equal(visible(world), false)
end)

test('clearing native checked state clears queued glow', function()
    local world = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    world.main:SetChecked(false)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('conditional macro glows only while combat branch is active', function()
    local world = setup(function(w)
        w.macros = { [1] = { 'Switch', '#showtooltip\n/cast [combat] Heroic Strike; Shoot Bow' } }
        w.actionNames = { [1] = 'Switch' }
        w.actions[1] = { 'macro', 78, 'spell' }
    end)
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)

    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(visible(world), false)
end)

test('checked ordinary spell does not glow', function()
    local world = setup(function(w) w.actions[1] = { 'spell', 1715 } end)

    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('gamepad combat macro glows only for its Heroic Strike branch', function()
    local world = setup(function(w)
        w.main = w:gamepadBar('bottomBar', { 201 })[1]
        w.macros = { [1] = { 'Switch', '#showtooltip\n/cast [combat] Heroic Strike; Shoot Bow' } }
        w.actionNames = { [201] = 'Switch' }
        w.actions[201] = { 'macro', 78, 'spell' }
    end)
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)

    world.combat = true
    world:fire('PLAYER_REGEN_DISABLED')
    world:tick(0.1)

    equal(visible(world), true)

    world.combat = false
    world:fire('PLAYER_REGEN_ENABLED')

    equal(visible(world), false)
end)

test('explicit mouseover macro can glow without a range target', function()
    local world = setup(function(w)
        w.macros = { [1] = { 'Mouseover Swing', '/cast [@mouseover] Heroic Strike' } }
        w.actionNames = { [1] = 'Mouseover Swing' }
        w.actions[1] = { 'macro', 78, 'spell' }
        w.env.SecureCmdOptionParse = function() return 'Heroic Strike', 'mouseover' end
    end)

    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)
end)

test('target change refreshes a target-conditional macro branch', function()
    local world = setup(function(w)
        w.exists = true
        w.macros = { [1] = { 'Target Swing', '/cast [harm] Heroic Strike; Shoot Bow' } }
        w.actionNames = { [1] = 'Target Swing' }
        w.actions[1] = { 'macro', 78, 'spell' }
        w.env.SecureCmdOptionParse = function()
            return w.exists and 'Heroic Strike' or 'Shoot Bow'
        end
    end)
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)

    world.exists = false
    world:fire('PLAYER_TARGET_CHANGED')

    equal(visible(world), false)
end)

test('spellbook change clears a no-longer-learned queued attack', function()
    local world = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), true)

    world.learned = { 1715 }
    world:fire('SPELLS_CHANGED')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('unknown checked state does not glow', function()
    local world = setup()
    world.main.GetChecked = function() return world.secret end

    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(visible(world), false)
end)

test('setting disables queued glow and is saved per character', function()
    local world, addon = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    addon.Config.Set('highlightQueuedAttacks', false)

    equal(visible(world), false)
    equal(world.env.AwesomeForeverToolkitCharacterDB.utilities.highlightQueuedAttacks, false)
end)

test('saved per-character color is used when the glow is prepared', function()
    local world = setup(function(w)
        w.env.AwesomeForeverToolkitCharacterDB.utilities.queuedGlowColor = 'ffcc4d1a'
    end)

    local texture = effect(world).textures[1]
    equal(texture.color[1], 204 / 255)
    equal(texture.color[2], 77 / 255)
    equal(texture.color[3], 26 / 255)
    equal(texture.color[4], 1)
    equal(world.glowStartColor, nil)
end)

test('changing color recolors an active glow without recreating the effect', function()
    local world, addon = setup()
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)
    local starts = world.glowStarts

    addon.Config.Set('queuedGlowColor', 'ffe6331a')

    local texture = effect(world).textures[1]
    equal(texture.color[1], 230 / 255)
    equal(texture.color[2], 51 / 255)
    equal(texture.color[3], 26 / 255)
    equal(texture.color[4], 1)
    equal(world.glowStarts, starts)
    equal(world.env.AwesomeForeverToolkitCharacterDB.utilities.queuedGlowColor, 'ffe6331a')
end)

test('invalid saved color resets to cyan default', function()
    local world, addon = setup(function(w)
        w.env.AwesomeForeverToolkitCharacterDB.utilities.queuedGlowColor = 'invalid'
    end)

    equal(addon.Config.Get('queuedGlowColor'), 'ff26d9ff')
    equal(effect(world).textures[1].color[1], 38 / 255)
end)

test('native glow color uses the library default without disabling the glow', function()
    local world, addon = setup(function(w)
        w.env.AwesomeForeverToolkitCharacterDB.utilities.queuedGlowNativeColor = true
    end)
    world.main:SetChecked(true)
    world:fire('ACTIONBAR_UPDATE_STATE')
    world:tick(0.1)

    equal(world.glowStartColor, nil)
    equal(visible(world), true)

    addon.Config.Set('queuedGlowNativeColor', false)
    equal(effect(world).textures[1].color[1], 38 / 255)

    addon.Config.Set('queuedGlowNativeColor', true)
    equal(effect(world).textures[1].color[1], 0.95)
    equal(visible(world), true)
end)

test('native glow restores the actual library default after a custom color', function()
    local world, addon = setup(function(w)
        w.nativePixelColor = { 0.4, 0.5, 0.6, 1 }
    end)

    addon.Config.Set('queuedGlowNativeColor', true)

    equal(effect(world).textures[1].color[1], 0.4)
    equal(effect(world).textures[1].color[2], 0.5)
    equal(effect(world).textures[1].color[3], 0.6)
end)

test('idle polls do not rescan queued button state', function()
    local reads = 0
    local world = setup(function(w)
        local getChecked = w.main.GetChecked
        w.main.GetChecked = function(button)
            reads = reads + 1
            return getChecked(button)
        end
    end)
    local initialReads = reads

    world:tick(0.1)
    world:tick(0.1)
    world:tick(0.1)

    equal(reads, initialReads)
end)

local function overrideProvider(world, entry)
    world.overlay = world:button('OverrideVisual', nil)
    world.entries = {entry}
    entry.button = world.overlay
    entry.nativeButton = world.main
    world.root.modules.Gamepad = {active = true, Visuals = {
        version = 1,
        GetFrames = function() return {world.overlay} end,
        GetEntries = function() return world.entries end,
    }}
    world.current = {}
    world.env.C_Spell.IsCurrentSpell = function(id) return world.current[id] or false end
    world.addon:Refresh(true, true)
    return {main = world.overlay}
end

test('override queued attack follows the override spell instead of native checked state', function()
    local world, addon = setup()
    local overlay = overrideProvider(world, {spellID = 78})
    world.current[78] = true

    world:tick(0.1)

    equal(visible(overlay), true)
    equal(visible(world), false)
    equal(addon.QueuedAttackGlow.active, 1)

    world.current[78] = false
    world:tick(0.1)

    equal(visible(overlay), false, 'swing consumption clears without waiting for an action-bar event')
end)

test('override macro body identifies queued strike even with a different tooltip spell', function()
    local world = setup(function(w)
        w.macros = {[1] = {'Swing', '#showtooltip Hamstring\n/cast [combat] Heroic Strike; Shoot Bow'}}
    end)
    local overlay = overrideProvider(world, {macroName = 'Swing'})
    world.env.GetMacroSpell = function() return 1715 end
    world.current[78] = true
    world.combat = true

    world:tick(0.1)

    equal(visible(overlay), true)

    world.combat = false
    world.env.GetMacroSpell = function() return 78 end
    world:tick(0.1)

    equal(visible(overlay), false, 'inactive macro branch beats tooltip fallback')
end)

test('override macro checks every applicable next-swing command', function()
    local world = setup(function(w)
        w.spells[845] = {name = 'Cleave', spellID = 845}
        w.learned[#w.learned + 1] = 845
        w.macros = {[1] = {'Two swings', '/cast Heroic Strike\n/cast Cleave'}}
    end)
    local overlay = overrideProvider(world, {macroName = 'Two swings'})
    world.current[845] = true

    world:tick(0.1)

    equal(visible(overlay), true, 'queued second command must not be masked by the first')

    world.current[845] = false
    world:tick(0.1)
    equal(visible(overlay), false)
end)

test('override state changes and removal release custom queued glow', function()
    local world, addon = setup()
    local overlay = overrideProvider(world, {spellID = 78})
    world.current[78] = true
    world:tick(0.1)
    equal(visible(overlay), true)

    world.current[78] = world.secret
    world:tick(0.1)
    equal(visible(overlay), false, 'restricted queue state must not be inspected')

    world.current[78] = true
    world:tick(0.1)
    world.entries = {}
    world:tick(0.1)
    equal(visible(overlay), false)

    world.entries = {{button = world.overlay, spellID = 78}}
    world:tick(0.1)
    addon.Config.Set('highlightQueuedAttacks', false)
    equal(visible(overlay), false)
end)

print(('Queued glow: %d passed, %d failed'):format(passed, failed))
if failed > 0 then os.exit(1) end
