local H = dofile("tests/gamepad/helpers.lua")
AwesomeForeverToolkitCharacterDB = {gamepad = {}}
local addon = {}
assert(H.loadfile('AwesomeForeverToolkit/Modules/Gamepad/OverlayLogic.lua'))('GAF', addon)
local source = H.loadfile('AwesomeForeverToolkit/Modules/Gamepad/ActionModel.lua')
if source then source('GAF', addon) end
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function model()
    assert(addon.ActionModel, 'action model missing')
    C_Spell = { GetSpellInfo = function(id) if id == 133 then return { name = 'Fireball', iconID = 10 } end end }
    GetNumMacros = function() return 2, 0 end
    GetMacroInfo = function(id)
        if id == 1 then return 'Attack', 20, '/startattack\n/cast Fireball' end
        if id == 2 then return 'Other', 30, '/say hello' end
    end
    return addon.ActionModel
end

test('macro cursor stores identity rather than volatile index', function()
    local m = model()

    local action = assert(m.FromCursor('macro', 1))

    assert(action.kind == 'macro' and action.macroName == 'Attack')
end)

test('macro resolves as native macro reference without rewriting its body', function()
    local m = model()

    local action = assert(m.Resolve({kind = 'macro', macroName = 'Attack'}))

    assert(action.macroName == 'Attack' and action.macrotext == nil)
end)

test('duplicate macro names are rejected rather than executing an arbitrary macro', function()
    local m = model()
    GetMacroInfo = function() return 'Attack', 20, '/cast Fireball' end

    assert(not m.Resolve({kind = 'macro', macroName = 'Attack'}))
end)

test('missing renamed macro does not become a different slot', function()
    local m = model()

    assert(not m.Resolve({kind = 'macro', macroName = 'Deleted'}))
end)

test('legacy saved spell remains supported', function()
    local m = model()

    local action = assert(m.Resolve({spellID = 133, mode = 'always'}))

    assert(action.spellID == 133 and action.macrotext:find('Fireball', 1, true))
end)

test('stance assignment leaves basis intact and other stances inherit', function()
    local m = model()
    local base = {mode = 'always', spellID = 133}

    local updated = m.WithProfile(base, 2457, {mode = 'context', kind = 'macro', macroName = 'Attack'})

    assert(updated.spellID == 133 and not base.stances)
    assert(m.Profile(updated, 2457).macroName == 'Attack')
    assert(m.Profile(updated, 71).spellID == 133)
end)

test('clearing stance override restores inheritance', function()
    local m = model()
    local base = {mode = 'always', spellID = 133, stances = {[2457] = {mode = 'native'}}}

    local updated = m.WithProfile(base, 2457, nil)

    assert(m.Profile(updated, 2457).spellID == 133)
    assert(base.stances[2457].mode == 'native')
end)

test('stance driver guards context by form and prevents fallback to basis within explicit native stance', function()
    local m = model()
    local config = {mode = 'always', stances = {
        [2457] = {mode = 'context', spellID = 133}, [71] = {mode = 'native'},
    }}

    local driver = m.Driver(config, {{index = 1, spellID = 2457}, {index = 2, spellID = 71}})

    assert(driver:find('[form:1,combat]', 1, true))
    assert(driver:find('[@mouseover,form:1,harm,nodead]', 1, true))
    assert(not driver:find('softenemy', 1, true))
    assert(driver:find('[@target,form:1,exists] native; [@mouseover,form:1,harm,nodead]', 1, true))
    assert(driver:find('form2457; [form:1] native;', 1, true))
    assert(driver:find('[form:2] native;', 1, true))
    assert(driver:sub(-8) == 'override')
end)

print(passed .. ' passed, ' .. failed .. ' failed')
os.exit(failed == 0 and 0 or 1)
