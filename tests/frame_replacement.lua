local H = dofile("tests/helpers.lua")
local failures = 0

local function test(name, run)
    local ok, err = pcall(run)
    if ok then print("PASS " .. name)
    else failures = failures + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function setup(mode)
    local world = H.new()
    world.spells[78] = {name = "Heroic Strike", spellID = 78, minRange = 0, maxRange = 0}
    world.learned = {10, 78}
    world.env.C_SpellBook.GetSpellBookItemInfo = function(index)
        return {itemType = 1, spellID = world.learned[index], isPassive = false, isOffSpec = false}
    end
    world.actions[201] = {"spell", mode == "queued" and 78 or 10}
    if mode == "cooldown" then
        world.ranges[10] = true
        world.env.C_ActionBar = {
            GetActionCooldown = function() return {startTime = 1, duration = 8, isEnabled = true, isOnGCD = false} end,
            IsUsableAction = function() return true, false end,
        }
        world.time = 2
    end
    local old = world:gamepadBar("topBar", {201})[1]
    old:SetChecked(mode == "queued")
    local root = world:loadManifest()
    world:fire("PLAYER_LOGIN")

    return world, root, old
end

for _, removed in ipairs({false, true}) do
    local transition = removed and "removal" or "replacement"
    test("range " .. transition .. " clears only range tint", function()
        local world, root, old = setup("range")
        local utilities = root.modules.Utilities
        assert(old.icon.color[2] == 0.25)
        utilities.IconTint.SetCooldown(old, true)
        if removed then world.env.GamepadMainActionBarFrame = nil
        else world:gamepadBar("topBar", {201}) end

        utilities.RangeCheck:Refresh(true, false)

        assert(old.icon.color[2] == 1, "departed icon remains red")
        assert(old.icon.desaturation == 1, "cooldown layer must survive")
        utilities.IconTint.SetCooldown(old, false)
        assert(old.icon.desaturation == 0)
    end)

    test("cooldown " .. transition .. " clears only cooldown tint", function()
        local world, root, old = setup("cooldown")
        local utilities = root.modules.Utilities
        assert(old.icon.desaturation == 1)
        utilities.IconTint.Set(old, true)
        if removed then world.env.GamepadMainActionBarFrame = nil
        else world:gamepadBar("topBar", {201}) end

        utilities.CooldownGrey:Refresh(true)

        assert(old.icon.color[2] == 0.25, "range layer must survive")
        utilities.IconTint.Set(old, false)
        assert(old.icon.desaturation == 0, "departed icon remains grey")
    end)

    test("queued " .. transition .. " clears border and preserves proc", function()
        local world, root, old = setup("queued")
        local utilities = root.modules.Utilities
        local entry = utilities.QueuedGlow.Prepare(old)
        assert(entry.effect:IsVisible(), "fixture must queue the old button")
        root.Glow.Set(old, "warrior:replacement-test", true)
        if removed then world.env.GamepadMainActionBarFrame = nil
        else world:gamepadBar("topBar", {201}) end

        utilities.QueuedAttackGlow:Refresh(true, false)

        assert(not entry.effect:IsVisible(), "departed border remains shown")
        assert(world.glowActive[old], "class proc owner must survive")
    end)
end

assert(failures == 0, tostring(failures) .. " frame replacement regressions")
