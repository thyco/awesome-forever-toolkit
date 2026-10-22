local Base = dofile("tests/warrior/helpers.lua")
local H = { equal = Base.equal }

function H.new()
    local world = Base.new()
    world.class = "HUNTER"
    world.time = 100
    world.learned = { 1495, 19306 }
    world.usable = { [1495] = true, [19306] = true }
    world.lowPower = {}
    world.cooldowns = {
        [1495] = { isActive = false, isEnabled = true, startTime = 0, duration = 0 },
        [19306] = { isActive = false, isEnabled = true, startTime = 0, duration = 0 },
    }
    world.names = { [1495] = "Morsure", [19306] = "Contre-attaque", [14269] = "Morsure" }
    world.env.C_Spell.GetSpellInfo = function(id) return { name = world.names[id], iconID = 132336 } end
    world.env.C_Spell.IsSpellUsable = function(id) return world.usable[id], world.lowPower[id] or false end
    world.env.C_Spell.GetSpellCooldown = function(id) return world.cooldowns[id] end
    world.env.Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 },
        InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
    world.style = 0
    world.env.C_InputInterfaceStyle = { GetCurrentStyle = function() return world.style end }
    world.env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #world.learned } end,
        GetSpellBookItemInfo = function(index)
            return { itemType = 1, isPassive = false, isOffSpec = false, spellID = world.learned[index] }
        end,
    }
    world.config = { mongooseGlowEnabled = true, mongooseBar = 1, mongooseButton = 1,
        mongooseNativeColor = true, mongooseGamepadPage = 1, mongooseGamepadBar = 1, mongooseGamepadButton = 1,
        counterattackGlowEnabled = true, counterattackBar = 1, counterattackButton = 2,
        counterattackNativeColor = true, counterattackGamepadPage = 1, counterattackGamepadBar = 1,
        counterattackGamepadButton = 2, counterattackOverlayEnabled = true }
    world.env.ActionButton1 = world:newFrame()
    world.env.ActionButton2 = world:newFrame()
    world.gamepad = { world:newFrame(), world:newFrame() }
    local pageUnit = { currentPage = 1, actionBars = { topBar = { actionButtons = world.gamepad } } }
    world.env.GamepadMainActionBarFrame = { PageUnit = pageUnit }
    world.pageUnit = pageUnit
    function pageUnit:GetCurrentPage() return self.currentPage end

    local createFrame = world.env.CreateFrame
    world.env.CreateFrame = function(kind, ...)
        local frame = createFrame(kind, ...)
        local createTexture = frame.CreateTexture
        frame.CreateTexture = function(self, ...)
            local texture = createTexture(self, ...)
            texture.AddMaskTexture = function(self, mask) self.mask = mask end
            return texture
        end
        frame.CreateMaskTexture = frame.CreateTexture
        if kind == "Cooldown" then
            for _, method in ipairs({ "SetDrawBling", "SetDrawEdge", "SetDrawSwipe", "SetHideCountdownNumbers" }) do
                frame[method] = function() end
            end
            frame.SetSwipeTexture = function(self, texture) self.swipeTexture = texture end
            frame.SetCooldown = function(self, start, duration) self.start, self.duration = start, duration end
            frame.Clear = function(self) self.start, self.duration = nil, nil end
        end
        return frame
    end

    world.root = { modules = { Hunter = { gcdSpellID = 61304 } } }
    for _, file in ipairs({ "Services/Client", "Services/Buttons", "Services/Glow" }) do
        assert(loadfile("AwesomeForeverToolkit/" .. file .. ".lua", "t", world.env))("AwesomeForeverToolkit", world.root)
    end
    local addon = world.root.modules.Hunter
    addon.Client, addon.Buttons, addon.Glow = world.root.Client, world.root.Buttons, world.root.Glow
    addon.Config = {
        Get = function(key) return world.config[key] end,
        GetColor = function() return 0.2, 0.4, 0.6 end,
    }
    world.addon = addon

    function world:loadReactive(...)
        for _, file in ipairs({ ... }) do
            assert(loadfile("AwesomeForeverToolkit/Modules/Hunter/" .. file .. ".lua", "t", self.env))(
                "AwesomeForeverToolkit", self.root)
        end
        return self.addon
    end

    return world
end

return H
