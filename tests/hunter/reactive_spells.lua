local H = dofile("tests/hunter/reactive/helpers.lua")
local world = H.new()
local spells = world:loadReactive("Services/ReactiveSpells").ReactiveSpells
spells.Rebuild()

H.equal(spells.Evaluate("mongoose").ready, true, "usable Mongoose with no cooldown glows")
H.equal(spells.Evaluate("counterattack").ready, true, "usable Counterattack glows")

world.cooldowns[1495] = { isActive = true, startTime = 100, duration = 1.5 }
world.cooldowns[61304] = { isActive = true, startTime = 100, duration = 1.5 }
H.equal(spells.Evaluate("mongoose").ready, true, "matching GCD does not block")

world.cooldowns[1495] = { isActive = true, startTime = 99, duration = 5 }
H.equal(spells.Evaluate("mongoose").ready, true, "Mongoose opportunity ignores its own cooldown like Overpower")

world.cooldowns[1495] = { isActive = true, startTime = world.secret, duration = world.secret }
H.equal(spells.Evaluate("mongoose").ready, true, "unknown cooldown does not suppress a known Mongoose opportunity")

world.cooldowns[1495] = { isActive = false }
world.cooldowns[61304] = nil
world.usable[1495] = false
world.lowPower[1495] = true
H.equal(spells.Evaluate("mongoose").ready, true, "insufficient power preserves the opportunity")

world.lowPower[1495] = false
H.equal(spells.Evaluate("mongoose").ready, false, "missing opportunity clears")

world.usable[1495] = true
H.equal(spells.Evaluate("mongoose").ready, true)
spells.ReactiveCast("player", 1495)
H.equal(spells.Evaluate("mongoose").ready, false, "cast immediately clears stale usability")

world.time = 107
H.equal(spells.Evaluate("mongoose").ready, true, "next valid proc cannot be permanently consumed")

world.cooldowns[1495] = { isActive = true, isOnGCD = true,
    startTime = world.secret, duration = world.secret }
spells.ObserveCooldownEvent()
H.equal(spells.Evaluate("mongoose").ready, true, "event GCD evidence allows unknown timing")

world.usable[1495] = false
H.equal(spells.Evaluate("mongoose").ready, true, "brief GCD usability loss preserves observed proc")

world.time = 109
H.equal(spells.Evaluate("mongoose").ready, false, "GCD evidence cannot retain proc indefinitely")

world.usable[1495] = true
spells.ObserveCooldownEvent()
world.env.C_Spell.GetSpellCooldownDuration = function()
    return { HasSecretValues = function() return false end, IsZero = function() return false end,
        HasExpired = function() return false end }
end
H.equal(spells.Evaluate("mongoose").ready, true, "Mongoose opportunity also ignores a readable own duration object")

world.env.C_Spell.GetSpellCooldownDuration = nil
world.cooldowns[1495] = { isActive = false }
world.usable[1495] = world.secret
world.secret[world.secret] = true
H.equal(spells.Evaluate("mongoose").ready, false, "secret usability cannot invent a proc")

world.learned = { 14269, 14269 }
world.usable[14269] = true
world.cooldowns[14269] = { isActive = false }
spells.Rebuild()
H.equal(spells.Evaluate("mongoose").id, 14269, "localized learned higher rank is used")
H.equal(#spells.ids.mongoose, 1, "duplicate ranks excluded")
H.equal(spells.Evaluate("counterattack").ready, false, "unlearned spell stays dark")

local ownWorld = H.new()
local ownSpells = ownWorld:loadReactive("Services/ReactiveSpells").ReactiveSpells
ownSpells.Rebuild()
ownWorld.cooldowns[61304] = { isActive = true, startTime = 100, duration = 1.5 }
ownWorld.cooldowns[19306] = { isActive = true, isOnGCD = true, startTime = 100, duration = 5 }
ownSpells.ObserveCooldownEvent()
H.equal(ownSpells.Evaluate("counterattack").ready, false, "raw own cooldown outranks event GCD flag")

ownWorld.env.C_Spell.GetSpellCooldownDuration = function()
    return { HasSecretValues = function() return true end }
end
ownSpells.ObserveCooldownEvent()
H.equal(ownSpells.Evaluate("counterattack").ready, false, "raw own cooldown outranks event even with secret duration object")

ownWorld.cooldowns[19306] = { isActive = true, startTime = ownWorld.secret, duration = ownWorld.secret }
local learnedCounterattack = ownSpells.Evaluate("counterattack")
H.equal(learnedCounterattack.ready, false, "Counterattack still needs known cooldown readiness")

ownWorld.cooldowns[19306] = { isActive = true, startTime = 100, duration = 1.5 }
ownWorld.env.C_Spell.GetSpellCooldownDuration = nil
H.equal(ownSpells.Evaluate("counterattack").ready, true, "Counterattack still allows a matching GCD")

print("hunter reactive spells passed")
