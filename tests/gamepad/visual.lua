local H = dofile("tests/gamepad/helpers.lua")
AwesomeForeverToolkitCharacterDB = {gamepad = {}}
local addon = {}
local source = H.loadfile('AwesomeForeverToolkit/Modules/Gamepad/OverlayVisual.lua')
if source then source('GAF', addon) end
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function fixture()
    assert(addon.OverlayVisual, 'visual module missing')
    local function widget()
        local w = {}
        local methods = {
            SetScale = function(self, v) self.scale = v end,
            SetSize = function(self, x, y) self.width, self.height = x, y end,
            SetPoint = function(self, _, region) self.anchor = region end,
            SetTexture = function(self, path, h, v) self.texture, self.hWrap, self.vWrap = path, h, v end,
            SetSwipeTexture = function(self, path) self.swipe = path end,
            SetDrawBling = function(self, v) self.bling = v end,
            AddMaskTexture = function(self, mask) self.mask = mask end,
            CreateTexture = function() return widget() end,
            CreateMaskTexture = function() return widget() end,
        }
        return setmetatable(w, {__index = function(_, k) return methods[k] or function() end end})
    end
    CreateFrame = function() return widget() end
    UIParent = {GetEffectiveScale = function() return 0.8 end}
    local native = {
        scale = 0.4, width = 38, height = 38,
        GetEffectiveScale = function(self) return self.scale end,
        GetFrameStrata = function() return 'MEDIUM' end,
        GetFrameLevel = function() return 4 end,
    }
    native.CircleMask = {GetSize = function() return native.width, native.height end}
    local visual = addon.OverlayVisual.Create(native)
    return visual, native
end

test('overlay matches inset native circle at its effective screen scale', function()
    local visual, native = fixture()

    assert(addon.OverlayVisual.Sync(visual, native))

    assert(visual.anchor == native.CircleMask)
    assert(visual.width == 38 and visual.height == 38)
    assert(visual.scale == 0.5)
    assert(math.abs(visual.width * visual.scale * UIParent:GetEffectiveScale() - 15.2) < 0.0001)
end)

test('expansion and UI scale changes resize the overlay', function()
    local visual, native = fixture()
    addon.OverlayVisual.Sync(visual, native)
    native.scale = 0.8
    native.width, native.height = 50, 50

    addon.OverlayVisual.Sync(visual, native)

    assert(visual.width == 50 and visual.scale == 1)
end)

test('icon and background share clamped circular alpha mask', function()
    local visual = fixture()

    assert(visual.icon.mask == visual.mask and visual.background.mask == visual.mask)
    assert(visual.mask.hWrap == 'CLAMPTOBLACKADDITIVE')
    assert(visual.mask.vWrap == 'CLAMPTOBLACKADDITIVE')
    assert(visual.mask.texture == visual.cooldown.swipe)
    assert(visual.cooldown.bling == false)
end)

print(passed .. ' passed, ' .. failed .. ' failed')
os.exit(failed == 0 and 0 or 1)
