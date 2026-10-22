local H = dofile("tests/gamepad/helpers.lua")
AwesomeForeverToolkitCharacterDB = {gamepad = {}}
local ns = {}
local source = H.loadfile("AwesomeForeverToolkit/Modules/Gamepad/OverlayLogic.lua")
if source then source("GamepadAssistForever", ns) end
local count, failures = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        count = count + 1
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function logic()
    assert(ns.Overlay, "overlay implementation missing")
    return ns.Overlay
end

test("context uses target first and mouseover only without a selected target", function()
    local rule = logic().BuildDriver("context")

    assert(rule == "[combat][@target,harm,nodead] override; [@target,exists] native; [@mouseover,harm,nodead] override; native")
end)

test("always override does not require a target or combat", function()
    assert(logic().BuildDriver("always") == "override")
end)

test("native mode never activates the replacement action", function()
    assert(logic().BuildDriver("native") == "native")
    assert(logic().BuildDriver("invalid") == nil)
end)

test("spell macro prefers selected target and has no explicit soft target", function()
    local macro = logic().BuildMacro("Charge")

    assert(macro == "/cast [@target,exists][@mouseover,harm,nodead][] Charge")
end)

test("invalid spell text cannot add macro commands or conditions", function()
    assert(not logic().BuildMacro("Charge\n/run evil()"))
    assert(not logic().BuildMacro("Charge;Other"))
    assert(not logic().BuildMacro(string.rep("x", 260)))
end)

local function fixture()
    local config = logic()
    local bars = {}
    local anchors = {}
    for _, name in ipairs({ "bare", "lt", "rt", "ltrt", "lb", "rb", "lbrb", "stance", "possess" }) do
        anchors[name] = {}
        local bar = { shown = name == "bare" }
        function bar:IsShown() return self.shown end
        function bar:GetParent() return anchors[name] end
        bars[name] = bar
    end

    local control = { attrs = {
        ["gaf-state"] = "override", ["gaf-text-override"] = "SPELL",
        ["gaf-lt"] = 1, ["gaf-rt"] = 2, ["gaf-lb"] = 3, ["gaf-rb"] = 4,
    } }
    function control:GetAttribute(key) return self.attrs[key] end
    function control:SetAttribute(key, value) self.attrs[key] = value end
    function control:GetFrameRef(key) return bars[key] end
    function control:SetID(id) self.id = id end
    function control:IsVisible() return self.visible ~= false end
    for name in pairs(bars) do control.attrs["gaf-native-" .. name] = name end

    local held = {}
    local environment = { self = control, down = true,
        GetGamePadState = function() return {buttons = held} end }
    local run = assert(load(config.ROUTER, "router", "t", environment))
    return control, held, bars, anchors, environment, run
end

test("bare press uses replacement action", function()
    local c, _, _, _, _, run = fixture()

    run()

    assert(c.attrs.macrotext1 == "SPELL")
end)

test("native condition retains the original A function", function()
    local c, _, _, _, _, run = fixture()
    c.attrs["gaf-state"] = "native"

    run()

    assert(c.attrs.macrotext1 == "bare")
end)

test("left trigger takes priority over override", function()
    local c, held, _, _, _, run = fixture()
    held[1] = true

    run()

    assert(c.attrs.macrotext1 == "lt")
end)

test("right trigger takes priority over override", function()
    local c, held, _, _, _, run = fixture()
    held[2] = true

    run()

    assert(c.attrs.macrotext1 == "rt")
end)

test("both triggers preserve combined native layer", function()
    local c, held, _, _, _, run = fixture()
    held[1], held[2] = true, true

    run()

    assert(c.attrs.macrotext1 == "ltrt")
end)

test("shoulder takes priority over trigger", function()
    local c, held, _, _, _, run = fixture()
    held[1], held[3] = true, true

    run()

    assert(c.attrs.macrotext1 == "lb")
end)

test("right shoulder uses native targeting layer", function()
    local c, held, _, _, _, run = fixture()
    held[4] = true

    run()

    assert(c.attrs.macrotext1 == "rb")
end)

test("both shoulders preserve native shortcuts", function()
    local c, held, _, _, _, run = fixture()
    held[3], held[4] = true, true

    run()

    assert(c.attrs.macrotext1 == "lbrb")
end)

test("stance replacing bare bar takes priority over spell override", function()
    local c, _, bars, anchors, _, run = fixture()
    bars.stance.shown = true
    anchors.stance = anchors.bare

    run()

    assert(c.attrs.macrotext1 == "stance")
end)

test("stance on a different layer does not steal bare A", function()
    local c, _, bars, anchors, _, run = fixture()
    bars.stance.shown = true
    anchors.stance = anchors.lt

    run()

    assert(c.attrs.macrotext1 == "SPELL")
end)

