local H = dofile('tests/helpers.lua')
local passed = 0
local function test(name, run)
    run()
    passed = passed + 1
    print('PASS ' .. name)
end

local function setup(options)
    local w = H.new()
    local root = w:loadManifest()
    assert(root.BuffTracker, 'shared buff tracker must exist')
    w.auras, w.restricted, w.items, w.info = {}, {}, {}, {}
    w.env.C_Secrets = {ShouldSpellAuraBeSecret = function(id) return w.restricted[id] == true end}
    w.env.C_UnitAuras.GetPlayerAuraBySpellID = function(id) return w.auras[id] end
    local viewer = w:newFrame()
    viewer:Show()
    viewer.itemFramePool = {EnumerateActive = function() return next, w.items, nil end}
    w.env.BuffIconCooldownViewer = viewer
    w.viewer = viewer
    w.env.C_CooldownViewer = {GetCooldownViewerCooldownInfo = function(id) return w.info[id] end}
    w.tracker = root.BuffTracker.New({
        {key = 'might', spellIDs = {19740, 19834}},
        {key = 'wisdom', spellIDs = {19742}},
    }, options)

    function w:item(id, spellID, shown, unit)
        local item = self:newFrame()
        item.cooldownID = id
        item.allowHideWhenInactive, item.hideWhenInactive = true, true
        item.GetCooldownID = function(self) return self.cooldownID end
        item.GetSpellID = function()
            assert(not w.combat, 'never identify tracked spells in combat')
            return spellID
        end
        item.GetAuraDataUnit = function() return unit end
        item.IsEditing = function() return false end
        item:SetShown(shown)
        self.info[id] = {spellID = spellID}
        self.items[item] = true
        return item
    end

    function w:sample()
        self.tracker:Invalidate()
        return self.tracker:Sample()
    end
    return w
end

test('all readable alternatives must be absent, and another caster rank counts', function()
    local w = setup()
    assert(w:sample() == 'missing')

    w.auras[19834] = {sourceUnit = 'party1', expirationTime = 400}
    assert(w:sample() == 'present')
    w.auras[19834] = nil
    w.restricted[19742] = true
    assert(w:sample() == 'unknown')
end)

test('a readable present buff wins even when another buff is restricted', function()
    local w = setup()
    w.restricted[19740], w.restricted[19834] = true, true
    w.auras[19742] = {}
    assert(w:sample() == 'present')
end)

test('failed or secret direct results cannot establish absence', function()
    local w = setup()
    w.env.C_UnitAuras.GetPlayerAuraBySpellID = function() error('restricted') end
    assert(w:sample() == 'unknown')

    local secret = {}
    w.env.issecretvalue = function(value) return value == secret end
    w.env.C_UnitAuras.GetPlayerAuraBySpellID = function() return secret end
    assert(w:sample() == 'unknown')
    w.env.C_Secrets.ShouldSpellAuraBeSecret = function() return secret end
    w.env.C_UnitAuras.GetPlayerAuraBySpellID = function() error('must not query a restricted spell') end
    assert(w:sample() == 'unknown')
end)

test('cached player buff frame supports combat presence but not all-caster absence', function()
    local w = setup()
    local item = w:item(1, 19740, true, 'player')
    w:sample()
    w.restricted = {[19740] = true, [19834] = true, [19742] = true}
    w.combat = true

    assert(w:sample() == 'present')
    item:Hide()
    assert(w:sample() == 'unknown', 'hidden own-cast icon cannot exclude another Paladin blessing')
    item:Show()
    item.GetAuraDataUnit = function() return 'target' end
    assert(w:sample() == 'unknown', 'a blessing on the target is not on the player')
end)

test('self-only consumer can reuse missing detection with complete tracked coverage', function()
    local w = setup({selfOnly = true})
    w:item(1, 19740, false)
    w:sample()
    w.restricted = {[19740] = true, [19834] = true, [19742] = true}
    assert(w:sample() == 'unknown', 'untracked alternative is unknown')
    w:item(2, 19742, false)
    w:sample()
    w.combat = true

    assert(w:sample() == 'missing')
end)

test('hidden viewers edit mode and always-visible entries are not buff signals', function()
    local w = setup({selfOnly = true})
    local first = w:item(1, 19740, false)
    w:item(2, 19742, false)
    w.restricted = {[19740] = true, [19834] = true, [19742] = true}
    assert(w:sample() == 'missing')

    w.viewer:Hide()
    assert(w:sample() == 'unknown')
    w.viewer:Show()
    first.IsEditing = function() return true end
    assert(w:sample() == 'unknown')
    first.IsEditing = function() return false end
    first.hideWhenInactive = false
    first:Show()
    assert(w:sample() == 'unknown')
end)

test('removed or reassigned pool entries never retain old buff identity in combat', function()
    local w = setup()
    local item = w:item(1, 19740, true, 'player')
    w:sample()
    w.restricted = {[19740] = true, [19834] = true, [19742] = true}
    w.combat = true
    w.items[item] = nil
    assert(w:sample() == 'unknown')

    w.items[item] = true
    item.cooldownID = 99
    assert(w:sample() == 'unknown')
end)

test('unavailable APIs and mid-combat startup remain unknown', function()
    local w = setup()
    w.env.C_Secrets = nil
    w.combat = true
    w:item(1, 19740, true, 'player')
    assert(w:sample() == 'unknown')

    w.combat = false
    w.env.C_UnitAuras.GetPlayerAuraBySpellID = nil
    w.env.BuffIconCooldownViewer = nil
    assert(w:sample() == 'unknown')
end)

print('Buff tracker: ' .. passed .. ' passed')
