local H = dofile("tests/helpers.lua")

-- Fresh characters start with native controls and no active overrides.
do
    local world = H.new()
    local root = world:loadManifest()

    world:fire("PLAYER_LOGIN")

    local gamepad = assert(root.modules.Gamepad, "Gamepad module missing")
    assert(gamepad.active)
    assert(gamepad.Runtime.GetConfig("A").mode == "native")
    assert(not gamepad.Runtime.IsEnabled("A"))
    assert(world.env.SlashCmdList.GAMEPADASSISTFOREVER == nil)
end

-- No gamepad layout/APIs are needed to load the toolkit on another class.
do
    local world = H.new()
    world.class = "HUNTER"
    local root = world:loadManifest()

    world:fire("PLAYER_LOGIN")
    world:tick(1)

    assert(root.modules.Gamepad.active)
    assert(not root.modules.Warrior.active)
    assert(root.Window:ShowPage("general"))
end
print("gamepad integration: PASS")

-- Every class owns its gamepad page, after the shared pages.
for _, class in ipairs({"WARRIOR", "HUNTER", "PALADIN"}) do
    local world = H.new()
    world.class = class
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")

    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("gamepad")

    assert(root.Window.currentPage == "gamepad.bindings")
    assert(root.Window.canvas:IsVisible())
    assert(root.Window.pages["gamepad.bindings"].parent == (class == "WARRIOR" and "Warrior" or world.env.UnitClass("player")))
    local seenClass = false
    for _, page in ipairs(root.Window.order) do
        if page.parent then seenClass = true
        else assert(not seenClass, "shared pages must precede class pages") end
    end

    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("gamepad")
    assert(not root.Window.canvas:IsVisible())
end
