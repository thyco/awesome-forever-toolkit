local _, addon = ...
local Buttons = {}
addon.Buttons = Buttons

local prefixes = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}
local gamepadBarKeys = { "topBar", "leftBar", "rightBar", "bottomBar" }
local gamepadBarLabels = { "Top set", "Left set", "Right set", "Bottom set" }
local gamepadPositionLabels = {
    "D-pad left", "D-pad up", "D-pad right", "D-pad down",
    "Face left", "Face top", "Face right", "Face bottom",
}

local function field(object, key)
    if not addon.Client.Readable(object) or type(object) ~= "table" then return nil end

    local ok, value = pcall(function() return object[key] end)
    if ok and addon.Client.Readable(value) then return value end
end

local function read(api, ...)
    if type(api) ~= "function" then return nil end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then return value end
end

local function integer(value, minimum, maximum)
    local number = addon.Client.Number(value)
    return number and number >= minimum and number <= maximum and number == math.floor(number)
end

local function gamepadPageUnit()
    return field(field(_G, "GamepadMainActionBarFrame"), "PageUnit")
end

function Buttons.Mode()
    local api = C_InputInterfaceStyle
    if not addon.Client.Readable(api) then return "unknown" end
    if api == nil then return "keyboard" end

    local style = read(field(api, "GetCurrentStyle"))
    local types = field(field(_G, "Enum"), "InputDeviceInterfaceType")
    local gamepad, keyboard = field(types, "Gamepad"), field(types, "Mkb")
    if addon.Client.Number(style) and addon.Client.Number(gamepad) and style == gamepad then
        return "gamepad"
    end
    if addon.Client.Number(style) and addon.Client.Number(keyboard) and style == keyboard then
        return "keyboard"
    end

    return "unknown"
end

function Buttons.GamepadBars()
    local labels = {}
    for index, label in ipairs(gamepadBarLabels) do labels[index] = label end

    return labels
end

function Buttons.GamepadPositions()
    local labels = {}
    for index, label in ipairs(gamepadPositionLabels) do labels[index] = label end

    return labels
end

