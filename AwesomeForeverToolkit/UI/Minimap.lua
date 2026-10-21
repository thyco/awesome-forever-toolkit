local _, addon = ...
local MinimapButton = {}
addon.Minimap = MinimapButton

function MinimapButton:SaveAngle(angle)
    if not addon.Client.Number(angle) then angle = 225 end
    addon.Config.GetSection("character", "ui").minimapAngle = angle % 360
    self:Refresh()
end

function MinimapButton:Refresh()
    if not self.button then return end
    local state = addon.Config.GetSection("character", "ui")
    if not addon.Client.Number(state.minimapAngle) then state.minimapAngle = 225 end
    state.minimapAngle = state.minimapAngle % 360

    local radians = math.rad(state.minimapAngle)
    local radius = math.max(Minimap:GetWidth(), Minimap:GetHeight()) / 2 + 10
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
    self.button:SetShown(state.minimapHidden ~= true)
end

function MinimapButton:Initialize()
    if self.button or not Minimap then return end

    local button = CreateFrame("Button", nil, Minimap)
    self.button = button
    button:SetSize(34, 34)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetNormalTexture("Interface\\AddOns\\AwesomeForeverToolkit\\Media\\Icon.tga")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function() addon.Window:Open() end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Awesome Forever Toolkit")
        GameTooltip:AddLine("Click to open settings. Drag to move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            if not centerX or not centerY or not scale or scale <= 0 then return end

            local dx, dy = x / scale - centerX, y / scale - centerY
            -- Lua 5.1 clients expose atan2; Lua 5.4 tests use two-argument atan.
            local radians = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
            self:SaveAngle(math.deg(radians))
        end)
    end)
    button:SetScript("OnDragStop", function() button:SetScript("OnUpdate", nil) end)
    button:SetScript("OnHide", function() button:SetScript("OnUpdate", nil) end)
    self:Refresh()
end
