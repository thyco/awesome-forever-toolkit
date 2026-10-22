local _, root = ...
local RoundGlow = {}
root.RoundGlow = RoundGlow

local nativeColor = { 1, 0.82, 0.25, 1 }
local segments = 48
local methods = {}

function RoundGlow.IsRound(button)
    return button.CircleMask ~= nil or button.aftRound == true
end

function methods:SetColor(color)
    color = color or nativeColor
    for _, line in ipairs(self.lines) do
        line:SetColorTexture(color[1], color[2], color[3], (color[4] or 1) * line.glowAlpha)
    end
end

function methods:RefreshGeometry()
    local ok, width, height = pcall(self.region.GetSize, self.region)
    if not ok or not root.Client.Number(width) or not root.Client.Number(height)
        or width <= 0 or height <= 0 then
        return
    end

    if width == self.width and height == self.height then return end
    self.width, self.height = width, height
    local radius = math.min(width, height) / 2

    for index, line in ipairs(self.lines) do
        local segment = (index - 1) % segments
        local angle = segment * math.pi * 2 / segments
        local nextAngle = (segment + 1) * math.pi * 2 / segments
        line:SetStartPoint('CENTER', self.frame, math.cos(angle) * radius, math.sin(angle) * radius)
        line:SetEndPoint('CENTER', self.frame, math.cos(nextAngle) * radius, math.sin(nextAngle) * radius)
    end
end

function methods:SetActive(active)
    if active then
        self:RefreshGeometry()
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function RoundGlow.Create(parent, button)
    if InCombatLockdown() then return nil end
    button = button or parent

    local region = button.CircleMask or button
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetAllPoints(region)
    frame:EnableMouse(false)
    frame:Hide()

    local renderer = setmetatable({ frame = frame, region = region, lines = {} }, { __index = methods })
    -- A soft outer band and narrow core form a ring without square proc artwork.
    -- All regions are reserved before combat; only addon-owned lines are changed.
    for layer = 1, 2 do
        for _ = 1, segments do
            local line = frame:CreateLine(nil, 'OVERLAY')
            line:SetThickness(layer == 1 and 5 or 2)
            line.glowAlpha = layer == 1 and 0.22 or 1
            renderer.lines[#renderer.lines + 1] = line
        end
    end

    renderer:SetColor()
    renderer:RefreshGeometry()
    return renderer
end
