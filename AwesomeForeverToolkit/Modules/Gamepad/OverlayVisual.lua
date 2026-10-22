local _, root = ...
local addon = root.modules.Gamepad
local Visual = {}
addon.OverlayVisual = Visual
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

function Visual.Create(native)
    -- Only addon-owned visuals are changed, never protected Blizzard frames.
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata(native:GetFrameStrata())
    frame:SetFrameLevel(native:GetFrameLevel() + 5)
    frame:EnableMouse(false)
    frame.aftRound = true

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints()
    frame.background:SetColorTexture(0, 0, 0, 1)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    -- Spell textures include a square edge; crop it before the circular mask.
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.mask = frame:CreateMaskTexture()
    frame.mask:SetAllPoints()
    frame.mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.background:AddMaskTexture(frame.mask)
    frame.icon:AddMaskTexture(frame.mask)

    -- The override covers Blizzard's original checked texture. Mirror current
    -- spell state on our own masked texture; never alter the native button.
    frame.checked = frame:CreateTexture(nil, "OVERLAY")
    frame.checked:SetAllPoints()
    frame.checked:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    frame.checked:SetBlendMode("ADD")
    frame.checked:AddMaskTexture(frame.mask)
    frame.checked:Hide()

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    frame.cooldown:EnableMouse(false)
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetDrawBling(false)
    frame.cooldown:SetSwipeTexture(CIRCLE)
    frame:Hide()
    return frame
end

function Visual.Sync(frame, native)
    -- CircleMask describes the inset visible area. Its dimensions use the
    -- native button's coordinates, while our unprotected frame lives on UIParent.
    local region = native.CircleMask
    if not region then return false end

    local width, height = region:GetSize()
    local parentScale = UIParent:GetEffectiveScale()
    if not width or not height or width <= 0 or height <= 0 or parentScale <= 0 then return false end
    local scale = native:GetEffectiveScale() / parentScale
    if scale <= 0 then return false end

    if frame.anchorRegion ~= region or frame.iconWidth ~= width or frame.iconHeight ~= height or frame.iconScale ~= scale then
        frame:SetScale(scale)
        frame:SetSize(width, height)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", region, "CENTER", 0, 0)
        frame.anchorRegion, frame.iconWidth, frame.iconHeight, frame.iconScale = region, width, height, scale
    end
    return true
end
