local H = dofile("tests/helpers.lua")
local function setup()
    local world = H.new()
    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    addon.Window:Open()
    addon.Window:ShowPage("warrior.reminders")
    world.reloads = 0
    world.env.ReloadUI = function()
        assert(not world.combat)
        assert(addon.Window.canvas:IsVisible(), "reload must precede hide")
        world.reloads = world.reloads + 1
    end
    return world, addon.Window, addon
end

do
    local world, panel = setup()
    panel:Close()
    assert(world.reloads == 0)
    assert(not panel.canvas:IsVisible())
end

for _, close in ipairs({"x", "escape", "footer"}) do
    local world, panel, addon = setup()
    addon.modules.Warrior.Config.Set("overpowerEnabled", false)

    if close == "x" then panel.closeButton.scripts.OnClick()
    elseif close == "escape" then panel.canvas.scripts.OnKeyDown(panel.canvas, "ESCAPE")
    else panel.applyButton.scripts.OnClick() end
    panel:Close()

    assert(world.reloads == 1)
end

do
    local world, panel, addon = setup()
    local config = addon.modules.Warrior.Config
    local original = config.Get("glowColor")
    panel.controls["warrior.glowColor"].scripts.OnClick()
    world.env.ColorPickerFrame.GetColorRGB = function() return 1, 0, 0 end
    world.env.ColorPickerFrame.options.swatchFunc()
    world.env.ColorPickerFrame.options.cancelFunc()

    assert(config.Get("glowColor") == original)
    panel:Close()
    assert(world.reloads == 1)
end

do
    local world, panel, addon = setup()
    addon.modules.Warrior.Config.Set("stanceIconX", 120)
    world.combat = true

    world:fire("PLAYER_REGEN_DISABLED")
    panel:Close()

    assert(world.reloads == 0)
    assert(not panel.canvas:IsVisible())
    assert(panel.reloadRequired)
    world.combat = false
    panel:Open()
    panel:Close()
    assert(world.reloads == 1)
end

do
    local world, panel, addon = setup()
    addon.modules.Warrior.Config.Set("overpowerEnabled", true)
    addon.modules.Utilities.Config.Set("checkMeleeAbilities", false)
    panel:Close()
    assert(world.reloads == 0)
end
print("settings close: PASS")
