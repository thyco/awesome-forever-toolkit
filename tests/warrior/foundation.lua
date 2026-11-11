local H = dofile("tests/warrior/helpers.lua")
local world = H.new()
local addon = world:load({ "Core", "Services/Config", "Services/Client" })

addon.Config.Initialize()
H.equal(addon.Config.Get("iconSize"), 36)
H.equal(addon.Config.Get("glowColor"), "ff00ff00")
H.equal(addon.Config.Get("iconX"), 0)
H.equal(addon.Config.Get("iconY"), -270)

local invalid = H.new()
invalid.env.AwesomeForeverToolkitDB.warrior = { iconSize = 61, glowColor = "bad", iconX = math.huge }
local other = invalid:load({ "Core", "Services/Config", "Services/Client" })
other.Config.Initialize()
H.equal(other.Config.Get("iconSize"), 36)
H.equal(other.Config.Get("glowColor"), "ff00ff00")
H.equal(other.Config.Get("iconX"), 0)

local changes = 0
other.Config.Subscribe(function(key, value)
    changes = changes + 1
    H.equal(key, "iconSize")
    H.equal(value, 48)
end)
other.Config.Set("iconSize", 48)
H.equal(changes, 1)
H.equal(other.Config.Get("iconSize"), 48)

local color = other.Config.GetColor("glowColor")
H.equal(color[1], 0)
H.equal(color[2], 1)
H.equal(color[3], 0)
H.equal(color[4], 1)

H.equal(other.Client.IsWarrior(), true)
invalid.class = "PALADIN"
H.equal(other.Client.IsWarrior(), false)
H.equal(other.Client.InCombat(), false)
invalid.combat = true
H.equal(other.Client.InCombat(), true)
H.equal(other.Client.Number(math.huge), nil)
H.equal(other.Client.Number(42), 42)

local secret = {}
invalid.secret[secret] = true
H.equal(other.Client.Readable(secret), false)
H.equal(other.Client.Number(secret), nil, "secret number rejected")

invalid.combat = secret
invalid.class = secret

H.equal(other.Client.InCombat(), false, "secret combat result rejected")
H.equal(other.Client.IsWarrior(), false, "secret class result rejected")

-- Secret values with otherwise valid types must also fail closed.
invalid.secret[42] = true
invalid.secret[true] = true
invalid.secret["WARRIOR"] = true
invalid.combat = true
invalid.class = "WARRIOR"

H.equal(other.Client.Number(42), nil, "secret numeric scalar rejected")
H.equal(other.Client.InCombat(), false, "secret true combat result rejected")
H.equal(other.Client.IsWarrior(), false, "secret Warrior token rejected")

print("foundation: PASS")
