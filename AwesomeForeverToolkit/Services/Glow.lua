local _, addon = ...
local Glow = {}
local library = LibStub("LibCustomGlow-1.0")
local glowKey = "AwesomeForeverToolkit"
addon.Glow = Glow

-- State lives here, never on Blizzard's protected action buttons.
local entries = {}
local appearanceColor

local ownerStyles = {}

local function sameColor(first, second)
    if first == second then
        return true
    end

    if not first or not second then
        return false
    end

    for index = 1, 4 do
        if first[index] ~= second[index] then
            return false
        end
    end

    return true
end

local function update(entry, refreshGeometry)
    local selectedOwner
    local priority
    for owner in pairs(entry.owners) do
        local style = ownerStyles[owner]
        local candidate = style and style.priority or 0
        if priority == nil or candidate > priority
            or (candidate == priority and owner < selectedOwner) then
            selectedOwner = owner
            priority = candidate
        end
    end

    local wanted = selectedOwner ~= nil
    local request = selectedOwner and entry.owners[selectedOwner]
    local startAnim = not request or request.startAnim
    local style = selectedOwner and ownerStyles[selectedOwner]
    local color = appearanceColor
    if style then
        color = style.color
    end

    if entry.round then
        if not entry.active or not sameColor(entry.color, color) then
            entry.round:SetColor(color)
        end

        entry.round:SetActive(wanted)
        if wanted then entry.frame:Show() else entry.frame:Hide() end

        entry.active = wanted
        entry.color = color
        entry.startAnim = startAnim
        return
    end

    if wanted then
        local animationChanged = entry.startAnim ~= startAnim
        if entry.active and animationChanged and not startAnim then
            -- Hide stops both animations without returning our reserved effect
            -- to the shared library pool. The next start selects the loop.
            entry.effect:Hide()
        end

        if not entry.active or animationChanged or not sameColor(entry.color, color) or refreshGeometry then
            -- Updating the shown effect changes tint without replaying OnShow.
            library.ProcGlow_Start(entry.frame, { key = glowKey, startAnim = startAnim, color = color })

            -- Recoloring resets the intro's alpha even after its animation ends.
            -- Keep that finished texture from appearing over the running loop.
            if entry.effect.ProcLoopAnim:IsPlaying() then
                entry.effect.ProcStart:Hide()
            end
        end

        if not entry.active then
            entry.frame:Show()
        end
    elseif entry.active then
        entry.effect:Hide()
        entry.frame:Hide()
    end

    entry.active = wanted
    entry.color = color
    entry.startAnim = startAnim
end

local function copyColor(color)
    return color and { color[1], color[2], color[3], color[4] } or nil
end

-- Default appearance for owners without an explicit style.
function Glow.Configure(options)
    appearanceColor = copyColor(options.color)
    for _, entry in pairs(entries) do
        update(entry)
    end
end

-- Higher priority wins when features share a button; ties use the owner name.
-- A nil color explicitly selects native artwork rather than inheriting a tint.
function Glow.ConfigureOwner(owner, options)
    ownerStyles[owner] = { color = copyColor(options.color), priority = options.priority or 0 }
    for _, entry in pairs(entries) do
        update(entry)
    end
end

function Glow.IsPrepared(button)
    return entries[button] ~= nil
end

function Glow.RefreshGeometry(button)
    local entry = entries[button]
    if entry and entry.round then
        entry.round:RefreshGeometry()
        entry.frame:SetFrameLevel(button:GetFrameLevel() + 6)
        return
    end

    if entry and entry.active then
        local ok, width, height = pcall(function() return entry.frame:GetSize() end)
        if not ok or not addon.Client.Number(width) or not addon.Client.Number(height)
            or width <= 0 or height <= 0 then
            return
        end
        if entry.geometryWidth == width and entry.geometryHeight == height then return end

        entry.geometryWidth, entry.geometryHeight = width, height
        entry.frame:SetFrameLevel(button:GetFrameLevel() + 6)
        update(entry, true)
    end
end

function Glow.Prepare(button)
    if entries[button] then
        return entries[button]
    end

    -- Prepare default buttons on login and after combat, including empty ones.
    if InCombatLockdown() then
        return nil
    end

    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints(button)
    frame:SetFrameLevel(button:GetFrameLevel() + 6)
    frame:EnableMouse(false)

    frame:Hide()

    if addon.RoundGlow and addon.RoundGlow.IsRound(button) then
        local round = addon.RoundGlow.Create(frame, button)
        local entry = { frame = frame, effect = round.frame, round = round, owners = {}, active = false }
        entries[button] = entry
        return entry
    end

    -- ProcGlow_Start allocates the effect, textures, and animation groups lazily.
    -- Keep that effect attached for this overlay's lifetime: releasing it would
    -- let another addon consume the pool entry before our next combat reminder.
    library.ProcGlow_Start(frame, { key = glowKey, startAnim = false })
    local effect = frame["_ProcGlow" .. glowKey]
    effect:Hide()

    local entry = { frame = frame, effect = effect, owners = {}, active = false }
    entries[button] = entry
    return entry
end

function Glow.Set(button, owner, active, options)
    local entry = entries[button]
    if not entry and active then
        entry = Glow.Prepare(button)
    end

    if not entry then
        return
    end

    entry.owners[owner] = active and { startAnim = not options or options.startAnim ~= false } or nil
    update(entry)
end

function Glow.ClearOwner(owner)
    for button in pairs(entries) do
        Glow.Set(button, owner, false)
    end
end
