local H = dofile("tests/warrior/helpers.lua")
local world = H.new()
local env = world.env
local combatResourceCreations = 0

-- Model only the WoW frame, animation, and pool boundaries. LibStub,
-- LibCustomGlow, Glow, and the screen icon all run their actual shipped code.
local function animation(parent)
    if world.combat then combatResourceCreations = combatResourceCreations + 1 end

    local group = { parent = parent, scripts = {}, plays = 0, playing = false }
    function group:GetParent() return self.parent end
    function group:SetScript(event, callback) self.scripts[event] = callback end
    function group:SetLooping(value) self.looping = value end
    function group:SetToFinalAlpha(value) self.finalAlpha = value end
    function group:IsPlaying() return self.playing end
    function group:Play() self.plays = self.plays + 1; self.playing = true end
    function group:Stop() self.playing = false end
    function group:Finish()
        self.playing = false
        if self.scripts.OnFinished then self.scripts.OnFinished(self) end
    end

    function group:CreateAnimation(kind)
        if world.combat then combatResourceCreations = combatResourceCreations + 1 end

        local effect = { kind = kind }
        for _, property in ipairs({ "ChildKey", "FromAlpha", "ToAlpha", "Duration", "Order",
            "FlipBookRows", "FlipBookColumns", "FlipBookFrames", "FlipBookFrameWidth", "FlipBookFrameHeight" }) do
            effect["Set" .. property] = function(self, value) self[property] = value end
        end
        return effect
    end

    return group
end

local function enhance(frame)
    local hide = frame.Hide
    function frame:GetParent() return self.parent end
    function frame:SetParent(parent) self.parent = parent end
    function frame:GetSize()
        if self.points then return self.points:GetSize() end
        return self.width or 64, self.height or 64
    end
    function frame:Show()
        local wasShown = self.visible
        self.visible = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide()
        local wasShown = self.visible
        hide(self)
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:CreateAnimationGroup() return animation(self) end
    function frame:CreateTexture()
        if world.combat then combatResourceCreations = combatResourceCreations + 1 end

        local texture = { visible = true }
        function texture:Show() self.visible = true end
        function texture:Hide() self.visible = false end
        function texture:SetVertexColor(...) self.color = { ... } end
        function texture:SetSize(width, height) self.width, self.height = width, height end
        function texture:SetPoint(...) self.point = { ... } end
        function texture:SetAllPoints(...) self.points = { ... } end
        for _, property in ipairs({ "BlendMode", "Atlas", "Alpha", "Desaturated", "Texture" }) do
            texture["Set" .. property] = function(self, value) self[property] = value end
        end
        return texture
    end

    return frame
end

local createFrame = env.CreateFrame
env.CreateFrame = function(...) return enhance(createFrame(...)) end
env.CreateTexturePool = function() return {} end -- Unused by ProcGlow.
env.CreateFramePool = function(kind, parent, template, reset)
    local pool = { inactive = {}, active = {} }
    function pool:Acquire()
        local frame = table.remove(self.inactive)
        local new = frame == nil
        if new then
            frame = env.CreateFrame(kind, nil, parent, template)
            reset(self, frame)
        end
        self.active[frame] = true
        return frame, new
    end
    function pool:Release(frame)
        assert(self.active[frame], "releasing an inactive frame")
        reset(self, frame)
        self.active[frame] = nil
        table.insert(self.inactive, frame)
    end
    return pool
end
env.LibStub = nil
env.strmatch = string.match
env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE = 1, 1
world:load({ "Libs/LibStub/LibStub", "Libs/LibCustomGlow-1.0/LibCustomGlow-1.0",
    "Core", "Services/Config", "Services/Client", "Services/Glow",
    "Services/Timers", "Services/BattleShoutAura", "Services/BattleShoutIcon", "Features/BattleShoutReminder" })

local addon = world.addon
addon.Config.Initialize()
addon.BattleShoutIcon:Initialize()
addon.BattleShoutAura.Initialize()
addon.BattleShoutReminder:Initialize()

local glow = world.addon.Glow
local icon = addon.BattleShoutIcon
local owner = "battle-shout-icon"
local key = "_ProcGlowAwesomeForeverToolkit"
glow.ConfigureOwner(owner, { color = { 0, 1, 0, 1 } })
local overlay = glow.Prepare(icon.frame).frame

-- A different addon can exhaust every free effect before combat starts.
local library = env.LibStub("LibCustomGlow-1.0")
local competitor = env.CreateFrame("Frame", nil, env.UIParent)
library.ProcGlow_Start(competitor, { key = "OtherAddon" })
local loopPlaysBeforeActivation = overlay[key] and overlay[key].ProcLoopAnim.plays or 0
world.combat = true

glow.Set(icon.frame, owner, true)
H.equal(world.combatFrameCreations, 0, "first activation allocates no combat frames")
local effect = assert(overlay[key], "actual library must attach proc effect")
H.equal(effect:GetParent(), overlay, "effect belongs to addon overlay")
H.equal(effect.ProcStartAnim.plays, 1, "one activation flash")
H.equal(effect.ProcStart.color[2], 1, "green activation tint")
H.equal(effect.ProcStartAnim:IsPlaying(), true, "startup playing")

