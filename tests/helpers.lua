local Base = dofile("tests/fixtures/utilities/helpers.lua")
local H = {equal = Base.equal}

function H.new()
    local world = Base.new()
    local env = world.env
    world.class = "WARRIOR"
    world.time = 0
    world.loaded = {}
    world.glowActive = {}
    world.glows = {}
    env.GetTime = function() return world.time end
    env.GetScreenHeight = function() return 1080 end
    env.GetScreenWidth = function() return 1920 end
    env.UnitAffectingCombat = function() return world.combat end
    env.C_AddOns = {IsAddOnLoaded = function(name) return world.loaded[name] == true end}
    env.C_UnitAuras = {GetAuraDataBySpellName = function() return nil end, GetUnitAuras = function() return {} end}
    env.C_Spell.GetSpellTexture = function() return 132333 end
    env.SlashCmdList = {}
    env.AwesomeForeverToolkitDB = {warrior = {}, graphics = {}}
    env.AwesomeForeverToolkitCharacterDB = {utilities = {}, ui = {}}
    env.GetCursorPosition = function() return world.cursorX or 0, world.cursorY or 0 end

    local create = env.CreateFrame
    env.CreateFrame = function(...)
        local value = create(...)
        function value:CreateTexture() return env.CreateFrame("Texture", nil, self) end
        function value:CreateFontString() return env.CreateFrame("FontString", nil, self) end
        function value:GetScript(event) return self.scripts[event] end
        function value:RegisterUnitEvent(event, unit) self.events[event] = unit end
        function value:SetToplevel(top) self.topLevel = top end
        function value:Raise() self.raised = true end
        function value:EnableKeyboard(enabled) self.keyboard = enabled end
        function value:SetPropagateKeyboardInput(propagate)
            assert(not world.combat)
            self.propagateKeyboard = propagate
        end
        function value:SetupMenu(generator) self.menuGenerator = generator end
        function value:OverrideText(text) self.text = text end
        function value:SetVerticalScroll(offset) self.offset = offset end
        function value:GetEffectiveScale() return world.scale or 1 end
        function value:GetHeight() return self.height or 140 end
        function value:GetSize() return self.width or 64, self.height or 64 end
        function value:IsShown() return self.shown end
        function value:SetTexCoord(...) self.coords = {...} end
        function value:SetAlpha(alpha) self.alpha = alpha end
        function value:SetNormalTexture(texture) self.normalTexture = texture end
        function value:SetHighlightTexture(texture) self.highlightTexture = texture end
        function value:SetScale(scale) self.scale = scale end
        function value:SetHitRectInsets(...) self.hitRectInsets = {...} end
        function value:RegisterForClicks(...) self.clicks = {...} end

        return value
    end
    env.Minimap = env.CreateFrame("Frame")
    env.Minimap:SetSize(140, 140)
    env.ColorPickerFrame = {
        SetupColorPickerAndShow = function(self, options) self.options = options end,
        GetColorRGB = function() return 0, 1, 0 end,
    }
    env.Settings.RegisterVerticalLayoutCategory = function(name)
        local category = {name = name, GetID = function() return 1 end}
        local layout = {AddInitializer = function(_, item) world.launcher = item end}
        world.category = category
        return category, layout
    end
    env.Settings.RegisterAddOnCategory = function(category) world.registeredCategory = category end
    env.CreateSettingsButtonInitializer = function(_, _, callback, tooltip, addSearchTags)
        -- Blizzard requires an explicit search-tag choice, even for launcher buttons.
        assert(addSearchTags ~= nil, "CreateSettingsButtonInitializer requires addSearchTags")

        return {click = callback}
    end

    local library = {}
    library.ProcGlow_Start = function(target, options)
        local key = "_ProcGlow" .. options.key
        if not target[key] then
            target[key] = {
                ProcLoopAnim = {IsPlaying = function() return false end},
                Hide = function() world.glowActive[target.parent] = false end,
            }
        end
        world.glows[target] = options
        world.glowActive[target.parent] = true
    end
    library.ProcGlow_Stop = function(target) world.glowActive[target.parent] = false end
    library.PixelGlow_Start = function(target, color, _, _, _, _, _, _, _, key)
        local effect = target["_PixelGlow" .. key]
        if not effect then
            effect = env.CreateFrame("Frame", nil, target)
            effect.textures = {effect:CreateTexture()}
            target["_PixelGlow" .. key] = effect
        end
        for _, texture in ipairs(effect.textures) do
            texture:SetVertexColor(table.unpack(color or {0.95, 0.95, 0.32, 1}))
        end
        effect:Show()
    end
    env.LibStub = function() return library end

    world.addon = {}
    function world:load(files)
        for _, file in ipairs(files) do
            assert(loadfile("AwesomeForeverToolkit/" .. file .. ".lua", "t", env))("AwesomeForeverToolkit", self.addon)
        end
        return self.addon
    end
    function world:loadManifest()
        for line in io.lines("AwesomeForeverToolkit/AwesomeForeverToolkit.toc") do
            if line:match("%.lua$") and not line:match("^Libs/") then self:load({(line:gsub("%.lua$", ""))}) end
        end
        return self.addon
    end
    local tick = world.tick
    function world:tick(elapsed)
        self.time = self.time + elapsed
        tick(self, elapsed)
    end
    function world:newFrame() return env.CreateFrame("Frame") end
    function world:button(name, slot)
        local button = env.CreateFrame("CheckButton", name)
        button.action = slot
        button.icon = env.CreateFrame("Texture", nil, button)
        return button
    end
    return world
end
return H
