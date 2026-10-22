local _, addon = ...
addon.DisplayLocation = {}

function addon.DisplayLocation.Create(layout, store, kind, dropdownKind)
    dropdownKind = dropdownKind or "Dropdown"
    local bars = {{value = 0, label = "Not selected"}}
    for index, label in ipairs(addon.Buttons.Bars()) do bars[#bars + 1] = {value = index, label = label} end
    local pages = addon.Widgets.Options(1, 3, 1, "Page ")
    table.insert(pages, 1, {value = 0, label = "Not selected"})
    local sets, positions = {}, {}
    for index, label in ipairs(addon.Buttons.GamepadBars()) do sets[#sets + 1] = {value = index, label = label} end
    for index, label in ipairs(addon.Buttons.GamepadPositions()) do positions[#positions + 1] = {value = index, label = label} end

    layout:Heading("Display locations")
    layout:Field(dropdownKind, kind .. "Bar", "Standard action bar", bars)
    layout:Field(dropdownKind, kind .. "Button", "Standard button", addon.Widgets.Options(1, 12, 1, "Button "))
    layout:Field(dropdownKind, kind .. "GamepadPage", "Gamepad page", pages)
    layout:Field(dropdownKind, kind .. "GamepadBar", "Gamepad set", sets)
    layout:Field(dropdownKind, kind .. "GamepadButton", "Gamepad button", positions)
end
