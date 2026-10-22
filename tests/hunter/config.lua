local H = dofile("tests/fixtures/hunter/helpers.lua")

local world = H.new()
world.env.HunterAssistForeverDB = {mongooseBar = 8, ammoWarnBelow = 100}
local hunter = world:load("Services/Config")
hunter.Config.Initialize()

assert(hunter.Config.Get("mongooseBar") == 3, "legacy settings must not be imported")
assert(hunter.Config.Get("mongooseGamepadPage") == 0)
assert(hunter.Config.CanSet("mongooseGamepadPage", 3))
assert(not hunter.Config.CanSet("mongooseGamepadPage", 4))
assert(hunter.Config.CanSet("counterattackGamepadButton", 8))
assert(not hunter.Config.CanSet("counterattackGamepadButton", 9))
assert(hunter.Config.CanSet("counterattackGamepadBar", 4))
assert(not hunter.Config.CanSet("counterattackGamepadBar", 5))
assert(not hunter.Config.CanSet("ammoWarnBelow", 400))
assert(not hunter.Config.CanSet("ammoWarnBelow", world.secret))

hunter.Config.Set("mongooseGamepadPage", 2)
hunter.Config.Set("ammoWarnBelow", 150)
hunter.Config.Set("mongooseGlowColor", "801234AB")

assert(world.env.AwesomeForeverToolkitDB.hunter.mongooseGamepadPage == 2)
assert(hunter.Config.Get("mongooseGlowColor") == "ff1234ab")
assert(world.env.HunterAssistForeverDB.mongooseBar == 8)
assert(world.env.HunterAssistForeverDB.ammoWarnBelow == 100)

hunter.Config.ResetAmmoThresholds()

assert(hunter.Config.Get("ammoWarnBelow") == 200)
assert(hunter.Config.Get("mongooseGamepadPage") == 2)
print("hunter config: PASS")
