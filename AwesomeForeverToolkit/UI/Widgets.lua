local _, addon = ...
local Widgets = {}
addon.Widgets = Widgets

function Widgets.Text(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

function Widgets.Section(parent, title, description, y, height)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    section:SetHeight(height)
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    section:SetBackdropColor(0.035, 0.035, 0.045, 0.8)
    section:SetBackdropBorderColor(0.35, 0.31, 0.22, 1)

    Widgets.Text(section, title, 16, -14, "GameFontNormalLarge")
    local subtitle = Widgets.Text(section, description, 16, -38)
    subtitle:SetPoint("TOPRIGHT", section, "TOPRIGHT", -16, -38)
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    return section
end

function Widgets.Checkbox(parent, label, y, setting)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    check.Text:SetText(label)
    check.Text:SetFontObject("GameFontHighlight")
    check:SetScript("OnClick", function(self)
        setting:SetValue(not not self:GetChecked())
    end)
    check.refresh = function()
        check:SetChecked(setting:GetValue())
    end
    return check
end

function Widgets.Dropdown(parent, label, y, setting, options)
    Widgets.Text(parent, label, 20, y - 7, "GameFontHighlight")
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 266, y)
    dropdown:SetWidth(210)
    dropdown.options = options
    dropdown:SetupMenu(function(_, rootDescription)
        for _, option in ipairs(options) do
            local value, text = option.value, option.label
            rootDescription:CreateRadio(text,
                function(candidate) return setting:GetValue() == candidate end,
                function(candidate) setting:SetValue(candidate) end, value)
        end
    end)

    dropdown.refresh = function()
        local value = setting:GetValue()
        dropdown.selectedValue = value

        for _, option in ipairs(options) do
            if option.value == value then
                dropdown:OverrideText(option.label)
                break
            end
        end
    end
    return dropdown
end

function Widgets.Color(parent, label, y, setting)
    Widgets.Text(parent, label, 20, y - 5, "GameFontHighlight")

    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetPoint("TOPLEFT", parent, "TOPLEFT", 266, y)
    swatch:SetSize(26, 24)
    swatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    swatch:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)

    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)

    local function rgb()
        local hex = setting:GetValue()
        return tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
    end

    swatch.refresh = function()
        local r, g, b = rgb()
        fill:SetColorTexture(r, g, b, 1)
    end
    swatch:SetScript("OnClick", function()
        local previous = setting:GetValue()
        local r, g, b = rgb()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function()
                local red, green, blue = ColorPickerFrame:GetColorRGB()
                if not addon.Client.Number(red) or not addon.Client.Number(green)
                    or not addon.Client.Number(blue) or red < 0 or red > 1
                    or green < 0 or green > 1 or blue < 0 or blue > 1 then
                    return
                end

                setting:SetValue(string.format("ff%02x%02x%02x",
                    math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5),
                    math.floor(blue * 255 + 0.5)))
            end,
            cancelFunc = function()
                setting:SetValue(previous)
            end,
        })
    end)
    swatch.refresh()

    return swatch
end

function Widgets.GraphicsSetting(parent, setting, y, graphics)
    Widgets.Text(parent, setting.label, 16, y, "GameFontHighlight")

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y - 32)
    slider:SetSize(180, 20)
    slider:SetMinMaxValues(setting.min, setting.max)
    if slider.SetValueStep then
        slider:SetValueStep(setting.step)
    end
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    Widgets.Tooltip(slider, setting.description)

    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", parent, "TOPLEFT", 220, y - 26)
    reset:SetSize(120, 24)
    reset:SetText("Reset to default")
    Widgets.Tooltip(reset, "Restore only this setting to the current WoW client's default.")

    local status = Widgets.Text(parent, "", 16, y - 68)
    local control = { slider = slider, reset = reset, status = status }
    local updating = false

    function control.refresh()
        local state = graphics.Status(setting.key)
        slider:SetEnabled(state.writable)
        reset:SetEnabled(state.writable and state.default ~= nil)

        updating = true
        slider:SetValue(math.max(setting.min, math.min(setting.max, state.value or setting.min)))
        updating = false

        if not state.available then
            status:SetText("Unavailable on this client")
        else
            status:SetText("Current: " .. tostring(state.value)
                .. "  |  Default: " .. tostring(state.default or "unavailable"))
        end
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if updating or not addon.Client.Number(value) then
            return
        end

        local steps = math.floor((value - setting.min) / setting.step + 0.5)
        local selected = math.max(setting.min, math.min(setting.max, setting.min + steps * setting.step))
        graphics.Set(setting.key, selected)
        control.refresh()
    end)
    reset:SetScript("OnClick", function()
        graphics.Reset(setting.key)
        control.refresh()
    end)
    control.refresh()

    return control
end

function Widgets.Tooltip(frame, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end


function Widgets.Setting(store, key)
    return {
        GetValue = function() return store.Get(key) end,
        SetValue = function(_, value)
            store.Set(key, value)
            addon.Window:Refresh()
        end,
    }
end

function Widgets.Options(first, last, step, prefix, suffix)
    local options = {}
    for value = first, last, step do
        options[#options + 1] = {value = value, label = (prefix or "") .. value .. (suffix or "")}
    end
    return options
end

function Widgets.Layout(parent, context, prefix, store)
    local layout = {y = -12}

    function layout:Heading(text)
        Widgets.Text(parent, text, 18, self.y, "GameFontNormalLarge")
        self.y = self.y - 34
    end

    function layout:Text(text)
        local label = Widgets.Text(parent, text, 20, self.y)
        label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, self.y)
        self.y = self.y - 38
    end

    function layout:Field(kind, key, label, options)
        local setting = Widgets.Setting(store, key)
        context.settings[prefix .. "." .. key] = setting
        context.controls[prefix .. "." .. key] = Widgets[kind](parent, label, self.y, setting, options)
        self.y = self.y - (kind == "Checkbox" and 36 or 44)
    end

    function layout:Button(key, label, callback)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(230, 28)
        button:SetPoint("TOPLEFT", 20, self.y)
        button:SetText(label)
        button:SetScript("OnClick", callback)
        context.controls[prefix .. "." .. key] = button
        self.y = self.y - 44
    end

    function layout:Finish()
        parent:SetHeight(-self.y + 16)
    end

    return layout
end
