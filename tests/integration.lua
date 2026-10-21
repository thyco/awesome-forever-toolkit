local H = dofile("tests/helpers.lua")

do
    local world = H.new()
    world.actions[1] = {"spell", 10}
    local button = world:button("ActionButton1", 1)
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    local frames = #world.frames

    world:fire("PLAYER_LOGIN")
    assert(#world.frames == frames)
    assert(root.modules.Utilities.Client == root.modules.Warrior.Client)
    assert(root.modules.Utilities.Buttons == root.modules.Warrior.Buttons)
    assert(root.modules.Warrior.Glow == root.Glow)
    assert(world.launcher)

    root.Glow.Prepare(button)
    root.Glow.Set(button, "warrior:integration", true)
    assert(world.glowActive[button])
    assert(button.icon.desaturation == 1)
    root.Glow.ClearOwner("warrior:integration")
    assert(button.icon.desaturation == 1)

    root.Glow.Set(button, "warrior:integration", true)
    root.modules.Utilities:Stop()
    assert(button.icon.desaturation == 0)
    assert(world.glowActive[button])
end

do
    local world = H.new()
    world.loaded.WarriorAssistForever = true
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")

    assert(not root.modules.Warrior.active)
    assert(root.modules.Utilities.active)
    assert(not root.Window.navigation["warrior.reminders"])
    assert(root.modules.Warrior.status:match("disable"))
end

do
    local world = H.new()
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    root.Window:Open()
    root.Window:ShowPage("warrior.reminders")
    local dropdown = root.Window.controls["warrior.feature"]
    local choose = {}
    dropdown.menuGenerator(dropdown, {CreateRadio = function(_, label, _, callback, value)
        choose[label] = function() callback(value) end
    end})

    choose.Overpower()

    assert(dropdown.text == "Overpower", "feature selector must update its visible label")
    assert(root.Window.controls["warrior.overpowerEnabled"].parent:IsVisible())
    assert(not root.Window.controls["warrior.battleShoutEnabled"].parent:IsVisible())
end

print("integration: PASS")
