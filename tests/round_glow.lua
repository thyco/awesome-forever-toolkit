-- The frame double records rendering commands; all selection and geometry run in production.
local combat, allocations = false, 0
local function newFrame()
    local frame = { lines = {}, width = 40, height = 40, level = 1 }
    function frame:SetAllPoints(region) self.anchor = region end
    function frame:GetSize() return self.width, self.height end
    function frame:GetFrameLevel() return self.level end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:EnableMouse() end
    function frame:SetScript(event, callback) self[event] = callback end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:CreateTexture()
        assert(not combat, 'no texture allocation in combat')
        allocations = allocations + 1
        local texture = {}
        function texture:SetBlendMode(value) self.blend = value end
        function texture:SetTexture(value) self.path = value end
        function texture:SetVertexColor(...) self.color = {...} end
        function texture:SetPoint(...) self.point = {...} end
        function texture:SetSize(width, height) self.width, self.height = width, height end
        return texture
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
local dpad = newFrame()
dpad.CircleMask = newFrame()
env.GamepadMainActionBarFrame = { PageUnit = { actionBars = {
    topBar = { actionButtons = { dpad, nil, nil, nil, button } },
} } }
assert(not root.RoundGlow.IsRound(dpad), 'D-pad remains square even with inherited CircleMask')
assert(root.RoundGlow.IsRound(button), 'Face button is round')
assert(not root.RoundGlow.IsRound({ CircleMask = newFrame() }), 'mask alone does not imply round')
local entry = root.Glow.Prepare(button)
root.Glow.Set(button, 'proc', true)

assert(entry.round.frame.anchor == button.CircleMask, 'ring follows inset mask')
local line = assert(entry.round.texture, 'smooth circle uses a texture rather than segmented lines')
assert(math.abs(line.width - 24 * 1.6) < 0.001 and line.width == line.height, 'ring radius uses inset, not square bounds')
assert(entry.round.frame.shown)
assert(line.blend == 'ADD' and line.path:find('RoundGlow', 1, true), 'soft additive halo extends beyond the edge')
assert(entry.round.frame.OnUpdate, 'round glow animates while visible')
entry.round.frame:OnUpdate(0.2)
local firstAlpha = entry.round.frame.alpha
entry.round.frame:OnUpdate(0.1)
assert(firstAlpha ~= entry.round.frame.alpha, 'glow brightness pulses')
assert(line.color[1] > 0.9 and line.color[2] > 0.6, 'native proc is golden')

root.Glow.ConfigureOwner('custom', {priority = 10, color = {1, 0, 0, 1}})
root.Glow.Set(button, 'custom', true)
assert(line.color[1] == 1 and line.color[2] == 0)
root.Glow.ClearOwner('custom')
assert(line.color[2] > 0.6, 'remaining proc owner restores golden color')

button.CircleMask.width, button.CircleMask.height = 40, 32
root.Glow.RefreshGeometry(button)
assert(math.abs(line.width - 32 * 1.6) < 0.001, 'non-square region keeps circular texture at the smaller diameter')
local originalGetSize = button.CircleMask.GetSize
button.CircleMask.GetSize = function() error("unavailable dimensions") end
assert(pcall(root.Glow.RefreshGeometry, button))
button.CircleMask.GetSize = function() return 0 / 0, math.huge end
assert(pcall(root.Glow.RefreshGeometry, button))
assert(math.abs(line.width - 32 * 1.6) < 0.001, 'invalid dimensions preserve last valid geometry')
button.CircleMask.GetSize = originalGetSize

root.Glow.ClearOwner('proc')
assert(not entry.round.frame.shown)

local visual = newFrame()
visual.aftRound = true
local queued = root.modules.Utilities.QueuedGlow.Prepare(visual)
root.modules.Utilities.QueuedGlow.Set(visual, true)
assert(queued.round.frame.anchor == visual)
assert(queued.round.texture.color[3] == 1, 'queued custom color retained')
color = {1, 0.2, 0, 1}
root.modules.Utilities.QueuedGlow.SetColor()
assert(queued.round.texture.color[2] == 0.2)
visual.width, visual.height = 60, 60
root.modules.Utilities.QueuedGlow.Set(visual, true)
assert(math.abs(queued.round.texture.width - 60 * 1.6) < 0.001, 'active queued ring follows expansion')

local preparedAllocations = allocations
combat = true
root.Glow.Set(button, 'proc', true)
root.modules.Utilities.QueuedGlow.Clear()
assert(not queued.round.frame.shown)
root.modules.Utilities.QueuedGlow.Set(visual, true)
assert(allocations == preparedAllocations, 'combat activation reuses prepared texture')
local unprepared = newFrame()
unprepared.aftRound = true
assert(root.Glow.Prepare(unprepared) == nil)
assert(root.modules.Utilities.QueuedGlow.Prepare(unprepared) == nil)
print('round_glow: PASS')
