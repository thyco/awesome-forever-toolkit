local H = dofile("tests/helpers.lua")

local world = H.new()
world.class = "HUNTER"
local root = world:loadManifest()
assert(root.modules.Hunter, "Hunter module must be in the manifest")
world:fire("PLAYER_LOGIN")

local hunter = root.modules.Hunter
assert(hunter.active and hunter.started)
assert(not root.modules.Warrior.active)
assert(hunter.Client == root.Client and hunter.Buttons == root.Buttons and hunter.Glow == root.Glow)
assert(root.Window:ShowPage("hunter.reactive"))
assert(root.Window.controls["hunter.mongooseGamepadButton"])
assert(root.Window.controls["hunter.counterattackGamepadPage"])
assert(root.Window.controls["hunter.mongooseGamepadButton"].menuGenerator == nil,
    "Hunter configuration must avoid Blizzard's gamepad menu focus path")

root.Window.settings["hunter.mongooseGamepadButton"]:SetValue(8)
assert(hunter.Config.Get("mongooseGamepadButton") == 8)
assert(world.env.AwesomeForeverToolkitDB.hunter.mongooseGamepadButton == 8)
assert(root.Window.reloadRequired)
assert(root.Window:ShowPage("hunter.reminders"))
local warning = root.Window.controls["hunter.ammoWarnBelow"]
assert(warning)
warning:SetText("450")
warning.scripts.OnEnterPressed(warning)
assert(hunter.Config.Get("ammoWarnBelow") == 200, "invalid threshold ordering must be rejected")
warning:SetText("150")
warning.scripts.OnEnterPressed(warning)
assert(hunter.Config.Get("ammoWarnBelow") == 150)
root.Window.controls["hunter.moveAmmo"].scripts.OnClick()
assert(hunter.AmmoIcon.preview)

assert(root.Window:ShowPage("gamepad.bindings"))
assert(not hunter.AmmoIcon.preview)

root.Window:ShowPage("hunter.reactive")
local pageChoice = root.Window.controls["hunter.mongooseGamepadPage"]
pageChoice.scripts.OnClick()
assert(pageChoice.popup:IsShown())
pageChoice.choices[3].scripts.OnClick()
assert(hunter.Config.Get("mongooseGamepadPage") == 2)
assert(not pageChoice.popup:IsShown())

world.env.SlashCmdList.AWESOMEFOREVERTOOLKIT("hunter")
assert(table.concat(world.messages, "\n"):find("Mongoose Bite:", 1, true), "Hunter diagnostics must be accessible")

local blockedWorld = H.new()
blockedWorld.class = "HUNTER"
blockedWorld.loaded.HunterAssistForever = true
local blockedRoot = blockedWorld:loadManifest()
blockedWorld:fire("PLAYER_LOGIN")
assert(not blockedRoot.modules.Hunter.active)
assert(not blockedRoot.Window:ShowPage("hunter.reactive"))
assert(blockedRoot.modules.Gamepad.active)


local warriorWorld = H.new()
local warriorRoot = warriorWorld:loadManifest()
warriorWorld:fire("PLAYER_LOGIN")
assert(not warriorRoot.modules.Hunter.active)
assert(not warriorRoot.Window:ShowPage("hunter.reminders"))
print("hunter integration: PASS")
