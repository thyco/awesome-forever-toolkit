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
    world.cvars = { groundEffectDensity = '64', graphicsGroundClutter = '5' }
    world.defaults = { groundEffectDensity = '32', graphicsGroundClutter = '4' }
    world.cvarWrites = {}
    world.locked = {}
    world.readOnly = {}
    world.rejected = {}
    world.timers = {}
    world.env.C_CVar = {
        GetCVarInfo = function(name)
            if world.cvars[name] == nil then
                return nil
            end

            return world.cvars[name], world.defaults[name], false, false,
                world.locked[name] or false, false, world.readOnly[name] or false
        end,
        SetCVar = function(name, value)
            if world.rejected[name] then
                return false
            end

            world.cvars[name] = tostring(value)
            world.cvarWrites[#world.cvarWrites + 1] = { name, tostring(value) }
            return true
        end,
    }
    world.env.C_Timer = { After = function(delay, callback)
        world.timers[#world.timers + 1] = { delay, callback }
    end }

    function world:runTimers()
        local pending = self.timers
        self.timers = {}

        for _, timer in ipairs(pending) do
            timer[2]()
        end
    end

    if configure then configure(world) end

    local manifest = assert(io.open('tests/utilities/manifest.txt'))
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

test('saved override applies across characters and reset removes it', function()
    local account = {}
    local _, addon = setup(function(world)
        world.env.AwesomeForeverToolkitDB.graphics = account
    end)
    addon.Graphics.Set('groundEffectDensity', 96)
    local overridden = setup(function(world)
        world.env.AwesomeForeverToolkitDB.graphics = account
    end)

    addon.Graphics.Reset('groundEffectDensity')
    local reset = setup(function(world)
        world.env.AwesomeForeverToolkitDB.graphics = account
        world.cvars.groundEffectDensity = '32'
    end)

    equal(overridden.cvars.groundEffectDensity, '96')
    equal(reset.cvars.groundEffectDensity, '32')
    equal(#reset.cvarWrites, 0)
    equal(account.groundEffectDensity, nil)
end)

test('ground clutter preset changes reapply only a manual density override', function()
    local world, addon = setup()
    addon.Graphics.Set('groundEffectDensity', 88)
    world.cvars.groundEffectDensity = '40'

    world:fire('CVAR_UPDATE', 'graphicsGroundClutter')
    world:runTimers()

    equal(world.cvars.groundEffectDensity, '88')
end)

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
