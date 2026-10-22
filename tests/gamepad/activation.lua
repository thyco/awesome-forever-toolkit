local H = dofile("tests/gamepad/helpers.lua")
AwesomeForeverToolkitCharacterDB = {gamepad = {}}
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function loadRuntime()
    local addon, eventFrame = {}, nil
    local world = {frames = {}, time = 0}
    local function widget(name, parent)
        local f = {attrs = {}, name = name, parent = parent, children = {}, shown = true, visible = not parent or parent:IsVisible(), bindings = {}}
        if name then world.frames[name] = f end
        if parent then parent.children[#parent.children + 1] = f end
        local function update(self)
            local visible = self.shown and (not self.parent or self.parent:IsVisible())
            if visible ~= self.visible then
                self.visible = visible
                local body = self.attrs[visible and "_onshow" or "_onhide"]
                if body then assert(load(body, "visibility", "t", {self = self}))() end
            end
            for _, child in ipairs(self.children) do update(child) end
        end
        local methods = {
            IsVisible = function(self) return self.visible end,
            IsShown = function(self) return self.shown end,
            SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end,
            Show = function(self) self.shown = true; update(self) end,
            Hide = function(self) self.shown = false; update(self) end,
            ClearBindings = function(self) self.bindings = {} end,
            SetBindingClick = function(self, _, key, name) self.bindings[key] = name end,
            GetName = function(self) return self.name end,
            SetAttribute = function(self, key, value) self.attrs[key] = value end,
            GetAttribute = function(self, key) return self.attrs[key] end,
            GetFrameStrata = function() return 'MEDIUM' end,
            GetFrameLevel = function() return 1 end,
            CreateTexture = function() return widget() end,
            CreateMaskTexture = function() return widget() end,
            RegisterEvent = function(self, event) if event == 'PLAYER_LOGIN' then eventFrame = self end end,
            SetScript = function(self, event, fn) self[event] = fn end,
        }
        return setmetatable(f, {__index = function(_, key) return methods[key] or function() end end})
    end
    UIParent = widget("UIParent")
    CreateFrame = function(_, name, parent) return widget(name, parent) end
    InCombatLockdown = function() return false end
    UnitAffectingCombat = function() return false end
    GetTime = function() return world.time end
    SlashCmdList = {}
    C_Spell = {GetSpellInfo = function(id) return {name = 'Spell' .. id, iconID = 1} end}
    InputUtil = {IsGamepadUIEnabled = function() return true end}
    C_GamePad = {ButtonBindingToIndex = function() return 1 end}
    C_AddOns = {IsAddOnLoaded = function() return false end}
    SecureHandlerWrapScript = function() end
    RegisterAttributeDriver = function() end
    UnregisterAttributeDriver = function() end
    SetOverrideBindingClick = function() end
    ClearOverrideBindings = function(owner) owner:ClearBindings() end
    GetNumShapeshiftForms = function() return 0 end
    local bars = {}
    for _, name in ipairs({'topBar', 'leftBar', 'rightBar', 'bottomBar', 'friendlyTargetingBar', 'hostileTargetingBar', 'shortcutsBar', 'stanceBar', 'possessBar'}) do
        bars[name] = {Right = {}}
        for i = 1, 4 do
            local button = widget(name .. i)
            button.SpecialActionIcon = widget()
            bars[name].Right['ActionButton' .. i] = button
        end
    end
    GamepadMainActionBarFrame = widget("NativeGamepadUI", UIParent)
    GamepadMainActionBarFrame.PageUnit = {actionBars = bars}
    GamepadSharedUtility = {InputBindingManager = {IsOnlyCoreBindingSetActive = function() return false end}}
    for _, file in ipairs({'OverlayLogic', 'ActionModel', 'OverlayVisual', 'OverlayRuntime'}) do
        assert(H.loadfile('AwesomeForeverToolkit/Modules/Gamepad/' .. file .. '.lua'))('GAF', addon)
    end
    world.addon = addon
    world.event = function(event, ...) eventFrame.OnEvent(eventFrame, event, ...) end
    return addon.Runtime, function() eventFrame.OnEvent(eventFrame, 'PLAYER_LOGIN') end,
        function() world.time = world.time + 1; eventFrame.OnUpdate(eventFrame, 1) end, world
end

test('active assignments restore after reload', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime = loadRuntime()
    assert(runtime.Configure('A', 'always', 133))

    local reloaded, login = loadRuntime()
    login()

    assert(reloaded.IsActive('A'), 'saved active A should restore')
end)

test('explicit off remains off after reload', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime = loadRuntime()
    assert(runtime.Configure('A', 'always', 133))
    runtime.RunCommand('off')

    local reloaded, login = loadRuntime()
    login()

    assert(not reloaded.IsActive('A'))
end)

test('reload only restores active faces rather than all stored assignments', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {B = {mode = 'always', spellID = 133}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime = loadRuntime()
    assert(runtime.Configure('A', 'always', 133))

    local reloaded, login = loadRuntime()
    login()

    assert(reloaded.IsActive('A') and not reloaded.IsActive('B'))
end)

test('assignments without activation preferences stay disabled', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {A = {mode = 'always', spellID = 133}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = nil
    local runtime, login = loadRuntime()

    login()

    assert(not runtime.IsActive('A'))
end)

test('restoration waits until controller layout is ready', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {A = {mode = 'always', spellID = 133}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {A = true}
    local runtime, login, update = loadRuntime()
    InputUtil.IsGamepadUIEnabled = function() return false end
    login()
    assert(not runtime.IsActive('A'))
    InputUtil.IsGamepadUIEnabled = function() return true end

    update()

    assert(runtime.IsActive('A'))
end)

test('explicit off cancels pending restoration', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {A = {mode = 'always', spellID = 133}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {A = true}
    local runtime, login, update = loadRuntime()
    InputUtil.IsGamepadUIEnabled = function() return false end
    login()
    runtime.RunCommand('off')
    InputUtil.IsGamepadUIEnabled = function() return true end

    update()

    assert(not runtime.IsActive('A'))
end)

test('startup with incomplete native buttons preserves activation and retries', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {A = {mode = 'always', spellID = 133}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {A = true}
    local runtime, login, update = loadRuntime()
    local buttons = GamepadMainActionBarFrame.PageUnit.actionBars.leftBar.Right
    local saved = buttons.ActionButton4
    buttons.ActionButton4 = nil

    login()

    assert(AwesomeForeverToolkitCharacterDB.gamepad.enabled.A == true, 'startup failure must not erase user preference')
    assert(not runtime.IsActive('A'))
    buttons.ActionButton4 = saved
    update()
    assert(runtime.IsActive('A'))
end)

test('temporary refresh failure preserves preference and recovers on data event', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime, _, _, world = loadRuntime()
    assert(runtime.Configure('A', 'always', 133))
    local info = C_Spell.GetSpellInfo
    C_Spell.GetSpellInfo = function() return nil end

    world.event('UPDATE_MACROS')

    assert(AwesomeForeverToolkitCharacterDB.gamepad.enabled.A == true)
    assert(not runtime.IsActive('A'))
    C_Spell.GetSpellInfo = info
    world.event('UPDATE_MACROS')
    assert(runtime.IsActive('A'))
end)

test('blocked action suspends session without permanently disabling saved choice', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime, _, _, world = loadRuntime()
    assert(runtime.Configure('A', 'always', 133))

    world.event('ADDON_ACTION_BLOCKED', 'AwesomeForeverToolkit', 'TestAction')

    assert(not runtime.IsActive('A'))
    assert(AwesomeForeverToolkitCharacterDB.gamepad.enabled.A == true)
    world.event('UPDATE_MACROS')
    assert(not runtime.IsActive('A'), 'blocked session must not retry automatically')
end)

test('absent stance does not erase the saved activation of stance-only profile', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {A = {mode = 'native', stances = {[2457] = {mode = 'always', spellID = 133}}}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {A = true}
    local runtime, login, _, world = loadRuntime()

    login()

    assert(AwesomeForeverToolkitCharacterDB.gamepad.enabled.A == true)
    GetNumShapeshiftForms = function() return 1 end
    GetShapeshiftFormInfo = function() return 1, true, true, 2457 end
    world.event('UPDATE_SHAPESHIFT_FORMS')
    assert(runtime.IsActive('A'))
end)

local function capture(fn)
    local original, lines = print, {}
    print = function(line) lines[#lines + 1] = tostring(line) end
    local ok, err = pcall(fn)
    print = original
    assert(ok, err)
    return table.concat(lines, "\n")
end

local function unrelatedError(event)
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime, _, _, world = loadRuntime()
    assert(runtime.Configure('A', 'always', 133))

    local messages = capture(function() world.event(event, 'AnotherAddon', 'TestAction') end)

    assert(messages == '', 'unrelated addon errors must not be echoed in chat')
    assert(runtime.IsActive('A'), 'unrelated addon errors must not stop overrides')
    assert(runtime.Configure('B', 'always', 133), 'unrelated addon errors must not fault the session')
end

test('another addon blocked action leaves gamepad running silently', function()
    unrelatedError('ADDON_ACTION_BLOCKED')
end)

test('another addon forbidden action leaves gamepad running silently', function()
    unrelatedError('ADDON_ACTION_FORBIDDEN')
end)

test('our forbidden action reports and suspends the session', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime, _, _, world = loadRuntime()
    assert(runtime.Configure('A', 'always', 133))

    local messages = capture(function()
        world.event('ADDON_ACTION_FORBIDDEN', 'AwesomeForeverToolkit', 'TestAction')
    end)

    assert(messages:find('ADDON_ACTION_FORBIDDEN', 1, true))
    assert(not runtime.IsActive('A'))
    assert(runtime.IsEnabled('A'), 'saved activation must survive a session fault')
    assert(not runtime.Configure('B', 'always', 133))
end)

local function missingMacroRuntime()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {A = {mode = 'always', kind = 'macro', macroName = 'Attack'}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {A = true}
    GetNumMacros = function() return 0, 0 end
    GetMacroInfo = function() return nil end
    return loadRuntime()
end

test('startup macro data can arrive late without a false warning', function()
    local runtime, login, update, world = missingMacroRuntime()

    local messages = capture(function()
        login()
        world.event('SPELLS_CHANGED')
        update()
    end)

    assert(not messages:find('Macro is missing', 1, true), 'startup must wait for macro data')
    assert(not runtime.IsActive('A') and runtime.IsEnabled('A'))
    GetNumMacros = function() return 1, 0 end
    GetMacroInfo = function() return 'Attack', 20 end
    update()
    assert(runtime.IsActive('A'), 'retry must recover without requiring another macro event')
end)

test('truly missing startup macro is reported after bounded retries', function()
    local runtime, login, update = missingMacroRuntime()

    local messages = capture(function()
        login()
        for i = 1, 6 do update() end
    end)

    assert(messages:find('Macro is missing', 1, true), 'genuine errors must remain visible')
    assert(not runtime.IsActive('A') and runtime.IsEnabled('A'))
end)

test('explicit off cancels a pending startup macro retry', function()
    local runtime, login, update = missingMacroRuntime()
    capture(login)
    runtime.RunCommand('off')
    GetNumMacros = function() return 1, 0 end
    GetMacroInfo = function() return 'Attack', 20 end

    update()

    assert(not runtime.IsActive('A') and not runtime.IsEnabled('A'))
end)

test('basis macro and three stance macros recover together after startup', function()
    local runtime, login, update = missingMacroRuntime()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {X = {mode = 'always', kind = 'macro', macroName = 'Attack'}}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {A = true, B = true, X = true, Y = true}
    for _, face in ipairs({'A', 'B', 'Y'}) do
        AwesomeForeverToolkitCharacterDB.gamepad.bindings[face] = {mode = 'native', stances = {
            [2457] = {mode = 'context', kind = 'macro', macroName = face .. 'Stance'},
        }}
    end
    GetNumShapeshiftForms = function() return 1 end
    GetShapeshiftFormInfo = function() return 1, true, true, 2457 end

    local messages = capture(login)

    assert(not messages:find('Macro is missing', 1, true))
    GetNumMacros = function() return 4, 0 end
    GetMacroInfo = function(index) return ({'Attack', 'AStance', 'BStance', 'YStance'})[index], 20 end
    update()
    for _, face in ipairs({'A', 'B', 'X', 'Y'}) do
        assert(runtime.IsActive(face), face .. ' did not recover')
        assert(runtime.IsEnabled(face), face .. ' lost saved activation')
    end
end)

test('macro removed after startup still reports immediately', function()
    local runtime, login, update, world = missingMacroRuntime()
    GetNumMacros = function() return 1, 0 end
    GetMacroInfo = function() return 'Attack', 20 end
    capture(login)
    world.time = 10
    GetNumMacros = function() return 0, 0 end

    local messages = capture(function() world.event('UPDATE_MACROS') end)

    assert(messages:find('Macro is missing', 1, true))
    assert(not runtime.IsActive('A') and runtime.IsEnabled('A'))
end)

test('visual provider exposes current stance action without Utils and clears on off', function()
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = {}
    AwesomeForeverToolkitCharacterDB.gamepad.enabled = {}
    local runtime, login, update, world = loadRuntime()
    login()
    assert(runtime.Configure('A', 'always', 133))
    assert(#world.addon.Visuals.GetEntries() == 0)
    assert(#world.addon.Visuals.GetFrames() == 1, 'hidden overlays must be discoverable before combat')
    assert(runtime.Configure('A', 'always', 456, 2457))
    GetNumShapeshiftForms = function() return 1 end
    GetShapeshiftFormInfo = function() return 1, true, true, 2457 end
    world.event('UPDATE_SHAPESHIFT_FORMS')
    local unit = GamepadMainActionBarFrame.PageUnit
    unit.GetActiveBar = function() return unit.actionBars.topBar end
    GamepadSharedUtility.InputBindingManager.IsOnlyCoreBindingSetActive = function() return true end
    world.addon.OverlayVisual.Sync = function() return true end
    C_Spell.GetSpellCooldownDuration = function() return nil end
    local router = world.frames.AFTGamepadRouterA
    router:SetAttribute('gaf-state', 'override')

    update()

    local entries = world.addon.Visuals.GetEntries()
    assert(#entries == 1 and entries[1].spellID == 133)
    entries[1].spellID = 999
    assert(world.addon.Visuals.GetEntries()[1].spellID == 133, 'descriptors must not mutate config')
    router:SetAttribute('gaf-state', 'form2457')
    update()
    assert(world.addon.Visuals.GetEntries()[1].spellID == 456)
    runtime.RunCommand('off')
    assert(#world.addon.Visuals.GetEntries() == 0)
end)

print(passed .. ' passed, ' .. failed .. ' failed')
os.exit(failed == 0 and 0 or 1)
