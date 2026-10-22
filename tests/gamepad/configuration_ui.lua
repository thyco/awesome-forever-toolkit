local H = dofile("tests/helpers.lua")

local function fixture()
    local world = H.new()
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    local gamepad = root.modules.Gamepad
    local state = {forms = {{spellID = 2457, name = "Battle Stance"}}, configs = {}, enabled = true}
    gamepad.Runtime.GetForms = function() return state.forms end
    gamepad.Runtime.GetConfig = function(face, stance)
        return gamepad.ActionModel.Profile(state.configs[face] or {mode = "native"}, stance)
    end
    gamepad.Runtime.Describe = function(config)
        if config.spellID then return {name = "Charge", iconID = 123} end
        if config.macroName then return {name = config.macroName, iconID = 456} end
    end
    gamepad.Runtime.IsEnabled = function() return state.enabled end
    gamepad.Runtime.IsActive = function() return state.active == true end
    gamepad.Runtime.RunCommand = function(command) state.enabled = command == "on" end
    gamepad.Runtime.Configure = function(face, mode, action, stance, inherit)
        if state.reject then return false, "Rejected" end
        local profile = gamepad.ActionModel.Copy(action or {})
        profile.mode = mode
        state.configs[face] = gamepad.ActionModel.WithProfile(state.configs[face] or {mode = "native"}, stance,
            not inherit and profile or nil)
        return true, "Saved"
    end
    world.env.GetCursorInfo = function() return table.unpack(state.cursor or {}) end
    world.env.ClearCursor = function() state.cursor = nil; state.cleared = true end
    world.env.C_Spell.GetSpellInfo = function(id) return id == 133 and {name = "Charge", iconID = 123} or nil end

    root.Window:Open()
    root.Window:ShowPage("gamepad.bindings")
    return world, root, gamepad, state, root.Window.controls
end

local function choose(dropdown, value)
    local choices = {}
    dropdown.menuGenerator(dropdown, {CreateRadio = function(_, _, selected, callback, candidate)
        choices[candidate] = callback
    end})
    assert(choices[value], "dropdown option missing")
    choices[value](value)
end

-- Empty buttons show their physical letter and native behavior, not a missing texture.
do
    local _, _, _, _, controls = fixture()
    local face = controls["gamepad.faces"].A

    assert(face.letter:IsShown())
    assert(not face.icon:IsShown())
    assert(face.caption.text == "Blizzard default")
    assert(controls["gamepad.editor"].name.text == "Drop a spell or macro here")
end

-- Selecting another controller button changes only the editor, never the assignment.
do
    local _, _, _, state, controls = fixture()

    controls["gamepad.faces"].B.button.scripts.OnClick()

    assert(controls["gamepad.editor"].title.text == "Button B")
    assert(next(state.configs) == nil)
end

-- Inheritance displays the resolved Base action and mode, and resetting restores both.
do
    local _, _, gamepad, state, controls = fixture()
    state.configs.A = {mode = "context", spellID = 133, stances = {[2457] = {mode = "native"}}}
    gamepad.RefreshConfiguration()
    choose(controls["gamepad.profile"], 2457)

    controls["gamepad.editor"].clear.scripts.OnClick()

    assert(state.configs.A.stances[2457] == nil)
    assert(controls["gamepad.editor"].origin.text == "Inherited from Base")
    assert(controls["gamepad.editor"].name.text == "Charge")
    assert(controls["gamepad.behavior"].selectedValue == "context")
    assert(controls["gamepad.faces"].A.icon.texture == 123)

    state.configs.A = {mode = "always", kind = "macro", macroName = "Attack"}
    gamepad.RefreshConfiguration()
    assert(controls["gamepad.editor"].name.text == "Attack")
    assert(controls["gamepad.behavior"].selectedValue == "always")
end

-- Inheriting an empty Base remains visibly native and never invents an assignment.
do
    local _, _, _, _, controls = fixture()

    choose(controls["gamepad.profile"], 2457)

    assert(controls["gamepad.editor"].origin.text == "Inherited from Base")
    assert(controls["gamepad.editor"].summary.text == "Blizzard default")
    assert(controls["gamepad.faces"].A.letter:IsShown())
