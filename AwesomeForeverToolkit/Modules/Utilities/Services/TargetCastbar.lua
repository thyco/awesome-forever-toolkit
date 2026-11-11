local _, root = ...
local addon = root.modules.Utilities
local Mover = { records = {}, applying = false, running = false }
addon.TargetCastbar = Mover
local defaults = { enabled = false, x = 0.5, y = 0.38, scale = 100 }
local store
local unpack = unpack or table.unpack

local function inCombat()
    return InCombatLockdown() or root.Client.InCombat()
end

local function valid(key, value)
    if key == "enabled" then return type(value) == "boolean" end
    if not root.Client.Number(value) then return false end

    if key == "scale" then return value >= 50 and value <= 300 and value % 5 == 0 end
    return value >= 0 and value <= 1
end

local function settings()
    if not store then
        store = root.Config.NewStore("account", "targetCastbar", defaults, valid)
        store.Subscribe(function() Mover:Apply() end)
    end
    return store
end

function Mover.Get(key) return settings().Get(key) end
function Mover.GetDefault(key) return defaults[key] end
function Mover.Set(key, value) return settings().Set(key, value) end

function Mover:PositionAnchor()
    local x = self.Get("x") * UIParent:GetWidth()
    local y = self.Get("y") * UIParent:GetHeight()
    self.anchorPosition = { x = x, y = y }
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

function Mover:SavePosition()
    local x, y = self.anchor:GetCenter()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not root.Client.Number(x) or not root.Client.Number(y) or width <= 0 or height <= 0 then return end

    -- Snapshot both coordinates before setting either: settings callbacks reanchor the frame.
    local scale = self.anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    x, y = x * scale / width, y * scale / height
    self.Set("x", math.max(0, math.min(1, x)))
    self.Set("y", math.max(0, math.min(1, y)))
end

function Mover:ClosePreview()
    if not self.anchor then return end

    self.anchor:StopMovingOrSizing()
    self.dragging = false
    self.anchor:EnableMouse(false)
    if self.preview then self.preview:Hide() end
    if not inCombat() then
        self:PositionAnchor()
    elseif self.anchorPosition and not self.anchor:IsProtected() then
        -- Discard an interrupted drag without consuming pending settings changes.
        self.anchor:ClearAllPoints()
        self.anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.anchorPosition.x, self.anchorPosition.y)
    end
end

function Mover:CreateAnchor()
    if self.anchor then return end

    local anchor = CreateFrame("Frame", "AwesomeForeverToolkitTargetCastbarAnchor", UIParent)
    self.anchor = anchor
    anchor:SetSize(206, 44)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:SetFrameStrata("DIALOG")
    anchor:EnableMouse(false)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function()
        if not inCombat() and self.preview and self.preview:IsShown() then
            self.dragging = true
            anchor:StartMoving()
        end
    end)
    anchor:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        if not self.dragging then return end

        self.dragging = false
        if not inCombat() then self:SavePosition() end
    end)
    self:PositionAnchor()
end

function Mover:SyncPreview()
    if not self.preview or not self.preview:IsShown() or not self.bar then return end

    local bar, preview = self.bar, self.preview
    local scale = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
    preview:SetSize(bar:GetWidth(), bar:GetHeight())
    preview:SetScale(scale)
    preview.classicStyleCastBar = bar.classicStyleCastBar
    if bar.look and preview.SetLook then preview:SetLook(bar.look) end
    preview.showIcon = bar.showIcon ~= false
    preview.Icon:SetShown(preview.showIcon)
    preview:UpdateBarFillTexture(false)
    self.anchor:SetSize(math.max(60, (bar:GetWidth() + 56) * scale),
        math.max(32, (bar:GetHeight() + 34) * scale))
end

