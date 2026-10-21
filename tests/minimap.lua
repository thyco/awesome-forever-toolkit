local H = dofile("tests/helpers.lua")
do
    local world = H.new()
    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    assert(addon.Minimap, "minimap launcher missing")

    addon.Minimap:SaveAngle(450)
    assert(addon.Config.GetSection("character", "ui").minimapAngle == 90)
    addon.Config.GetSection("character", "ui").minimapHidden = true
    addon.Minimap:Refresh()
    assert(not addon.Minimap.button:IsVisible())
    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("")
    assert(addon.Window.canvas:IsVisible())
    addon.Window:Close()

    world.combat = true
    addon.Minimap.button.scripts.OnClick()
    assert(not addon.Window.canvas:IsVisible())
    world.combat = false
    addon.Minimap.button.scripts.OnClick()
    assert(addon.Window.canvas:IsVisible())
end

do
    local world = H.new()
    world.env.AwesomeForeverToolkitCharacterDB.ui = {minimapAngle = 0/0}
    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    assert(addon.Config.GetSection("character", "ui").minimapAngle == 225)

    world.scale = 2
    world.cursorX, world.cursorY = 1000, 1200
    addon.Minimap.button.scripts.OnDragStart()
    addon.Minimap.button.scripts.OnUpdate()
    addon.Minimap.button.scripts.OnDragStop()

    assert(math.abs(addon.Config.GetSection("character", "ui").minimapAngle - 90) < 0.01)
    assert(addon.Minimap.button:GetScript("OnUpdate") == nil)
end

do
    local world = H.new()
    world.env.Minimap = nil
    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")

    assert(addon.Minimap.button == nil)
    world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("")
    assert(addon.Window.canvas:IsVisible())
end
print("minimap: PASS")
