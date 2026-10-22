local _, root = ...
local addon = root.modules.Gamepad
local panels = {}
local faces = { "A", "B", "X", "Y" }
local modes = {
    { value = "native", label = "Native" },
    { value = "context", label = "Context" },
    { value = "always", label = "Always" },
}

local function Label(parent, text, x, y, width, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 25)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Checkbox(parent, text, x, y, callback)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", checkbox, "RIGHT", 1, 0)
    label:SetText(text)
    checkbox:SetHitRectInsets(0, -58, 0, 0)
    checkbox:SetScript("OnClick", callback)
    return checkbox
end

local function CreatePanel(frame, context)
    local window = frame
    local selectedStanceID
    local rows = {}

    local function Refresh()
        if not window then return end
        local locked = addon.Runtime.IsLocked()
        window.combat:SetText(locked and "Combat: changes are temporarily locked." or "Changes are saved and applied immediately.")

        local profileName = "Base (inherited by forms without an override)"
        local selectedExists = false
        for _, form in ipairs(addon.Runtime.GetForms()) do
            if form.spellID == selectedStanceID then
                profileName = form.name
                selectedExists = true
            end
        end
        if not selectedExists then selectedStanceID = nil end
        window.profile:SetText("Profile: " .. profileName .. "  >")

        for face, row in pairs(rows) do
            local config, inherited = addon.Runtime.GetConfig(face, selectedStanceID)
            local info = addon.Runtime.Describe(config)
            row.icon:SetTexture(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(info and info.name or "Drop a spell or macro")
            local status = addon.Runtime.IsActive(face) and "active" or "off"
            if addon.Runtime.IsEnabled(face) and not addon.Runtime.IsActive(face) then
                status = "enabled, temporarily inactive"
            end
            row.state:SetText((inherited and "Inherits base / " or "") .. status)
            row.clear:SetText(selectedStanceID and "Base" or "Clear")
            row.slot:SetEnabled(not locked)
            row.clear:SetEnabled(not locked)

            for _, mode in ipairs(modes) do
                local button = row.modes[mode.value]
                local selected = config.mode == mode.value
                button:SetChecked(selected)
                button:SetEnabled(not locked)
            end
        end

        local anyActive = false
        for _, face in ipairs(faces) do
            if addon.Runtime.IsEnabled(face) then anyActive = true end
        end
        window.enabled:SetChecked(anyActive)
        window.enabled:SetEnabled(not locked)
    end

    local function Result(ok, message)
        window.message:SetText((ok and "|cff80ff80" or "|cffff8080") .. tostring(message) .. "|r")
        addon.RefreshConfiguration()
    end

    local function Initialize()
        Label(frame, "Gamepad bindings", 20, -12, 560, "GameFontNormalLarge")

        Label(frame, "Drag spells from your spellbook or macros from /macro onto A, B, X or Y.", 20, -42, 560)
        Label(frame, "Context: combat or an enemy target; mouseover only without a target.\nAlways: also without combat or a target. Modifier and stance layers take priority.", 20, -65, 560, "GameFontHighlightSmall")
        frame.combat = Label(frame, "", 20, -103, 560, "GameFontNormalSmall")

        frame.profile = Button(frame, "", 20, -128, 560, function()
            local forms = addon.Runtime.GetForms()
            local nextID = forms[1] and forms[1].spellID
            if selectedStanceID then
                for index, form in ipairs(forms) do
                    if form.spellID == selectedStanceID then
                        nextID = forms[index + 1] and forms[index + 1].spellID
                        break
                    end
                end
            end
            selectedStanceID = nextID
            frame.message:SetText("Editing this profile does not change your current form. Base restores inheritance.")
            Refresh()
        end)

        for index, face in ipairs(faces) do
            local y = -175 - (index - 1) * 70
            local row = { modes = {} }
            rows[face] = row
            Label(frame, face, 23, y - 10, 20, "GameFontNormalLarge")

            local slot = CreateFrame("Button", nil, frame)
            row.slot = slot
            slot:SetSize(44, 44)
            slot:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, y)
            slot:RegisterForClicks("LeftButtonUp")
            slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            row.icon = slot:CreateTexture(nil, "ARTWORK")
            row.icon:SetAllPoints()
            slot:SetScript("OnReceiveDrag", function() Result(addon.ConfigurationActions.Drop(face, selectedStanceID)) end)
            slot:SetScript("OnClick", function() Result(addon.ConfigurationActions.Drop(face, selectedStanceID)) end)
            slot:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local config = addon.Runtime.GetConfig(face, selectedStanceID)
                if config.kind == "macro" then
                    GameTooltip:SetText("Macro: " .. tostring(config.macroName))
                    GameTooltip:AddLine("Uses the macro's own targeting rules.", 1, 1, 1, true)
                elseif config.spellID then GameTooltip:SetSpellByID(config.spellID)
                else GameTooltip:SetText("Drop a spell or macro here.") end
                GameTooltip:Show()
            end)
            slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

            row.name = Label(frame, "", 108, y - 3, 145)
            row.name:SetHeight(30)
            row.state = Label(frame, "", 108, y - 35, 145, "GameFontHighlightSmall")
            for modeIndex, mode in ipairs(modes) do
                row.modes[mode.value] = Checkbox(frame, mode.label, 258 + (modeIndex - 1) * 80, y - 8, function()
                    Result(addon.ConfigurationActions.SetMode(face, mode.value, selectedStanceID))
                end)
            end
            row.clear = Button(frame, "Clear", 505, y - 8, 72, function()
                Result(addon.ConfigurationActions.Clear(face, selectedStanceID))
            end)
        end

        frame.enabled = Checkbox(frame, "Enable overrides", 20, -461, function(self)
            addon.Runtime.RunCommand(self:GetChecked() and "on" or "off")
            frame.message:SetText("See chat for the result for each button.")
            addon.RefreshConfiguration()
        end)
        frame.enabled:SetHitRectInsets(0, -120, 0, 0)
        Label(frame, "Activation survives /reload. Assign jump elsewhere when overriding A.", 265, -461, 315, "GameFontHighlightSmall")
        frame.message = Label(frame, "", 20, -499, 560, "GameFontHighlightSmall")
        frame.message:SetHeight(32)
        frame:SetScript("OnShow", Refresh)
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
        frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        frame:RegisterEvent("UPDATE_MACROS")
        frame:SetScript("OnEvent", Refresh)
    end

    Initialize()
    context.controls["gamepad.refresh"] = {refresh = Refresh}
    context.controls["gamepad.rows"] = rows
    context.controls["gamepad.profile"] = frame.profile
    context.controls["gamepad.enabled"] = frame.enabled
    panels[#panels + 1] = { frame = frame, refresh = Refresh }
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
        frame:SetSize(600, 550)
        CreatePanel(frame, context)

        local function resize(_, width)
            local scale = math.min(1, math.max(1, width) / 600)
            frame:SetScale(scale)
            parent:SetHeight(550 * scale)
        end
        parent:SetScript("OnSizeChanged", resize)
        parent:SetScript("OnShow", addon.RefreshConfiguration)
        resize(parent, parent:GetWidth())
    end,
})
