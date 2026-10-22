local _, root = ...
local addon = root.modules.Gamepad
local panels = {}
local faces = {"A", "B", "X", "Y"}
local modes = {
    {value = "native", label = "Blizzard default", description = "Use Blizzard's original action. Any saved spell or macro is remembered."},
    {value = "context", label = "Contextual", description = "Use the assignment in combat or with an enemy target. Hostile mouseover applies only without a target."},
    {value = "always", label = "Always", description = "Use the assignment even without combat or a target. Modifier and stance layers still take priority."},
}
local positions = {Y = {110, -158}, X = {30, -258}, B = {190, -258}, A = {110, -358}}

local function Label(parent, text, x, y, width, height, font)
    local label = root.Widgets.Text(parent, text, x, y, font or "GameFontHighlight")
    label:SetWidth(width)
    label:SetHeight(height)
    label:SetJustifyV("TOP")
    return label
end

-- Blizzard menus enter the native gamepad focus stack from addon callbacks.
-- Keep these choices on ordinary addon-owned frames instead.
local openChoices

local function Dropdown(parent, x, y, width, options, get, set)
    local dropdown = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    dropdown:SetPoint("TOPLEFT", x, y)
    dropdown:SetSize(width, 26)

    local popup = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    popup:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    popup:SetBackdropColor(0.08, 0.08, 0.1, 1)
    popup:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
    popup:EnableMouse(true)
    popup:Hide()
    dropdown.popup, dropdown.choices = popup, {}

    local function Close()
        popup:Hide()
        if openChoices == popup then openChoices = nil end
    end

    dropdown:SetScript("OnHide", Close)
    popup:RegisterEvent("GLOBAL_MOUSE_DOWN")
    popup:SetScript("OnEvent", function()
        if popup:IsShown() and not popup:IsMouseOver() and not dropdown:IsMouseOver() then Close() end
    end)
    dropdown:SetScript("OnClick", function()
        if popup:IsShown() then Close(); return end
        if addon.Runtime.IsLocked() or not dropdown:IsEnabled() then return end
        if openChoices then openChoices:Hide() end

        for _, choice in ipairs(dropdown.choices) do choice:Hide() end
        for index, option in ipairs(options) do
            local choice = dropdown.choices[index]
            if not choice then
                choice = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
                choice:SetPoint("TOPLEFT", 4, -4 - (index - 1) * 26)
                choice:SetSize(width - 8, 24)
                dropdown.choices[index] = choice
            end
            choice.value = option.value
            choice:SetText((get() == option.value and "|cffffd100" or "|cffffffff") .. option.label .. "|r")
            choice:SetScript("OnClick", function()
                Close()
                if not addon.Runtime.IsLocked() then set(option.value) end
            end)
            choice:Show()
        end

        popup:SetSize(width, 8 + #options * 26)
        openChoices = popup
        popup:Show()
    end)
    dropdown.refresh = function()
        Close()
        local value = get()
        dropdown.selectedValue = value
        for _, option in ipairs(options) do
            if option.value == value then dropdown:SetText(option.label .. "  |TInterface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up:16:16|t"); break end
        end
    end
    return dropdown
end

local function Slot(parent, x, y, size)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(size, size)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
    button:SetBackdropColor(0.08, 0.08, 0.1, 1)
    button:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    local letter = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    letter:SetPoint("CENTER")
    letter:SetTextColor(0.5, 0.5, 0.55)
    return {button = button, icon = icon, letter = letter}
end

local function CreatePanel(frame, context)
    local selectedFace, selectedStanceID = "A", nil
    local faceSlots, profileOptions = {}, {}
    local editor = {}
    local profile, behavior, enabled, message
    local Refresh

    local function Result(ok, detail)
        message:SetText((ok and "|cff80ff80" or "|cffff8080") .. tostring(detail or "") .. "|r")
        addon.RefreshConfiguration()
    end

    local function Select(face)
        selectedFace = face
        message:SetText("")
        Refresh()
    end

    local function Drop(face)
        selectedFace = face
        Result(addon.ConfigurationActions.Drop(face, selectedStanceID))
    end

    local function Click(face)
        if GetCursorInfo() then Drop(face) else Select(face) end
    end

    local function Tooltip(button, face)
        local config, inherited = addon.Runtime.GetConfig(face, selectedStanceID)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if config.kind == "macro" then
            GameTooltip:SetText("Macro: " .. tostring(config.macroName))
            GameTooltip:AddLine("Uses the macro's own targeting rules.", 1, 1, 1, true)
        elseif config.spellID then
            GameTooltip:SetSpellByID(config.spellID)
        else
            GameTooltip:SetText("Button " .. face .. " — Blizzard default")
            GameTooltip:AddLine("Drop a spell or macro here.", 1, 1, 1, true)
        end
        if inherited then GameTooltip:AddLine("Inherited from Base", 0.7, 0.7, 0.7) end
        GameTooltip:Show()
    end

    local function Paint(slot, face, info)
        slot.icon:SetTexture(info and info.iconID or nil)
        slot.icon:SetShown(info ~= nil and info.iconID ~= nil)
        slot.letter:SetText(face)
        slot.letter:SetShown(info == nil or info.iconID == nil)
    end

    Refresh = function()
        local locked = addon.Runtime.IsLocked()
        local forms = addon.Runtime.GetForms()
        local exists = selectedStanceID == nil
        for index = #profileOptions, 1, -1 do profileOptions[index] = nil end
        profileOptions[1] = {value = 0, label = "Base"}
        for _, form in ipairs(forms) do
            profileOptions[#profileOptions + 1] = {value = form.spellID, label = form.name}
            if form.spellID == selectedStanceID then exists = true end
        end
        if not exists then selectedStanceID = nil end
        profile.refresh()
        profile:SetEnabled(not locked)

        local anyEnabled = false
        for _, face in ipairs(faces) do
            local config = addon.Runtime.GetConfig(face, selectedStanceID)
            local info = addon.Runtime.Describe(config)
            local slot = faceSlots[face]
            Paint(slot, face, info)
            slot.caption:SetText(info and info.name or (config.macroName or (config.spellID and "Unavailable spell") or "Blizzard default"))
            slot.button:SetEnabled(not locked)
            if face == selectedFace then slot.button:SetBackdropBorderColor(1, 0.82, 0.2, 1)
            else slot.button:SetBackdropBorderColor(0.3, 0.3, 0.35, 1) end
            anyEnabled = anyEnabled or addon.Runtime.IsEnabled(face)
        end
        enabled:SetChecked(anyEnabled)
        enabled:SetEnabled(not locked)

        local config, inherited = addon.Runtime.GetConfig(selectedFace, selectedStanceID)
        local info = addon.Runtime.Describe(config)
        local assigned = config.spellID ~= nil or config.macroName ~= nil
        Paint(editor.slot, selectedFace, info)
        editor.slot.button:SetEnabled(not locked)
        editor.title:SetText("Button " .. selectedFace)
        editor.name:SetText(info and info.name or (assigned and (config.macroName or "Unavailable spell") or "Drop a spell or macro here"))
        editor.origin:SetText(inherited and "Inherited from Base" or (selectedStanceID and "Custom for this profile" or "Base assignment"))
        for _, mode in ipairs(modes) do
            if mode.value == config.mode then
                editor.summary:SetText(mode.label)
                editor.description:SetText(mode.description)
                break
            end
        end
        behavior.refresh()
        behavior:SetEnabled(not locked)
        editor.clear:SetText(selectedStanceID and "Use Base assignment" or "Clear assignment")
        editor.clear:SetEnabled(not locked and (selectedStanceID ~= nil and not inherited or selectedStanceID == nil and assigned))
        local status = addon.Runtime.IsActive(selectedFace) and "Active" or "Off"
        if addon.Runtime.IsEnabled(selectedFace) and not addon.Runtime.IsActive(selectedFace) then
            status = "Enabled, temporarily inactive"
        end
        editor.status:SetText(locked and "Combat: changes are locked" or status)
    end

    Label(frame, "Gamepad bindings", 20, -12, 560, 25, "GameFontNormalLarge")
    Label(frame, "Select a button to edit, or drop a spell or macro directly onto it.", 20, -44, 560, 32)
    Label(frame, "Profile", 20, -80, 260, 20, "GameFontNormal")
    profile = Dropdown(frame, 20, -103, 270, profileOptions,
        function() return selectedStanceID or 0 end,
        function(value)
            selectedStanceID = value ~= 0 and value or nil
            message:SetText("")
            Refresh()
        end)

    enabled = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 350, -101)
    enabled.Text:SetText("Enable overrides")
    enabled:SetScript("OnClick", function(self)
        addon.Runtime.RunCommand(self:GetChecked() and "on" or "off")
        message:SetText("See chat for the result for each button.")
        addon.RefreshConfiguration()
    end)

    for _, face in ipairs(faces) do
        local x, y = positions[face][1], positions[face][2]
        local slot = Slot(frame, x, y, 60)
        faceSlots[face] = slot
        Label(frame, face, x, y + 20, 60, 18, "GameFontNormal")
        slot.caption = Label(frame, "", x - 20, y - 64, 100, 32, "GameFontHighlightSmall")
        slot.button:SetScript("OnClick", function() Click(face) end)
        slot.button:SetScript("OnReceiveDrag", function() Drop(face) end)
        slot.button:SetScript("OnEnter", function(self) Tooltip(self, face) end)
        slot.button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local detail = CreateFrame("Frame", nil, frame)
    detail:SetPoint("TOPLEFT", 300, -155)
    detail:SetSize(280, 330)
    editor.title = Label(detail, "", 0, 0, 280, 24, "GameFontNormalLarge")
    editor.slot = Slot(detail, 0, -36, 64)
    editor.slot.button:SetScript("OnClick", function() Click(selectedFace) end)
    editor.slot.button:SetScript("OnReceiveDrag", function() Drop(selectedFace) end)
    editor.slot.button:SetScript("OnEnter", function(self) Tooltip(self, selectedFace) end)
    editor.slot.button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    editor.name = Label(detail, "", 78, -36, 202, 42)
    editor.summary = Label(detail, "", 78, -82, 202, 30, "GameFontHighlightSmall")
    editor.origin = Label(detail, "", 0, -120, 280, 24, "GameFontNormal")
    Label(detail, "Behavior", 0, -155, 280, 20)
    behavior = Dropdown(detail, 0, -180, 280, modes,
        function() return addon.Runtime.GetConfig(selectedFace, selectedStanceID).mode end,
        function(value) Result(addon.ConfigurationActions.SetMode(selectedFace, value, selectedStanceID)) end)
    editor.description = Label(detail, "", 0, -218, 280, 64, "GameFontHighlightSmall")
    editor.clear = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    editor.clear:SetPoint("TOPLEFT", 0, -290)
    editor.clear:SetSize(240, 26)
    editor.clear:SetScript("OnClick", function() Result(addon.ConfigurationActions.Clear(selectedFace, selectedStanceID)) end)
    editor.status = Label(detail, "", 0, -330, 280, 36, "GameFontHighlightSmall")
    message = Label(frame, "", 20, -530, 560, 40, "GameFontHighlightSmall")
    Label(frame, "Changes apply outside combat. Editing a profile does not change your current form.\nIf you override A, assign jump elsewhere. Activation survives /reload.", 20, -580, 560, 38, "GameFontHighlightSmall")

    context.controls["gamepad.faces"] = faceSlots
    context.controls["gamepad.editor"] = editor
    context.controls["gamepad.profile"] = profile
    context.controls["gamepad.behavior"] = behavior
    context.controls["gamepad.enabled"] = enabled
    context.controls["gamepad.refresh"] = {refresh = Refresh}
    panels[#panels + 1] = {frame = frame, refresh = Refresh}
    frame:SetScript("OnShow", Refresh)
    for _, event in ipairs({"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_MACROS"}) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", Refresh)
    Refresh()
end

function addon.RefreshConfiguration()
    for _, panel in ipairs(panels) do
        if panel.frame:IsShown() then panel.refresh() end
    end
end

local className, class = UnitClass("player")
if class == "WARRIOR" then className = root.Window.pages["warrior.reminders"].parent end
if type(className) ~= "string" then className = "Class" end
root.Window:RegisterPage({
    id = "gamepad.bindings", label = "Gamepad bindings", parent = className,
    available = function() return addon.active == true end,
    build = function(parent, context)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetPoint("TOPLEFT")
        frame:SetSize(600, 640)
        CreatePanel(frame, context)

        local function resize(_, width)
            local scale = math.min(1, math.max(1, width) / 600)
            frame:SetScale(scale)
            parent:SetHeight(640 * scale)
        end
        parent:SetScript("OnSizeChanged", resize)
        parent:SetScript("OnShow", addon.RefreshConfiguration)
        resize(parent, parent:GetWidth())
    end,
})
