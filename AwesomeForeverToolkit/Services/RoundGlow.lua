local _, root = ...
local RoundGlow = {}
root.RoundGlow = RoundGlow

local nativeColor = { 1, 0.82, 0.25, 1 }
local methods = {}

local function field(object, key)
    if not root.Client.Readable(object) or type(object) ~= 'table' then return nil end

    local ok, value = pcall(function() return object[key] end)
    if ok and root.Client.Readable(value) then return value end
end

function RoundGlow.IsRound(button)
    if field(button, 'aftRound') == true then return true end

    -- Both native shapes can inherit CircleMask. The bar position, rather than
    -- the existence of that texture, identifies Face buttons (slots 5 through 8).
    local bars = field(field(GamepadMainActionBarFrame, 'PageUnit'), 'actionBars')
    for _, key in ipairs({ 'topBar', 'leftBar', 'rightBar', 'bottomBar', 'stanceBar', 'possessBar' }) do
        local buttons = field(field(bars, key), 'actionButtons')
        for index = 5, 8 do
            if field(buttons, index) == button then return true end
        end
    end

    return false
end

function methods:SetColor(color)
    color = color or nativeColor
    self.texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

function methods:RefreshGeometry()
    local ok, width, height = pcall(self.region.GetSize, self.region)
    if not ok or not root.Client.Number(width) or not root.Client.Number(height)
        or width <= 0 or height <= 0 then
        return
    end

    if width == self.width and height == self.height then return end
    self.width, self.height = width, height

    -- The texture's luminous radius is 80 in a 256px canvas. Keep it square,
    -- including when the native region is rectangular, and center on the icon.
    local size = math.min(width, height) * 256 / 160
    self.texture:SetSize(size, size)
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

    local texture = frame:CreateTexture(nil, 'OVERLAY')
    texture:SetTexture("Interface\\AddOns\\AwesomeForeverToolkit\\Media\\RoundGlow.tga")
    texture:SetBlendMode('ADD')
    texture:SetPoint('CENTER', frame, 'CENTER', 0, 0)

    local renderer = setmetatable({ frame = frame, region = region, texture = texture }, { __index = methods })
    local elapsed = 0
    frame:SetScript('OnUpdate', function(self, delta)
        elapsed = (elapsed + delta) % 1.4
        self:SetAlpha(0.8 + 0.2 * math.sin(elapsed * math.pi * 2 / 1.4))
    end)

    renderer:SetColor()
    renderer:RefreshGeometry()
    return renderer
end
