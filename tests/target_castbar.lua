local H = dofile("tests/helpers.lua")

local function setup(saved)
    local w = H.new()
    w.env.AwesomeForeverToolkitDB.targetCastbar = saved
    w.env.UIParent.GetEffectiveScale = function() return 1 end
    local create = w.env.CreateFrame
    w.env.CreateFrame = function(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        function f:GetParent() return self.parent end
        function f:GetScale() return self.scale or 1 end
        function f:GetEffectiveScale()
            return self:GetScale() * (self.parent and self.parent:GetEffectiveScale() or 1)
        end
        function f:IsProtected() return self.protected == true end
        function f:GetNumPoints() return #(self.points or {}) end
        function f:GetPoint(index) return table.unpack(self.points[index]) end
        function f:HookScript(event, callback)
            local original = self.scripts[event]
            self.scripts[event] = function(...)
                if original then original(...) end
                callback(...)
            end
        end
        if template == "TargetSpellBarTemplate" then
            for _, key in ipairs({"Text", "Icon", "BorderShield", "Flash", "Spark"}) do
                f[key] = create("Frame", nil, f)
            end
            function f:StopAnims() end
            function f:UpdateBarFillTexture() end
        end
        return f
    end
    w.env.CastingBarType = {Standard = 1}
    w.env.TargetFrame = w.env.CreateFrame("Frame", nil, w.env.UIParent)
    w.bar = w.env.CreateFrame("StatusBar", nil, w.env.TargetFrame)
    w.bar:SetSize(150, 10)
    w.bar:SetPoint("TOP", w.env.TargetFrame, "BOTTOM", 0, -10)
    w.bar:SetScale(1.2)
    local setPoint, setScale = w.bar.SetPoint, w.bar.SetScale
    function w.bar:SetPoint(...)
        assert(not w.combat or not self:IsProtected(), "must not position protected bar in combat")
        setPoint(self, ...)
    end
    function w.bar:SetScale(...)
        assert(not w.combat or not self:IsProtected(), "must not scale protected bar in combat")
        setScale(self, ...)
    end
    local clear = w.bar.ClearAllPoints
    function w.bar:ClearAllPoints()
        assert(not w.combat or not self:IsProtected(), "must not clear protected bar anchors in combat")
        clear(self)
    end
    w.nativeSetPoint = setPoint
    w.env.TargetFrameSpellBar = w.bar
    w.root = w:loadManifest()
    w:fire("PLAYER_LOGIN")
    w.mover = assert(w.root.modules.Utilities.TargetCastbar, "castbar mover must load")
    return w
end

local w = setup()
local mover = w.mover
assert(not mover.Get("enabled"), "must opt in before moving native UI")
assert(w.bar.point[2] == w.env.TargetFrame)
mover.Set("enabled", true)
assert(w.bar.point[2] == mover.anchor)
assert(mover.anchor.point[1] == "CENTER" and mover.anchor.point[3] == "BOTTOMLEFT")
assert(mover.anchor.point[4] == w.env.UIParent:GetWidth() * 0.5)
mover.Set("scale", 150)
assert(math.abs(w.bar:GetScale() - 1.8) < 0.001)

assert(mover:Preview())
assert(mover.preview:IsShown())
assert(math.abs(mover.preview:GetScale() - 1.8) < 0.001)
w.env.TargetFrame:SetScale(1.5)
assert(math.abs(mover.preview:GetScale() - 2.7) < 0.001, "preview follows parent scaling")
w.env.TargetFrame:SetScale(1)
mover.anchor.centerX, mover.anchor.centerY = 200, 300
mover.anchor.scripts.OnDragStart(mover.anchor)
mover.anchor.scripts.OnDragStop(mover.anchor)
assert(mover.Get("x") == 200 / w.env.UIParent:GetWidth())
assert(w.env.AwesomeForeverToolkitCharacterDB.targetCastbar == nil)
local saved = w.env.AwesomeForeverToolkitDB.targetCastbar
assert(saved.x == mover.Get("x") and saved.scale == 150)

w.root.ClearPreviews()
assert(not mover.preview:IsShown())
assert(mover:Preview())
mover.anchor.scripts.OnDragStart(mover.anchor)
mover.anchor:ClearAllPoints()
mover.anchor:SetPoint("CENTER", w.env.UIParent, "BOTTOMLEFT", 100, 100)
w.combat = true
w:fire("PLAYER_REGEN_DISABLED")
assert(not mover.preview:IsShown() and not mover.dragging, "combat closes preview and cancels drag")
assert(mover.anchor.point[4] == 200 and mover.anchor.point[5] == 300, "interrupted drag restores saved position")
mover.Set("scale", 200)
w:fire("DISPLAY_SIZE_CHANGED")
assert(not mover:Preview())
-- Native layout writes are allowed; the posthook must restore our cached position.
w.bar:SetPoint("TOP", w.env.TargetFrame, "BOTTOM", 0, -30)
assert(w.bar.point[2] == mover.anchor)
assert(math.abs(w.bar:GetScale() - 1.8) < 0.001, "pending scale edits are not applied by combat hooks")
w.bar.protected = true
w.nativeSetPoint(w.bar, "TOP", w.env.TargetFrame, "BOTTOM", 0, -40)
w.bar:Show()
assert(w.bar.point[2] == w.env.TargetFrame, "protected bars defer combat maintenance")
assert(math.abs(w.bar:GetScale() - 1.8) < 0.001)
w.combat = false
w:fire("PLAYER_REGEN_ENABLED")
assert(math.abs(w.bar:GetScale() - 2.4) < 0.001)

mover.Set("enabled", false)
assert(w.bar.point[2] == w.env.TargetFrame and w.bar.point[5] == -10)
assert(w.bar:GetScale() == 1.2)
mover.Set("enabled", true)
assert(mover:Reset())
assert(mover.Get("x") == 0.5 and mover.Get("y") == 0.38 and mover.Get("scale") == 100)

local second = setup({enabled = true, x = 0.25, y = 0.75, scale = 125})
assert(second.mover.anchor.point[4] == second.env.UIParent:GetWidth() * 0.25)
second.env.UIParent.GetWidth = function() return 2000 end
second:fire("DISPLAY_SIZE_CHANGED")
assert(second.mover.anchor.point[4] == 500)
second.root.modules.Utilities:Stop()
assert(second.bar.point[2] == second.env.TargetFrame)

local invalid = setup({enabled = "yes", x = 0/0, y = 2, scale = math.huge})
assert(invalid.mover.Get("enabled") == false)
assert(invalid.mover.Get("x") == 0.5 and invalid.mover.Get("y") == 0.38)
assert(invalid.mover.Get("scale") == 100)
-- A new character reads the account section, without a per-character copy.
local shared = setup(saved)
assert(shared.mover.Get("x") == saved.x and shared.mover.Get("scale") == saved.scale)
assert(shared.env.AwesomeForeverToolkitCharacterDB.targetCastbar == nil)

-- A second mover must never fight the original addon's posthooks.
shared.loaded.ForeverTargetCastbar = true
shared:fire("ADDON_LOADED", "ForeverTargetCastbar")
assert(shared.bar.point[2] == shared.env.TargetFrame)
assert(not shared.mover:Preview())
print("target castbar: PASS")
