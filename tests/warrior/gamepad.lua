local H = dofile("tests/warrior/helpers.lua")

local function setup()
    local world = H.new()
    world.style, world.page, world.stance = 0, 1, 17
    world.env.Enum = {
        InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 },
        SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 },
    }
    world.env.C_InputInterfaceStyle = { GetCurrentStyle = function() return world.style end }
    world.env.GetShapeshiftFormID = function() return world.stance end
    world.env.UnitPower = function() return 1 end
    local ids = { 7384, 6572, 5308, 402927, 2565 }
    local names = { "Overpower", "Revenge", "Execute", "Victory Rush", "Shield Block" }
    world.env.C_Spell.GetSpellInfo = function(id)
        for index, known in ipairs(ids) do
            if known == id then return { name = names[index] } end
        end
    end
    world.env.C_Spell.IsSpellUsable = function() return true, false end
    world.env.C_Spell.IsSpellInRange = function() return true end
    world.env.C_Spell.GetSpellCooldown = function()
        return { isActive = false, isEnabled = true, startTime = 0, duration = 0 }
    end
    world.env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #ids } end,
        GetSpellBookItemInfo = function(index)
            return { itemType = 1, isPassive = false, isOffSpec = false, spellID = ids[index] }
        end,
    }
    world.env.GetInventoryItemID = function() return 123 end
    world.env.C_Item = { GetItemInfoInstant = function() return 123, "Armor", "Shields", "INVTYPE_SHIELD" end }
    world.env.AwesomeForeverToolkitDB.warrior = {}
    world.keyboard, world.bars = {}, {}

    local root = world:newFrame()
    root.visible = false
    world.root = root
    root.PageUnit = { GetCurrentPage = function() return world.page end, actionBars = world.bars }
    world.env.GamepadMainActionBarFrame = root

    for _, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar", "stanceBar", "possessBar" }) do
        local bar = world:newFrame()
        bar.actionButtons = {}
        world.bars[key] = bar
        bar.visible = key ~= "stanceBar" and key ~= "possessBar"
        function bar:IsVisible() return self.visible and root.visible end
        for index = 1, 8 do
            local button = world:newFrame()
            button.parent = bar
            button:SetSize(32, 32)
            function button:IsVisible() return self.visible and bar:IsVisible() end
            bar.actionButtons[index] = button
        end
    end
    world.bars.stanceBar.IsBarActivelyOverridingActionBar = function(_, bar)
        return world.override and bar == world.bars.leftBar or false
    end

    world.kinds = { "overpower", "revenge", "execute", "victoryRush", "shieldBlock" }
    for index, kind in ipairs(world.kinds) do
        world.keyboard[index] = world:newFrame()
        world.env["ActionButton" .. index] = world.keyboard[index]
        world.env.AwesomeForeverToolkitDB.warrior[kind .. "Bar"] = 1
        world.env.AwesomeForeverToolkitDB.warrior[kind .. "Button"] = index
    end

    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    return world, addon
end

local world, addon = setup()
H.equal(addon.Buttons.Mode(), "keyboard")

for index, kind in ipairs(world.kinds) do
    H.equal(addon.Config.Get(kind .. "GamepadPage"), 1, "new gamepad destinations default to page 1")
    world.settings[kind .. "GamepadPage"]:SetValue(1)
    world.settings[kind .. "GamepadBar"]:SetValue(2)
    world.settings[kind .. "GamepadButton"]:SetValue(index)
end

H.equal(addon.Config.Get("overpowerBar"), 1, "gamepad settings preserve the keyboard selection")
H.equal(pcall(addon.Config.Set, "overpowerGamepadPage", 4), false)
H.equal(pcall(addon.Config.Set, "overpowerGamepadBar", 5), false)
H.equal(pcall(addon.Config.Set, "overpowerGamepadButton", 9), false)

for barIndex, key in ipairs({ "topBar", "leftBar", "rightBar", "bottomBar" }) do
    for index = 1, 8 do
        H.equal(addon.Buttons.GamepadSelected(1, barIndex, index), world.bars[key].actionButtons[index],
            "each gamepad position resolves its actual Blizzard button")
    end
end

