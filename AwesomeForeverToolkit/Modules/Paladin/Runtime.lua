local _, root = ...
local addon = root.modules.Paladin
local discoveryEvents = {
    PLAYER_ENTERING_WORLD = true, ACTIONBAR_SLOT_CHANGED = true, ACTIONBAR_PAGE_CHANGED = true,
    UPDATE_BONUS_ACTIONBAR = true, UPDATE_OVERRIDE_ACTIONBAR = true, UPDATE_VEHICLE_ACTIONBAR = true,
    SPELLS_CHANGED = true, PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true,
    UPDATE_SHAPESHIFT_FORM = true, UPDATE_SHAPESHIFT_FORMS = true,
}

function addon:StartRuntime()
    local frame = CreateFrame('Frame')
    self.frame = frame
    for event in pairs(discoveryEvents) do frame:RegisterEvent(event) end
    for _, event in ipairs({'SPELL_UPDATE_COOLDOWN', 'PLAYER_DEAD', 'PLAYER_EQUIPMENT_CHANGED',
        'PLAYER_TARGET_CHANGED', 'UPDATE_MOUSEOVER_UNIT'}) do frame:RegisterEvent(event) end
    frame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
    frame:RegisterUnitEvent('UNIT_AURA', 'player')

    frame:SetScript('OnEvent', function(_, event, ...)
        if not self.active then return end
        if event == 'PLAYER_REGEN_DISABLED' then self:ClearPreviews() end
        if event == 'UNIT_AURA' then self.RighteousFuryReminder.lastAuraCheck = nil end
        for _, feature in ipairs(self.features) do
            if feature.OnEvent then feature:OnEvent(event, ...) end
        end
        self:Refresh(discoveryEvents[event], event == 'SPELL_UPDATE_COOLDOWN')
    end)

    local elapsedCheck, elapsedDiscovery = 0, 0
    frame:SetScript('OnUpdate', function(_, elapsed)
        if not self.active then return end
        elapsedCheck, elapsedDiscovery = elapsedCheck + elapsed, elapsedDiscovery + elapsed
        if elapsedCheck < 0.1 then return end

        local discover = elapsedDiscovery >= 0.5
        elapsedCheck = 0
        if discover then elapsedDiscovery = 0 end
        self:Refresh(discover)
    end)
end