test("possess replacing bare bar takes priority over spell and stance", function()
    local c, _, bars, anchors, _, run = fixture()
    bars.possess.shown = true
    bars.stance.shown = true
    anchors.possess = anchors.bare
    anchors.stance = anchors.bare

    run()

    assert(c.attrs.macrotext1 == "possess")
end)

test("release retains the action selected on button down", function()
    local c, held, _, _, env, run = fixture()
    run()
    held[3] = true
    env.down = false

    run()

    assert(c.attrs.macrotext1 == "SPELL")
end)

test("stance profile chooses configured macro by name", function()
    local c, _, _, _, _, run = fixture()
    c.attrs["gaf-state"] = "form2457"
    c.attrs["gaf-macro-form2457"] = "My attack"

    run()

    assert(c.attrs.macro1 == "My attack" and c.attrs.macrotext1 == nil)
end)

test("switching from macro stance to basis spell clears old macro", function()
    local c, _, _, _, _, run = fixture()
    c.attrs["gaf-state"] = "form2457"
    c.attrs["gaf-macro-form2457"] = "My attack"
    run()
    c.attrs["gaf-state"] = "override"

    run()

    assert(c.attrs.macro1 == nil and c.attrs.macrotext1 == "SPELL")
end)

test("modifier after macro press clears macro and restores native layer", function()
    local c, held, _, _, _, run = fixture()
    c.attrs["gaf-macro-override"] = "My attack"
    c.attrs["gaf-text-override"] = nil
    run()
    held[1] = true

    run()

    assert(c.attrs.macro1 == nil and c.attrs.macrotext1 == "lt")
end)

test("stance change on release retains pressed macro", function()
    local c, _, _, _, env, run = fixture()
    c.attrs["gaf-state"] = "form2457"
    c.attrs["gaf-macro-form2457"] = "My attack"
    run()
    c.attrs["gaf-state"] = "override"
    env.down = false

    run()

    assert(c.attrs.macro1 == "My attack" and c.attrs.macrotext1 == nil)
end)

local function nativeAction(bars)
    local button = {id = 401, page = 1}
    function button:GetID() return self.id end
    function button:GetAttribute(key)
        if key == "type" then return self.kind or "action" end
        if key == "actionpage" then return self.page end
    end
    bars["button-lt"] = button
    return button
end

test("LT native action executes directly without nesting a macro click", function()
    local c, held, bars, _, _, run = fixture()
    nativeAction(bars)
    held[1] = true

    run()

    assert(c.attrs.type1 == "action" and c.id == 401)
    assert(c.attrs.macrotext1 == nil and c.attrs.macro1 == nil)
    assert(c.attrs.actionpage == 1)
end)

test("native action routing reads current storage ID on each press", function()
    local c, held, bars, _, _, run = fixture()
    local button = nativeAction(bars)
    held[1] = true
    run()
    button.id = 433
    button.page = 2

    run()

    assert(c.id == 433 and c.attrs.actionpage == 2)
end)

test("returning to bare override clears direct action slot", function()
    local c, held, bars, _, _, run = fixture()
    nativeAction(bars)
    held[1] = true
    run()
    held[1] = false

    run()

    assert(c.id == 0 and c.attrs.actionpage == nil)
    assert(c.attrs.type1 == "macro" and c.attrs.macrotext1 == "SPELL")
end)

test("direct action stays selected through release", function()
    local c, held, bars, _, env, run = fixture()
    local button = nativeAction(bars)
    held[1] = true
    run()
    button.id = 433
    env.down = false
    held[1] = false

    run()

    assert(c.attrs.type1 == "action" and c.id == 401)
end)

test("RT uses the direct native action path too", function()
    local c, held, bars, _, _, run = fixture()
    bars["button-rt"] = nativeAction(bars)
    held[2] = true

    run()

    assert(c.attrs.type1 == "action" and c.id == 401)
end)

test("native stance layer uses its own current slot instead of LT slot", function()
    local c, held, bars, anchors, _, run = fixture()
    nativeAction(bars)
    local stance = {GetID = function() return 501 end, GetAttribute = function(_, key)
        if key == "type" then return "action" end
    end}
    bars["button-stance"] = stance
    bars.stance.shown = true
    anchors.stance = anchors.lt
    held[1] = true

    run()

    assert(c.attrs.type1 == "action" and c.id == 501)
end)

test("flyout retains native click handling", function()
    local c, held, bars, _, _, run = fixture()
    local button = nativeAction(bars)
    button.kind = "flyout"
    held[1] = true

    run()

    assert(c.attrs.type1 == "macro" and c.attrs.macrotext1 == "lt" and c.id == 0)
end)

print(count .. " passed, " .. failures .. " failed")
os.exit(failures == 0 and 0 or 1)