function Mover:Preview()
    if inCombat() then return false, "Leave combat before positioning the target castbar." end
    if not self.Get("enabled") then return false, "Enable target castbar positioning first." end
    self:Apply()
    if self.conflict then return false, "Disable ForeverTargetCastbar and reload first." end
    if self.lastError then return false, "Could not position the target castbar: " .. self.lastError end
    if not self.bar then return false, "Blizzard's target castbar is not available yet." end

    if not self.preview then
        -- Synthetic data only ever reaches our own preview; the live bar stays Blizzard-owned.
        local preview = CreateFrame("StatusBar", nil, self.anchor, "TargetSpellBarTemplate")
        self.preview = preview
        preview:UnregisterAllEvents()
        preview:SetScript("OnEvent", nil)
        preview:SetScript("OnShow", nil)
        preview:SetScript("OnUpdate", nil)
        preview:StopAnims()
        preview:SetPoint("CENTER", self.anchor, "CENTER", 0, 0)
        preview:EnableMouse(false)
        preview:SetMinMaxValues(0, 1)
        preview:SetValue(0.65)
        preview.barType = CastingBarType.Standard
        preview.Text:SetText("Target castbar preview")
        preview.Icon:SetTexture(135812)
        preview.BorderShield:Hide()
        preview.Flash:Hide()
        preview.Spark:Hide()
        preview:SetAlpha(1)
    end

    self.preview:Show()
    self.anchor:EnableMouse(true)
    self:SyncPreview()
    return true
end

function Mover:Capture(bar)
    local record = self.records[bar]
    if not record then
        record = {}
        self.records[bar] = record
        local function changed()
            if not self.running or self.bar ~= bar or self.applying then return end
            if inCombat() then self:MaintainPosition() else self:Apply() end
        end
        hooksecurefunc(bar, "SetPoint", changed)
        hooksecurefunc(bar, "SetScale", changed)
        bar:HookScript("OnShow", changed)
        local parent = bar:GetParent()
        if parent then hooksecurefunc(parent, "SetScale", changed) end
    end
    if not record.moved then
        record.points = {}
        for index = 1, bar:GetNumPoints() do
            record.points[index] = { bar:GetPoint(index) }
        end
        record.scale = bar:GetScale()
    end
    return record
end

function Mover:Restore(bar)
    local record = bar and self.records[bar]
    if not record or not record.moved then return end

    bar:SetScale(record.scale)
    bar:ClearAllPoints()
    for _, point in ipairs(record.points) do bar:SetPoint(unpack(point)) end
    record.moved = false
end

-- Native aura layout may re-anchor an unprotected castbar during combat. Only
-- reapply the layout captured outside combat; never read cast data or apply edits here.
function Mover:MaintainPosition()
    local bar = self.bar
    local record = bar and self.records[bar]
    if self.applying or not self.running or not record or not record.moved then return end
    if bar:IsProtected() then self.pending = true; return end

    self.applying = true
    local ok, err = pcall(function()
        bar:SetScale(record.appliedScale)
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", self.anchor, "CENTER", 0, 0)
    end)
    self.applying = false
    if not ok then self.pending = true; self.lastError = tostring(err) end
end

function Mover:Apply()
    if self.applying then return end
    if inCombat() then
        self.pending = true
        return
    end

    self.applying = true
    local ok, err = pcall(function()
        local enabled = self.running and self.Get("enabled")
        self.conflict = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ForeverTargetCastbar") == true
        if not enabled or self.conflict then
            self:ClosePreview()
            self:Restore(self.bar)
            return
        end

        self:CreateAnchor()
        if not self.dragging then self:PositionAnchor() end
        local bar = _G.TargetFrameSpellBar or (_G.TargetFrame and _G.TargetFrame.spellbar)
        if bar ~= self.bar then
            self:Restore(self.bar)
            self.bar = bar
        end
        if not bar then return end

        local record = self:Capture(bar)
        record.moved = true
        record.appliedScale = record.scale * self.Get("scale") / 100
        bar:SetScale(record.appliedScale)
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", self.anchor, "CENTER", 0, 0)
        self:SyncPreview()
    end)
    self.applying = false
    self.pending = not ok
    self.lastError = not ok and tostring(err) or nil
end

function Mover:Reset()
    if inCombat() then return false, "Leave combat before resetting the target castbar." end

    self:ClosePreview()
    for _, key in ipairs({"x", "y", "scale"}) do self.Set(key, defaults[key]) end
    self:Apply()
    return true
end

function Mover:Start()
    self.running = true
    settings()
    if not self.events then
        self.events = CreateFrame("Frame")
        for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "ADDON_LOADED",
            "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do
            self.events:RegisterEvent(event)
        end
        self.events:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_DISABLED" then self:ClosePreview() end
            self:Apply()
        end)
    end
    self:Apply()
end

function Mover:Stop()
    self.running = false
    self:ClosePreview()
    self:Apply()
end
