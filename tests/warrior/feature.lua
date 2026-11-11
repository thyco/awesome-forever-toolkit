local H = dofile("tests/warrior/helpers.lua")
local function setup(configure)
    local world = H.new()
    if configure then configure(world) end
    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    return world, addon
end

-- Class gating avoids feature initialization and aura queries entirely.
do
    local world, addon = setup(function(w) w.class = "MAGE" end)
    H.equal(#addon.features, 0)
    H.equal(addon.BattleShoutIcon.frame, nil)
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    world:fire("UNIT_AURA", "player")
    world:tick(1)
    H.equal(world.auraQueries, 0)
end

-- Preview moves the saved icon outside combat and ends on combat entry.
do
    local world, addon = setup()
    local icon = addon.BattleShoutIcon
    H.equal(icon.frame.strata, "BACKGROUND", "underlay stays below aura icons")
    icon:SetPreview(true)
    H.equal(icon.frame:IsVisible(), true)
    H.equal(icon.frame.mouse, true)
    icon.frame.scripts.OnDragStart(icon.frame)
    H.equal(icon.frame.moving, true)
    icon.frame.x, icon.frame.y = 550, 480
    icon.frame.scripts.OnDragStop(icon.frame)
    H.equal(addon.Config.Get("iconX"), 50)
    H.equal(addon.Config.Get("iconY"), 80)

    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    H.equal(icon.frame.mouse, false)
    H.equal(icon.frame.strata, "BACKGROUND", "combat underlay retains low display layer")
    icon:SetPreview(true)
    H.equal(icon.preview, false)
end

print("Battle Shout preview and class gating: PASS")
