local H = dofile('tests/paladin/helpers.lua')
local passed = 0
local function test(name, run)
    run()
    passed = passed + 1
    print('PASS ' .. name)
end

local function newWorld(settings)
    local w = H.new(settings)
    w.form = 0
    w.formSpellID = 465
    w.env.C_Spell.GetSpellTexture = function(id)
        return ({[465] = 135893, [7294] = 135873})[id]
    end
    w.env.GetShapeshiftForm = function() return w.form end
    w.env.GetShapeshiftFormInfo = function(index)
        assert(index == w.form)
        return 135890, true, true, w.formSpellID
    end
    w:fire('UPDATE_SHAPESHIFT_FORM')
    return w
end

test('missing aura shows a grayscale Devotion Aura icon and red glow', function()
    local w = newWorld()
    local feature = w.paladin.AuraIcon
    assert(feature, 'Paladin aura indicator must be registered')
    local popup = feature.popup

    assert(popup.frame:IsShown())
    assert(popup.frame:GetWidth() == 36)
    assert(popup.texture.texture == w.env.C_Spell.GetSpellTexture(465))
    assert(popup.texture.desaturation == 1, 'missing aura matches cooldown grayscale')
    local r, g, b = popup.texture:GetVertexColor()
    assert(r == 1 and g == 1 and b == 1, 'grayscale must not darken the icon')
    assert(w:glowing(popup.frame))
    local color = w:color(popup.frame)
    assert(color[1] == 1 and color[2] == 0 and color[3] == 0 and color[4] == 1)
end)

test('changing and cancelling own aura restores color and warning immediately', function()
    local w = newWorld()
    local popup = w.paladin.AuraIcon.popup

    w.form = 1
    w:fire('UPDATE_SHAPESHIFT_FORM')
    assert(popup.texture.texture == 135893, 'use the aura spell icon, not the stance active artwork')
    assert(popup.texture.desaturation == 0)
    assert(not w:glowing(popup.frame))

    w.form, w.formSpellID = 2, 7294
    w:fire('UPDATE_SHAPESHIFT_FORMS')
    assert(popup.texture.texture == 135873)

    w.form = 0
    w.aura = { expirationTime = w.time + 1800 }
    w:fire('UNIT_AURA', 'player')
    assert(popup.texture.desaturation == 1)
    assert(w:glowing(popup.frame), 'another player aura must not hide the missing-own-aura warning')
end)

test('unreadable aura state hides the indicator instead of claiming an aura is missing', function()
    local w = newWorld()
    local popup = w.paladin.AuraIcon.popup

    w.env.GetShapeshiftForm = function() error('unavailable') end
    w:fire('UPDATE_SHAPESHIFT_FORM')
    assert(not popup.frame:IsShown() and not w:glowing(popup.frame))

    w.env.GetShapeshiftForm = function() return w.secret end
    w.secret = {}
    w.env.issecretvalue = function(value) return value == w.secret end
    w:fire('UPDATE_SHAPESHIFT_FORM')
    assert(not popup.frame:IsShown() and not w:glowing(popup.frame))

    w.env.GetShapeshiftForm = function() return 1 end
    w.env.GetShapeshiftFormInfo = function() return 135890, true, true, w.secret end
    w:fire('UPDATE_SHAPESHIFT_FORM')
    assert(not popup.frame:IsShown() and not w:glowing(popup.frame))
end)

test('active artwork is ignored even when secret and spell lookup failures stay unknown', function()
    local w = newWorld()
    local popup = w.paladin.AuraIcon.popup
    local secret = {}
    w.env.issecretvalue = function(value) return value == secret end
    w.form = 1
    w.env.GetShapeshiftFormInfo = function() return secret, true, true, 465 end

    w:fire('UPDATE_SHAPESHIFT_FORM')
    assert(popup.frame:IsShown() and popup.texture.texture == 135893)
    assert(not w:glowing(popup.frame))

    w.env.C_Spell.GetSpellTexture = function() error('unavailable') end
    w:fire('UPDATE_SHAPESHIFT_FORM')
    assert(not popup.frame:IsShown() and not w:glowing(popup.frame))
end)

test('size position disable and preview lifecycle apply to the aura indicator', function()
    local w = newWorld({auraIconSize = 48, auraIconX = 120, auraIconY = -240})
    local feature = w.paladin.AuraIcon
    local popup = feature.popup

    assert(popup.frame:GetWidth() == 48)
    assert(popup.x == 120 and popup.y == -240)
    feature:SetPreview(true)
    assert(popup.preview)
    w.paladin:ClearPreviews()
    assert(not popup.preview and popup.frame:IsShown())

    feature:SetPreview(true)
    w.combat = true
    w:fire('PLAYER_REGEN_DISABLED')
    assert(not popup.preview)
    assert(popup.frame:IsShown() and w:glowing(popup.frame))

    w.combat = false
    w:fire('PLAYER_REGEN_ENABLED')
    w.paladin.Config.Set('auraIconEnabled', false)
    feature:SetPreview(true)
    assert(not popup.frame:IsShown() and not popup.preview and not w:glowing(popup.frame))

    w.paladin.Config.Set('auraIconEnabled', true)
    assert(popup.frame:IsShown() and w:glowing(popup.frame))
    w.paladin.Config.Set('auraIconSize', 60)
    assert(popup.frame:GetWidth() == 60)
    w.paladin:Stop()
    assert(not popup.frame:IsShown() and not w:glowing(popup.frame))
end)

print('Paladin aura icon: ' .. passed .. ' passed')
