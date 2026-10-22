local H = dofile("tests/helpers.lua")

-- Legacy assignments must not activate or populate the new module.
do
    local world = H.new()
    world.env.GamepadAssistForeverOverlayDB = {A = {mode = "always", spellID = 133}}
    world.env.GamepadAssistForeverOverlayEnabled = {A = true}
    local root = world:loadManifest()

    world:fire("PLAYER_LOGIN")

    local gamepad = assert(root.modules.Gamepad, "Gamepad module missing")
    assert(gamepad.active)
    assert(gamepad.Runtime.GetConfig("A").mode == "native")
    assert(not gamepad.Runtime.IsEnabled("A"))
    assert(world.env.GamepadAssistForeverOverlayDB.A.spellID == 133)
    assert(world.env.SlashCmdList.GAMEPADASSISTFOREVER == nil)
end

-- Loading the old addon suppresses every runtime side effect of the new module.
do
    local world = H.new()
    world.loaded.GamepadAssistForever = true
    local provider = {version = 1}
    world.env.GamepadAssistForeverVisuals = provider
    local root = world:loadManifest()

    world:fire("PLAYER_LOGIN")

    assert(not root.modules.Gamepad.active)
    assert(root.modules.Gamepad.status:find("disable GamepadAssistForever", 1, true))
    assert(root.modules.Gamepad.Runtime.frame == nil)
    assert(world.env.GamepadAssistForeverVisuals == provider)
    assert(world.env.AwesomeForeverToolkitCharacterDB.gamepad == nil)
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