local selected = world.bars.leftBar.actionButtons[1]
H.equal(addon.Buttons.GamepadSelected(1, 2, 1), selected)
H.equal(addon.Buttons.GamepadSelected(2, 2, 1), nil, "same frame on another page is not the destination")
H.equal(addon.Buttons.GamepadSelected(0, 2, 1), nil)
H.equal(addon.Buttons.GamepadSelected(1, 2, 9), nil)
H.equal(addon.Glow.IsPrepared(selected), true, "hidden gamepad destinations are prepared before combat")
H.equal(addon.Glow.IsPrepared(world.bars.stanceBar.actionButtons[1]), true,
    "stance replacements are prepared before combat")

world.style, world.root.visible = 1, true
world.combat = true
world:tick(0.1)

H.equal(addon.Buttons.Mode(), "gamepad")
H.equal(world.glowActive[world.keyboard[1]], false, "UI switching clears the old keyboard owner")
H.equal(world.glowActive[selected], true, "Overpower uses its gamepad destination in combat")
H.equal(world.glowActive[world.bars.leftBar.actionButtons[3]], true, "Execute uses its own gamepad slot")
H.equal(world.glowActive[world.bars.leftBar.actionButtons[4]], true, "Victory Rush uses its gamepad slot")
H.equal(world.combatFrameCreations, 0, "UI switching allocates no combat frames")

world.stance = 18
world:tick(0.1)
H.equal(world.glowActive[selected], false, "Overpower still obeys its stance restriction")
H.equal(world.glowActive[world.bars.leftBar.actionButtons[2]], true, "Revenge uses its gamepad slot")
H.equal(world.glowActive[world.bars.leftBar.actionButtons[5]], true, "Shield Block uses its gamepad slot")

world.page = 2
world:tick(0.1)
H.equal(world.glowActive[world.bars.leftBar.actionButtons[2]], false, "page changes clear unrelated icons")
world.page = 1
world:tick(0.1)
H.equal(world.glowActive[world.bars.leftBar.actionButtons[2]], true, "returning to the selected page restores glow")

world.override = true
world.bars.leftBar.visible, world.bars.stanceBar.visible = false, true
world:tick(0.1)
H.equal(addon.Buttons.GamepadSelected(1, 2, 2), world.bars.stanceBar.actionButtons[2])
H.equal(world.glowActive[world.bars.leftBar.actionButtons[2]], false)
H.equal(world.glowActive[world.bars.stanceBar.actionButtons[2]], true,
    "glow follows the stance bar replacing the selected set")
H.equal(world.combatFrameCreations, 0)

world.style, world.root.visible = 0, false
world:tick(0.1)
H.equal(world.glowActive[world.bars.stanceBar.actionButtons[2]], false)
H.equal(world.glowActive[world.keyboard[2]], true, "keyboard destination returns on UI switch")

world.style = {}
world.secret[world.style] = true
world:tick(0.1)
H.equal(addon.Buttons.Mode(), "unknown")
H.equal(world.glowActive[world.keyboard[2]], false, "unreadable UI mode cannot pick a keyboard destination")

world.style, world.root.visible, world.combat = 1, true, false
world.override = false
world.bars.leftBar.visible, world.bars.stanceBar.visible = true, false
world.stance = 19
addon.Config.Set("overpowerBerserkerNativeColor", false)
addon.Config.Set("overpowerBerserkerGlowColor", "ffff0000")
world:tick(0.1)
local entry = addon.Glow.Prepare(selected)
H.equal(world.glows[entry.frame].color[1], 1)
H.equal(world.glows[entry.frame].color[2], 0, "gamepad retains Berserker custom red")

world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("warrior")
assert(table.concat(world.printed, "\n"):find("gamepad page 1 / Left set / D-pad left", 1, true))

H.equal(addon.ReactiveAbilities:PreviewGamepad("shieldBlock"), true,
    "preview works outside combat without a real Shield Block opportunity")
H.equal(world.glowActive[world.bars.leftBar.actionButtons[5]], true)
world:tick(3.1)
H.equal(world.glowActive[world.bars.leftBar.actionButtons[5]], false, "preview expires")
H.equal(world.glowActive[selected], true, "preview does not clear the genuine Overpower owner")

addon.ReactiveAbilities:PreviewGamepad("shieldBlock")
H.equal(world.glowActive[world.bars.leftBar.actionButtons[5]], true, "settings button starts the preview")
addon:ClearPreviews()
H.equal(world.glowActive[world.bars.leftBar.actionButtons[5]], false, "closing settings clears preview")

