local H = dofile("tests/gamepad/helpers.lua")
AwesomeForeverToolkitCharacterDB = {gamepad = {}}
local ns = {}
assert(H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/OverlayLogic.lua"))("GAF", ns)
assert(H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/ActionModel.lua"))("GAF", ns)
local source = H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/ConfigurationActions.lua")
if source then source("GamepadAssistForever", ns) end
local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function setup()
    assert(ns.ConfigurationActions, "configuration actions missing")
    local state = { saved = {}, clears = 0, locked = false }
    ns.Runtime = {
        IsLocked = function() return state.locked end,
        GetConfig = function(face, stanceID) return ns.ActionModel.Profile(state.saved[face] or { mode = "native" }, stanceID) end,
        Configure = function(face, mode, action, stanceID, inherit)
            if state.reject then return false, "Rejected" end
            local profile = ns.ActionModel.Copy(action or {})
            profile.mode = mode
            state.saved[face] = ns.ActionModel.WithProfile(state.saved[face] or {mode = "native"}, stanceID, not inherit and profile or nil)
            return true, "Saved"
        end,
    }
    GetCursorInfo = function() return table.unpack(state.cursor or {}) end
    ClearCursor = function() state.clears = state.clears + 1 end
    C_Spell = { GetSpellInfo = function(id)
        if id == 133 then return { name = "Fireball", iconID = 123 } end
    end }
    return ns.ConfigurationActions, state
end

test("spellbook drop uses spell ID rather than spellbook index", function()
    local actions, state = setup()
    state.cursor = { "spell", 7, "spell", 133 }

    assert(actions.Drop("A"))

    assert(state.saved.A.spellID == 133 and state.saved.A.mode == "context")
    assert(state.clears == 1)
end)

test("replacing spell keeps permanent mode", function()
    local actions, state = setup()
    state.saved.B = { mode = "always", spellID = 42 }
    state.cursor = { "spell", 7, "spell", 133 }

    assert(actions.Drop("B"))

    assert(state.saved.B.mode == "always" and state.saved.B.spellID == 133)
end)

test("item cursor is rejected without losing cursor or existing assignment", function()
    local actions, state = setup()
    state.saved.A = { mode = "always", spellID = 133 }
    state.cursor = { "item", 133 }

    assert(not actions.Drop("A"))

    assert(state.clears == 0 and state.saved.A.spellID == 133)
end)

test("combat prevents assignment and preserves cursor", function()
    local actions, state = setup()
    state.cursor = { "spell", 7, "spell", 133 }
    state.locked = true

    assert(not actions.Drop("A"))

    assert(not state.saved.A and state.clears == 0)
end)

test("failed activation preserves cursor", function()
    local actions, state = setup()
    state.cursor = { "spell", 7, "spell", 133 }
    state.reject = true

    assert(not actions.Drop("A"))

    assert(state.clears == 0 and not state.saved.A)
end)

test("changing mode preserves spell for later reuse", function()
    local actions, state = setup()
    state.saved.X = { mode = "always", spellID = 133 }

    assert(actions.SetMode("X", "native"))

    assert(state.saved.X.spellID == 133 and state.saved.X.mode == "native")
end)

test("empty override requires a spell", function()
    local actions, state = setup()

    assert(not actions.SetMode("Y", "always"))

    assert(not state.saved.Y)
end)

test("clear restores native and removes stored spell", function()
    local actions, state = setup()
    state.saved.A = { mode = "always", spellID = 133 }

    assert(actions.Clear("A"))

    assert(state.saved.A.mode == "native" and state.saved.A.spellID == nil)
end)

test("macro drop assigns selected stance without changing basis", function()
    local actions, state = setup()
    state.saved.A = { mode = "always", spellID = 133 }
    state.cursor = { "macro", 1 }
    GetNumMacros = function() return 1, 0 end
    GetMacroInfo = function() return "My macro", 123 end

    assert(actions.Drop("A", 2457))

    assert(state.saved.A.spellID == 133)
    assert(state.saved.A.stances[2457].macroName == "My macro")
    assert(state.saved.A.stances[2457].mode == "always")
    assert(state.clears == 1)
end)

test("clearing stance via UI restores basis rather than disabling button", function()
    local actions, state = setup()
    state.saved.A = { mode = "always", spellID = 133, stances = { [2457] = {mode = "native"} } }

    assert(actions.Clear("A", 2457))

    assert(not state.saved.A.stances[2457] and state.saved.A.spellID == 133)
end)

test("native stance selection preserves macro for later reuse", function()
    local actions, state = setup()
    state.saved.A = { mode = "native", stances = { [2457] = {mode = "always", kind = "macro", macroName = "My macro"} } }

    assert(actions.SetMode("A", "native", 2457))

    assert(state.saved.A.stances[2457].macroName == "My macro")
    assert(state.saved.A.stances[2457].mode == "native")
end)

local function runtimeFixture()
    local runtimeAddon = {}
    local locked = false
    AwesomeForeverToolkitCharacterDB.gamepad.bindings = { A = { mode = "always", spellID = 133 } }
    InCombatLockdown = function() return locked end
    UnitAffectingCombat = function() return false end
    SlashCmdList = {}
    GetTime = function() return 0 end
    CreateFrame = function() return {
        RegisterEvent = function() end,
        SetScript = function() end,
    } end
    C_Spell = { GetSpellInfo = function(id)
        if id == 133 then return { name = "Fireball", iconID = 123 } end
    end }

    assert(H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/OverlayLogic.lua"))("GAF", runtimeAddon)
    assert(H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/ActionModel.lua"))("GAF", runtimeAddon)
    assert(H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/OverlayRuntime.lua"))("GAF", runtimeAddon)
    return runtimeAddon.Runtime, function() locked = true end
end

test("runtime saves native mode while keeping assigned spell", function()
    local runtime = runtimeFixture()

    assert(runtime.Configure("A", "native", 133))

    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.mode == "native")
    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.spellID == 133)
end)

test("runtime refuses invalid spell without replacing saved configuration", function()
    local runtime = runtimeFixture()

    assert(not runtime.Configure("A", "context", 999))

    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.mode == "always")
    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.spellID == 133)
end)

test("runtime refuses native reset during combat", function()
    local runtime, enterCombat = runtimeFixture()
    enterCombat()

    assert(not runtime.Configure("A", "native", nil))

    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.mode == "always")
end)

test("configuration snapshot cannot mutate saved choices before apply", function()
    local runtime = runtimeFixture()
    local config = runtime.GetConfig("A")

    config.mode = "native"

    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.mode == "always")
end)

test("native chat command preserves spell just like native UI selection", function()
    local runtime = runtimeFixture()

    runtime.RunCommand("set A native")

    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.mode == "native")
    assert(AwesomeForeverToolkitCharacterDB.gamepad.bindings.A.spellID == 133)
end)

print(passed .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