glow.ConfigureOwner(owner, { color = { 1, 0, 0, 1 } })
H.equal(effect.ProcStart.visible, true, "recoloring during the intro preserves its flash")
H.equal(effect.ProcStartAnim.plays, 1, "recoloring during the intro does not restart it")
glow.ConfigureOwner(owner, { color = { 0, 1, 0, 1 } })

effect.ProcStartAnim:Finish()
H.equal(effect.ProcLoopAnim:IsPlaying(), true, "startup transitions to loop")
glow.Set(icon.frame, owner, true)
glow.ConfigureOwner(owner, { color = { 0, 1, 0, 1 } })
H.equal(overlay[key], effect, "same-color refresh reuses effect")
H.equal(effect.ProcStartAnim.plays, 1, "same-color refresh does not reflash")
H.equal(effect.ProcLoopAnim.plays, loopPlaysBeforeActivation + 1, "loop continues")

icon:SetVisible(true)
addon.Config.Set("iconSize", 36)
icon:ApplySettings()
H.equal(effect.point[4], 7.2, "active glow padding follows the new icon size")
H.equal(effect.ProcStartAnim.plays, 1, "resizing does not reflash")

glow.ConfigureOwner(owner, { color = { 1, 0, 0, 1 } })
H.equal(effect.ProcStart.color[1], 1, "startup retinted")
H.equal(effect.ProcLoop.color[2], 0, "loop retinted")
H.equal(effect.ProcStartAnim.plays, 1, "color change does not reflash")
H.equal(effect.ProcStart.visible, false, "recoloring cannot reveal the finished intro over the loop")

glow.ConfigureOwner(owner, {})
H.equal(effect.ProcStart.visible, false, "custom to native keeps the finished intro hidden")
H.equal(effect.ProcLoop.Desaturated, nil, "native restores the loop artwork")
H.equal(effect.ProcLoopAnim:IsPlaying(), true, "native switch keeps the existing loop running")

glow.ConfigureOwner(owner, { color = { 1, 0, 0, 1 } })
H.equal(effect.ProcStart.visible, false, "native to red keeps a single visible glow layer")
H.equal(effect.ProcLoop.color[1], 1)
H.equal(effect.ProcLoop.color[2], 0)
H.equal(overlay[key], effect, "stance color switches keep one reserved effect")
H.equal(effect.ProcStartAnim.plays, 1, "stance color switches do not replay the intro")

glow.RefreshGeometry(icon.frame)
H.equal(effect.ProcStart.visible, false, "geometry refresh cannot restore the finished intro")

world.combat = false
local gamepadButton = env.CreateFrame("CheckButton", nil, env.UIParent)
gamepadButton:SetSize(32, 32)
local gamepadEntry = glow.Prepare(gamepadButton)
world.combat = true
glow.Set(gamepadButton, "gamepad-geometry", true)
local gamepadEffect = gamepadEntry.effect
gamepadEffect.ProcStartAnim:Finish()

gamepadButton:SetSize(40, 40)
glow.RefreshGeometry(gamepadButton)
H.equal(gamepadEffect.point[4], 8, "expanded gamepad button updates loop padding")
H.equal(gamepadEffect.ProcStart.visible, false, "expanding gamepad button preserves a single loop layer")
gamepadButton:SetSize(32, 32)
glow.RefreshGeometry(gamepadButton)
H.equal(gamepadEffect.point[4], 6.4, "collapsed gamepad button restores loop padding")
H.equal(gamepadEffect.ProcStartAnim.plays, 1, "HUD resize does not reflash")
glow.Set(gamepadButton, "gamepad-geometry", false)

glow.Set(icon.frame, owner, false)
H.equal(overlay[key], effect, "stop retains reserved effect")
H.equal(effect.visible, false, "stop hides effect")
H.equal(library.ProcGlowPool.active[effect], true, "stopped effect stays unavailable to other addons")
H.equal(effect.ProcLoopAnim:IsPlaying(), false, "stop cancels animation")
H.equal(overlay.visible, false, "stop hides overlay")

glow.Set(icon.frame, owner, true)
H.equal(overlay[key], effect, "reactivation reuses reserved effect")
H.equal(effect.ProcStartAnim.plays, 2, "reactivation flashes once")

-- The same prepared icon handles both late and missing combat reminders.
local reminder = addon.BattleShoutReminder
world.auras = { { name = "Battle Shout", expirationTime = 5 } }
reminder:Refresh()

H.equal(reminder.output, "icon-late", "late buff chooses screen icon")
H.equal(effect.visible, true, "screen effect active")
H.equal(icon.visible, true, "screen icon visible")

world.auras = {}
reminder:Refresh()

H.equal(reminder.output, "icon-missing", "missing buff chooses screen")
H.equal(effect.visible, true, "screen effect remains active")
H.equal(world.combatFrameCreations, 0, "all combat output transitions allocate no frames")

glow.Set(icon.frame, owner, true, { startAnim = false })
H.equal(effect.ProcStartAnim:IsPlaying(), false, "loop-only transition stops startup")
H.equal(effect.ProcLoopAnim:IsPlaying(), true, "loop-only transition starts loop")
H.equal(world.combatFrameCreations, 0, "animation transition allocates no frames")
H.equal(combatResourceCreations, 0, "combat creates no textures or animations")

world.combat = false
reminder:Refresh()
H.equal(effect.visible, false, "combat exit hides screen effect")

print("integration: bundled LibStub/LibCustomGlow start, refresh, tint, stop, and icon reuse passed")