addon.ReactiveAbilities:PreviewGamepad("shieldBlock")
world.combat = true
world:tick(0.1)
H.equal(world.glowActive[world.bars.leftBar.actionButtons[5]], false, "combat clears the preview")
H.equal(addon.ReactiveAbilities:PreviewGamepad("shieldBlock"), false, "preview cannot start in combat")

world.combat, world.page = false, 2
H.equal(addon.ReactiveAbilities:PreviewGamepad("shieldBlock"), false, "preview cannot target another page")
world.page = 1
world.bars.leftBar.visible = false
world.bars.possessBar.visible = true
world:tick(0.1)
H.equal(world.glowActive[selected], false, "possess replacement does not inherit warrior glows")

world.env.GamepadMainActionBarFrame = nil
world:tick(0.1)
H.equal(addon.Buttons.GamepadSelected(1, 2, 1), nil, "missing gamepad HUD stays safe")
world.env.C_InputInterfaceStyle.GetCurrentStyle = function() error("restricted style") end
H.equal(addon.Buttons.Mode(), "unknown")
world.env.C_InputInterfaceStyle = nil
H.equal(addon.Buttons.Mode(), "keyboard", "older clients without gamepad API retain keyboard support")

local onlyGamepad, onlyAddon = setup()
for _, kind in ipairs(onlyGamepad.kinds) do onlyAddon.Config.Set(kind .. "Bar", 0) end
onlyAddon.Config.Set("overpowerGamepadPage", 1)
onlyAddon.Config.Set("overpowerGamepadBar", 3)
onlyAddon.Config.Set("overpowerGamepadButton", 8)
onlyGamepad.style, onlyGamepad.root.visible = 1, true
onlyGamepad:tick(0.1)
H.equal(onlyGamepad.glowActive[onlyGamepad.bars.rightBar.actionButtons[8]], true,
    "gamepad-only configuration keeps polling without any keyboard destination")

local hiddenButtons = onlyGamepad.bars.rightBar.actionButtons
onlyGamepad.secret[hiddenButtons] = true
onlyGamepad:tick(0.1)
H.equal(onlyGamepad.glowActive[hiddenButtons[8]], false, "unreadable frame collection clears its owner")
onlyGamepad.secret[hiddenButtons] = nil
onlyGamepad.bars.rightBar.actionButtons = setmetatable({}, { __index = function() error("restricted") end })
H.equal(onlyAddon.Buttons.GamepadSelected(1, 3, 8), nil, "failing frame lookup remains safe")

local reloaded = H.new()
reloaded.env.AwesomeForeverToolkitDB.warrior = world.env.AwesomeForeverToolkitDB.warrior
local reloadedAddon = reloaded:loadManifest()
reloaded:fire("PLAYER_LOGIN")
H.equal(reloadedAddon.Config.Get("shieldBlockGamepadButton"), 5, "gamepad selection survives reload")
H.equal(reloadedAddon.Config.Get("shieldBlockButton"), 5, "keyboard selection also survives reload")

print("gamepad: PASS")

-- A normal action-bar preview must not need a real ability opportunity.
do
    local world, addon = setup()
    local button = world.keyboard[5]
    assert(not world.glowActive[button])

    assert(addon.ReactiveAbilities:Preview("shieldBlock"))

    assert(world.glowActive[button])
    world:tick(3.1)
    assert(not world.glowActive[button], "normal action-bar preview expires")

    assert(addon.ReactiveAbilities:Preview("shieldBlock"))
    addon:ClearPreviews()
    assert(not world.glowActive[button], "closing settings clears normal preview")

    assert(addon.ReactiveAbilities:Preview("shieldBlock"))
    world.combat = true
    world:tick(0.1)
    assert(not world.glowActive[button], "combat clears normal preview")
    assert(not addon.ReactiveAbilities:Preview("shieldBlock"))

    world.combat = false
    assert(addon.ReactiveAbilities:Preview("shieldBlock"))
    world.style, world.root.visible = 1, true
    world:tick(0.1)
    assert(not world.glowActive[button], "switching UI clears the old preview")
    assert(addon.ReactiveAbilities.preview == nil)

    assert(addon.ReactiveAbilities:Preview("shieldBlock"))
    assert(world.glowActive[world.bars.topBar.actionButtons[1]], "shared preview supports gamepad")
    addon:ClearPreviews()

    world.style, world.root.visible = 0, false
    addon.Config.Set("shieldBlockBar", 0)
    assert(not addon.ReactiveAbilities:Preview("shieldBlock"), "unselected destination cannot preview")
end
