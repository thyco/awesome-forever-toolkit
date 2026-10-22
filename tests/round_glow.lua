-- The frame double records rendering commands; all selection and geometry run in production.
local combat, allocations = false, 0
local function newFrame()
    local frame = { lines = {}, width = 40, height = 40, level = 1 }
    function frame:SetAllPoints(region) self.anchor = region end
    function frame:GetSize() return self.width, self.height end
    function frame:GetFrameLevel() return self.level end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:EnableMouse() end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:CreateLine()
        assert(not combat, 'no line allocation in combat')
        allocations = allocations + 1
        local line = {}
        function line:SetThickness(value) self.thickness = value end
        function line:SetColorTexture(...) self.color = {...} end
        function line:SetStartPoint(_, _, x, y) self.x, self.y = x, y end
        function line:SetEndPoint(_, _, x, y) self.endX, self.endY = x, y end
        self.lines[#self.lines + 1] = line
        return line
    end
    return frame
end
local env = setmetatable({
    InCombatLockdown = function() return combat end,
    CreateFrame = function() assert(not combat); return newFrame() end,
    LibStub = function() return {} end,
}, {__index = _G})
local color = {0.15, 0.85, 1, 1}
local root = { modules = { Utilities = { Config = {
    Get = function() return false end,
    GetColor = function() return color end,
} } }, Client = { Number = function(value) return type(value) == 'number' end } }
assert(loadfile('AwesomeForeverToolkit/Services/Client.lua', 't', env))('AwesomeForeverToolkit', root)
local renderer = loadfile('AwesomeForeverToolkit/Services/RoundGlow.lua', 't', env)
assert(renderer, 'round renderer must exist')
renderer('AwesomeForeverToolkit', root)
assert(loadfile('AwesomeForeverToolkit/Services/Glow.lua', 't', env))('AwesomeForeverToolkit', root)
assert(loadfile('AwesomeForeverToolkit/Modules/Utilities/Services/QueuedGlow.lua', 't', env))('AwesomeForeverToolkit', root)

local button = newFrame()
button.CircleMask = newFrame()
button.CircleMask.width, button.CircleMask.height = 24, 24
local entry = root.Glow.Prepare(button)
root.Glow.Set(button, 'proc', true)

assert(entry.round.frame.anchor == button.CircleMask, 'ring follows inset mask')
local line = entry.round.frame.lines[1]
assert(math.abs(line.x - 12) < 0.001 and math.abs(line.y) < 0.001, 'ring radius uses inset, not square bounds')
assert(entry.round.frame.shown)
assert(line.color[1] > 0.9 and line.color[2] > 0.6, 'native proc is golden')

root.Glow.ConfigureOwner('custom', {priority = 10, color = {1, 0, 0, 1}})
root.Glow.Set(button, 'custom', true)
assert(line.color[1] == 1 and line.color[2] == 0)
root.Glow.ClearOwner('custom')
assert(line.color[2] > 0.6, 'remaining proc owner restores golden color')

button.CircleMask.width, button.CircleMask.height = 32, 32
root.Glow.RefreshGeometry(button)
assert(math.abs(line.x - 16) < 0.001, 'geometry follows mask resizing')
local originalGetSize = button.CircleMask.GetSize
button.CircleMask.GetSize = function() error("unavailable dimensions") end
assert(pcall(root.Glow.RefreshGeometry, button))
button.CircleMask.GetSize = function() return 0 / 0, math.huge end
assert(pcall(root.Glow.RefreshGeometry, button))
assert(math.abs(line.x - 16) < 0.001, 'invalid dimensions preserve last valid geometry')
button.CircleMask.GetSize = originalGetSize

root.Glow.ClearOwner('proc')
assert(not entry.round.frame.shown)

local visual = newFrame()
visual.aftRound = true
local queued = root.modules.Utilities.QueuedGlow.Prepare(visual)
root.modules.Utilities.QueuedGlow.Set(visual, true)
assert(queued.round.frame.anchor == visual)
assert(queued.round.frame.lines[1].color[3] == 1, 'queued custom color retained')
color = {1, 0.2, 0, 1}
root.modules.Utilities.QueuedGlow.SetColor()
assert(queued.round.frame.lines[1].color[2] == 0.2)
visual.width, visual.height = 60, 60
root.modules.Utilities.QueuedGlow.Set(visual, true)
assert(math.abs(queued.round.frame.lines[1].x - 30) < 0.001, 'active queued ring follows expansion')

local preparedAllocations = allocations
combat = true
root.Glow.Set(button, 'proc', true)
root.modules.Utilities.QueuedGlow.Clear()
assert(not queued.round.frame.shown)
root.modules.Utilities.QueuedGlow.Set(visual, true)
assert(allocations == preparedAllocations, 'combat activation reuses prepared lines')
local unprepared = newFrame()
unprepared.aftRound = true
assert(root.Glow.Prepare(unprepared) == nil)
assert(root.modules.Utilities.QueuedGlow.Prepare(unprepared) == nil)
print('round_glow: PASS')
