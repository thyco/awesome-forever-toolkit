local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:loadManifest()
world:fire("PLAYER_LOGIN")

assert(addon.Window, "standalone window missing")
addon.Window:Open()
addon.Window:ShowPage("warrior.reminders")
local config = addon.modules.Warrior.Config
assert(addon.Window.controls["warrior.overpowerGamepadButton"])
assert(#addon.Window.controls["warrior.overpowerGamepadButton"].options == 8)
addon.Window.settings["warrior.overpowerGamepadButton"]:SetValue(4)
assert(config.Get("overpowerGamepadButton") == 4)
addon.Window:ShowPage("utilities")
assert(addon.Window.reloadRequired)
addon.Window.settings["utilities.checkRangedAbilities"]:SetValue(false)
assert(not addon.modules.Utilities.Config.Get("checkRangedAbilities"))
assert(world.env.AwesomeForeverToolkitCharacterDB.utilities.checkRangedAbilities == false)

local other = H.new()
other.class = "HUNTER"
other.env.AwesomeForeverToolkitCharacterDB = {ui = {lastPage = "warrior.reminders"}}
local root = other:loadManifest()
other:fire("PLAYER_LOGIN")
root.Window:Open()
assert(root.Window.currentPage == "general")
assert(not root.modules.Warrior.active)
assert(root.modules.Utilities.active)
assert(root.Window:ShowPage("warrior.reminders") == false)
print("settings: PASS")

do
    local world = H.new()
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("utilities options")
    assert(root.Window.canvas:IsVisible())
end

do
    local world = H.new()
    world.env.Settings = nil
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("")
    assert(root.Window.canvas:IsVisible())
end

do
    local world = H.new()
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    root.Window:Open()
    root.Window:ShowPage("utilities")
    local config = root.modules.Utilities.Config
    local prior = config.Get("queuedGlowColor")
    root.Window.controls["utilities.queuedGlowColor"].scripts.OnClick()
    world.env.ColorPickerFrame.GetColorRGB = function() return 1, 0, 0 end
    world.env.ColorPickerFrame.options.swatchFunc()
    assert(config.Get("queuedGlowColor") == "ffff0000")
    world.env.ColorPickerFrame.options.cancelFunc()
    assert(config.Get("queuedGlowColor") == prior)

    world.env.ColorPickerFrame.GetColorRGB = function() return world.secret, 0, 0 end
    world.env.ColorPickerFrame.options.swatchFunc()
    assert(config.Get("queuedGlowColor") == prior)
    assert(not root.Window.reloadRequired)
end

do
    local world = H.new()
    world.env.AwesomeForeverToolkitCharacterDB.utilities = {checkRangedAbilities = false}
    world.actions[1] = {"spell", 10}
    local button = world:button("ActionButton1", 1)
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    root.Window:Open()
    root.Window:ShowPage("utilities")
    local check = root.Window.controls["utilities.checkRangedAbilities"]
    assert(check:GetChecked() == false)

    check:SetChecked(true)
    check.scripts.OnClick(check)

    assert(root.modules.Utilities.Config.Get("checkRangedAbilities"))
    assert(button.icon.desaturation == 1)
    assert(button.icon.color[2] == 0.25)
    assert(root.modules.Utilities.Config.Get("checkMeleeAbilities"))
    assert(root.Window.content.parent == root.Window.scroll)
    root.Window:ShowPage("warrior.stance")
    root.Window.controls["warrior.moveStance"].scripts.OnClick()
    assert(root.modules.Warrior.StanceIcon.preview)
    root.Window:ShowPage("general")
    assert(not root.modules.Warrior.StanceIcon.preview)
end

-- The Blizzard Settings launcher must initialize successfully and open the standalone window.
do
    local world = H.new()
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    assert(not root.Window.canvas:IsVisible())

    world.launcher.click()

    assert(root.Window.canvas:IsVisible())
    assert(root.Window.currentPage == "general")
end

-- The settings preview button uses the selected normal action-bar destination.
do
    local world = H.new()
    local button = world:button("ActionButton1", 1)
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    root.modules.Warrior.Config.Set("shieldBlockBar", 1)
    root.Window:Open()
    root.Window:ShowPage("warrior.reminders")

    root.Window.controls["warrior.shieldBlockPreview"].scripts.OnClick()

    assert(world.glowActive[button], "settings must start a normal action-bar preview")
end
