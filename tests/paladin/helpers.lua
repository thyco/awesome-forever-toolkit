local Base = dofile('tests/helpers.lua')
local H = {}

function H.new(settings)
    local w = Base.new()
    w.class = 'PALADIN'
    w.time = 100
    w.env.AwesomeForeverToolkitDB.paladin = settings or {}
    w.env.AwesomeForeverToolkitCharacterDB.utilities = {
        checkRangedAbilities = false, checkMeleeAbilities = false,
        greyOnCooldown = false, greyUnusableActions = false, greyPetActions = false,
    }
    w.cooldowns = {}
    w.spells = { [1] = { name = 'Holy Strike', spellID = 1 }, [2] = { name = 'Judgement', spellID = 2 },
        [7] = { name = 'Exorcism', spellID = 7 }, [8] = { name = 'Righteous Fury', spellID = 8 },
        [9] = { name = 'Seal of Righteousness', spellID = 9 }, [20424] = {name = 'Seal of Command', spellID = 20424} }
    w.env.C_Spell.GetSpellInfo = function(id)
        if type(id) == 'string' then
            for _, spell in pairs(w.spells) do if spell.name == id then return spell end end
        end
        return w.spells[id]
    end
    w.env.C_Spell.GetSpellCooldown = function(id) return w.cooldowns[id] or { startTime = 0, duration = 0, isEnabled = true } end
    w.env.C_SpellBook.IsSpellKnown = function(id) return w.spells[id] ~= nil end
    w.env.GetInventoryItemID = function() return w.shield and 900 or nil end
    w.env.C_Item = {GetItemInfoInstant = function() return 900, nil, nil, 'INVTYPE_SHIELD' end}
    w.env.C_UnitAuras.GetPlayerAuraBySpellID = function() return w.aura end
    w.env.C_Secrets = {ShouldSpellAuraBeSecret = function() return w.auraRestricted == true end}
    w.env.UnitCreatureType = function() return 'Creature', w.creatureType end
    w.env.C_Spell.IsSpellInRange = function() return w.rangeResult end
    w.holy = w:button('MultiBarBottomRightButton3', 1)
    w.seal = w:button('MultiBarBottomRightButton4', 2)
    w.exorcism = w:button('MultiBarBottomRightButton5', 3)
    w.root = w:loadManifest()
    w:fire('PLAYER_LOGIN')
    w.paladin = w.root.modules.Paladin

    function w:glowing(button) return self.glowActive[button] == true end
    function w:color(button)
        for frame, options in pairs(self.glows) do
            if frame.parent == button then return options.color end
        end
    end
    return w
end
return H