end

-- Rejected behavior changes keep the saved choice selected.
do
    local _, _, gamepad, state, controls = fixture()
    state.configs.A = {mode = "context", spellID = 133}
    state.reject = true
    gamepad.RefreshConfiguration()

    choose(controls["gamepad.behavior"], "always")

    assert(state.configs.A.mode == "context")
    assert(controls["gamepad.behavior"].selectedValue == "context")
end

-- Direct drops select the destination and preserve stance inheritance elsewhere.
do
    local _, _, _, state, controls = fixture()
    state.cursor = {"spell", 7, "spell", 133}
    choose(controls["gamepad.profile"], 2457)

    controls["gamepad.faces"].X.button.scripts.OnReceiveDrag()

    assert(state.configs.X.stances[2457].spellID == 133)
    assert(state.configs.X.mode == "native")
    assert(controls["gamepad.editor"].title.text == "Button X")
    assert(state.cleared)
end

-- Combat disables mutation controls and rejected drops preserve the cursor.
do
    local world, _, gamepad, state, controls = fixture()
    world.combat = true
    state.cursor = {"spell", 7, "spell", 133}
    gamepad.RefreshConfiguration()

    controls["gamepad.faces"].A.button.scripts.OnReceiveDrag()

    assert(not state.cleared and state.configs.A == nil)
    assert(controls["gamepad.behavior"].enabled == false)
    assert(controls["gamepad.editor"].clear.enabled == false)
    assert(controls["gamepad.enabled"].enabled == false)
end

-- Saved activation stays checked while temporarily inactive and can be disabled.
do
    local _, _, gamepad, state, controls = fixture()
    gamepad.RefreshConfiguration()
    assert(controls["gamepad.enabled"]:GetChecked())
    assert(controls["gamepad.editor"].status.text == "Enabled, temporarily inactive")

    local enabled = controls["gamepad.enabled"]
    enabled:SetChecked(false)
    enabled.scripts.OnClick(enabled)

    assert(not state.enabled)
    assert(not enabled:GetChecked())
end
-- Choosing a behavior on an inherited form creates a local override without changing Base.
do
    local _, _, gamepad, state, controls = fixture()
    state.configs.A = {mode = "context", spellID = 133}
    gamepad.RefreshConfiguration()
    choose(controls["gamepad.profile"], 2457)

    choose(controls["gamepad.behavior"], "always")

    assert(state.configs.A.mode == "context")
    assert(state.configs.A.stances[2457].mode == "always")
    assert(controls["gamepad.editor"].origin.text == "Custom for this profile")
end

-- Clearing Base removes its assignment and restores the neutral empty state.
do
    local _, _, gamepad, state, controls = fixture()
    state.configs.A = {mode = "context", spellID = 133}
    gamepad.RefreshConfiguration()

    controls["gamepad.editor"].clear.scripts.OnClick()

    assert(state.configs.A.spellID == nil and state.configs.A.mode == "native")
    assert(controls["gamepad.faces"].A.letter:IsShown())
    assert(controls["gamepad.editor"].summary.text == "Blizzard default")
end

-- The large slot edits the selected face, and missing forms return the editor to Base.
do
    local _, _, gamepad, state, controls = fixture()
    controls["gamepad.faces"].Y.button.scripts.OnClick()
    choose(controls["gamepad.profile"], 2457)
    state.cursor = {"spell", 7, "spell", 133}

    controls["gamepad.editor"].slot.button.scripts.OnReceiveDrag()

    assert(state.configs.Y.stances[2457].spellID == 133)
    state.forms = {}
    gamepad.RefreshConfiguration()
    assert(controls["gamepad.profile"].selectedValue == 0)
    assert(controls["gamepad.editor"].origin.text == "Base assignment")
    assert(controls["gamepad.editor"].summary.text == "Blizzard default")
end
print("gamepad focused editor: PASS")