function Buttons.GamepadCandidates(bar, index)
    if not integer(bar, 1, 4) or not integer(index, 1, 8) then return {} end

    local bars = field(gamepadPageUnit(), "actionBars")
    local result = {}
    for _, key in ipairs({ gamepadBarKeys[bar], "stanceBar" }) do
        local button = field(field(field(bars, key), "actionButtons"), index)
        if button then result[#result + 1] = button end
    end

    return result
end

function Buttons.GamepadSelected(page, bar, index)
    if not integer(page, 1, 3) or not integer(bar, 1, 4) or not integer(index, 1, 8) then
        return nil
    end

    local unit = gamepadPageUnit()
    local currentPage = read(field(unit, "GetCurrentPage"), unit)
    if not integer(currentPage, 1, 3) or currentPage ~= page then return nil end

    local bars = field(unit, "actionBars")
    local selected = field(bars, gamepadBarKeys[bar])
    local stance = field(bars, "stanceBar")
    local overriding = read(field(stance, "IsBarActivelyOverridingActionBar"), stance, selected)
    if addon.Client.Boolean(overriding) == true
        and addon.Client.Boolean(read(field(stance, "IsVisible"), stance)) == true then
        selected = stance
    end

    return field(field(selected, "actionButtons"), index)
end

function Buttons.SelectionLabel(config, kind)
    local mode = Buttons.Mode()
    if mode == "gamepad" then
        local page = config.Get(kind .. "GamepadPage")
        local bar = config.Get(kind .. "GamepadBar")
        local index = config.Get(kind .. "GamepadButton")
        if page == 0 then return "gamepad not selected" end

        return "gamepad page " .. page .. " / " .. gamepadBarLabels[bar]
            .. " / " .. gamepadPositionLabels[index]
    elseif mode == "unknown" then
        return "UI mode unknown"
    end

    local bar = config.Get(kind .. "Bar")
    if bar == 0 then return "not selected" end

    return "bar " .. bar .. " button " .. config.Get(kind .. "Button")
end

function Buttons.Bars()
    local labels = {}

    for index = 1, #prefixes do
        labels[index] = "Action bar " .. index
    end

    return labels
end

function Buttons.Selected(bar, index)
    if not addon.Client.Number(bar) or not addon.Client.Number(index)
        or bar ~= math.floor(bar) or not prefixes[bar]
        or index < 1 or index > 12 or index ~= math.floor(index) then
        return nil
    end

    return _G[prefixes[bar] .. index]
end


Buttons.BarPrefixes = prefixes

local function gamepadButtons(key)
    local bar = field(field(gamepadPageUnit(), "actionBars"), key)
    local list = field(bar, "actionButtons")
    if not addon.Client.Readable(list) or type(list) ~= "table" then return {} end

    local result = {}
    for index = 1, 8 do
        local button = field(list, index)
        if button then result[#result + 1] = button end
    end
    return result
end

function Buttons.Bar(index)
    local buttons = {}
    local prefix = prefixes[index]
    if not prefix then
        return buttons
    end

    for buttonIndex = 1, 12 do
        local button = _G[prefix .. buttonIndex]
        if button then
            buttons[#buttons + 1] = button
        end
    end

    return buttons
end

function Buttons.All()
    local buttons = {}
    local seen = {}

    local function add(button)
        if not seen[button] then
            seen[button] = true
            buttons[#buttons + 1] = button
        end
    end

    for barIndex = 1, #prefixes do
        for _, button in ipairs(Buttons.Bar(barIndex)) do
            add(button)
        end
    end

    for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar", "stanceBar" }) do
        for _, button in ipairs(gamepadButtons(key)) do
            add(button)
        end
    end

    return buttons
end

function Buttons.CooldownAll()
    local buttons = {}
    local seen = {}

    local function add(button, kind)
        if button and not seen[button] then
            seen[button] = true
            buttons[#buttons + 1] = { button = button, kind = kind }
        end
    end

    for _, button in ipairs(Buttons.All()) do
        add(button, "action")
    end

    for _, prefix in ipairs({ "ExtraActionButton", "StanceButton", "PossessButton",
        "OverrideActionBarButton", "SpellFlyoutPopupButton" }) do
        for index = 1, prefix == "SpellFlyoutPopupButton" and 40 or 12 do
            add(_G[prefix .. index], "action")
        end
    end

    for index = 1, NUM_PET_ACTION_SLOTS or 10 do
        add(_G["PetActionButton" .. index], "pet")
    end

    for _, button in ipairs(gamepadButtons("possessBar")) do
        add(button, "pet")
    end

    if type(LibStub) == "table" and type(LibStub.GetLibrary) == "function" then
        local ok, library = pcall(LibStub.GetLibrary, LibStub, "LibActionButton-1.0", true)
        if ok and type(library) == "table" and type(library.buttonRegistry) == "table" then
            for button in pairs(library.buttonRegistry) do
                add(button, "lab")
            end
        end
    end

    if Dominos and Dominos.ActionButtons and type(Dominos.ActionButtons.buttons) == "table" then
        for button in pairs(Dominos.ActionButtons.buttons) do
            add(button, "action")
        end
    end

    if Bartender4 and type(Bartender4.GetModule) == "function" then
        local ok, module = pcall(Bartender4.GetModule, Bartender4, "PetBar")
        if ok and module and module.bar and type(module.bar.buttons) == "table" then
            for _, button in ipairs(module.bar.buttons) do
                add(button, "pet")
            end
        end
    end

    return buttons
end

-- Reconcile discovery snapshots without touching effects owned by other features.
function Buttons.ReleaseRemoved(previous, current, release, buttonOf)
    buttonOf = buttonOf or function(button) return button end
    local present = {}
    for _, entry in ipairs(current) do present[buttonOf(entry)] = true end

    for _, entry in ipairs(previous) do
        local button = buttonOf(entry)
        if not present[button] then release(button) end
    end
end
