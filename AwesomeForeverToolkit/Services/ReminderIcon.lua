local _, root = ...
local Icon = {}
root.ReminderIcon = Icon

-- Reusable, aura-independent popup. Callers own settings and visibility decisions.
function Icon.New(options)
    local instance = setmetatable({ options = options, preview = false, visible = false }, { __index = Icon })
    instance:Initialize()
    return instance
end

function Icon:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", self.options.name, UIParent)
    self.frame = frame
    frame:SetSize(64, 64)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    self.texture = frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints(frame)
    self.texture:SetTexture(self.options.texture)
    frame:SetScript("OnDragStart", function(target)
        if self.preview and not root.Client.InCombat() and not InCombatLockdown() then
            target:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(target)
        target:StopMovingOrSizing()

        local x, y = target:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if root.Client.Number(x) and root.Client.Number(y)
            and root.Client.Number(centerX) and root.Client.Number(centerY) then
            self.options.onMoved(math.max(-4096, math.min(4096, x - centerX)),
                math.max(-4096, math.min(4096, y - centerY)))
        end
    end)

    root.Glow.Prepare(frame)
    frame:Hide()
end

function Icon:ApplySettings(settings)
    self.settings = settings
    if not self.frame then
        return
    end

    local size = settings.size
    local resized = self.size ~= size
    self.size = size
    self.frame:SetSize(size, size)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
    self.texture:SetAlpha(settings.hideArtwork and 0 or 1)

    self.texture:SetDesaturated(settings.underlay == true)
    -- Clip the animated glow to the same rectangle an opaque aura icon covers.
    self.frame:SetClipsChildren(settings.underlay == true)
    self.frame:SetFrameStrata(self.preview and "TOOLTIP" or settings.underlay and "BACKGROUND" or "DIALOG")

    root.Glow.ConfigureOwner(self.options.owner, { color = settings.color })
    root.Glow.Prepare(self.frame)
    if resized then
        root.Glow.RefreshGeometry(self.frame)
    end

    self:Render()
end

function Icon:SetVisible(visible)
    self.visible = visible
    self:Render()
end

function Icon:SetPreview(enabled)
    self.preview = enabled and not root.Client.InCombat() and not InCombatLockdown() and self.options.canPreview()
    if not self.frame then
        return
    end

    if not self.preview then
        self.frame:StopMovingOrSizing()
    end

    self.frame:SetFrameStrata(self.preview and "TOOLTIP" or self.settings.underlay and "BACKGROUND" or "DIALOG")
    self.frame:EnableMouse(self.preview)
    self:Render()
end

function Icon:Render()
    if not self.frame then
        return
    end

    local visible = self.preview or self.visible
    self.frame:SetShown(visible)
    root.Glow.Set(self.frame, self.options.owner, visible)
end
