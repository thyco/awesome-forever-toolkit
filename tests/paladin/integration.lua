local H = dofile('tests/helpers.lua')
local world = H.new()
world.class = 'PALADIN'
local root = world:loadManifest()
world:fire('PLAYER_LOGIN')

assert(root.modules.Paladin, 'Paladin module must be registered')
assert(root.modules.Paladin.active, 'Paladin starts on its own class')
assert(root.Window.pages['paladin.abilities'], 'ability page is registered')
assert(root.Window.pages['paladin.reminders'], 'reminder page is registered')
local config = root.modules.Paladin.Config
assert(config.Get('holyStrikeBar') == 3)
assert(config.Get('sealReminderSeconds') == 25)
assert(config.Get('holyStrikeGamepadPage') == 0)
assert(world.env.AwesomeForeverToolkitDB.paladin)
assert(not world.env.PaladinAssistForeverDB, 'no legacy settings migration')

config.Set('sealReminderSeconds', 20)
assert(root.Window.reloadRequired, 'class settings require reload on close')
root.Window:ShowPage('paladin.abilities')
root.Window:ShowPage('paladin.reminders')

local other = H.new()
other.class = 'HUNTER'
local otherRoot = other:loadManifest()
other:fire('PLAYER_LOGIN')
assert(not otherRoot.modules.Paladin.active)
print('paladin integration: PASS')
