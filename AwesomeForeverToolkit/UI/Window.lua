local _, addon = ...
local Window = {pages = {}, order = {}, controls = {}, settings = {}, cache = {}}
addon.Window = Window

function Window:RegisterPage(page)
    assert(not self.pages[page.id], "Duplicate settings page")
    self.pages[page.id] = page
    self.order[#self.order + 1] = page
end

function Window:MarkReloadRequired()
    self.reloadRequired = true
    self:Refresh()
end

function Window:Refresh()
    for _, control in pairs(self.controls) do
        if control.refresh then control.refresh() end
    end

    if self.applyButton then
        self.applyButton:SetText(self.reloadRequired and "Apply & Reload" or "Close")
    end
end

function Window:ShowPage(id)
    local page = self.pages[id]
    if not page or page.available and not page.available() then return false end
    addon.ClearPreviews()

    for _, entry in pairs(self.cache) do entry.frame:Hide() end
    if not self.cache[id] then
        local frame = CreateFrame("Frame", nil, self.scroll)
        frame:SetSize(math.max(1, self.scroll:GetWidth()), 100)
        local context = {controls = {}, settings = {}, frame = frame}
        page.build(frame, context)
        self.cache[id] = context
    end

    local context = self.cache[id]
    self.currentPage = id
    self.controls, self.settings = context.controls, context.settings
    self.content = context.frame
    self.scroll:SetScrollChild(context.frame)
    context.frame:SetWidth(math.max(1, self.scroll:GetWidth()))
    context.frame:Show()
    self.scroll:SetVerticalScroll(0)
    addon.Config.GetSection("character", "ui").lastPage = id

    for key, button in pairs(self.navigation) do
        button:SetText((key == id and "|cffffd24a" or "|cffffffff") .. self.pages[key].label .. "|r")
    end
    self:Refresh()
    return true
end

function Window:Close()
    if self.reloadRequested or InCombatLockdown() then return end

    if self.reloadRequired then
        self.reloadRequested = true
        ReloadUI()
        return
    end

    addon.ClearPreviews()
    self.canvas:Hide()
end

function Window:Open()
    if InCombatLockdown() then
        print("Awesome Forever Toolkit: open configuration outside combat.")
        return
    end

    self:Initialize()
    self.canvas:Show()
    self.canvas:Raise()
end

function Window:Initialize()
    if self.canvas then return end

    local canvas = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    self.canvas = canvas
    canvas:SetSize(math.min(860, GetScreenWidth() - 40), math.min(740, GetScreenHeight() - 80))
    canvas:SetPoint("CENTER")
    canvas:SetFrameStrata("DIALOG")
    canvas:SetToplevel(true)
    canvas:SetMovable(true)
    canvas:SetClampedToScreen(true)
    canvas:EnableMouse(true)
    canvas:EnableKeyboard(true)
    if not InCombatLockdown() then canvas:SetPropagateKeyboardInput(true) end
    canvas:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then Window:Close() end
    end)
    canvas:RegisterForDrag("LeftButton")
    canvas:SetScript("OnDragStart", function() canvas:StartMoving() end)
    canvas:SetScript("OnDragStop", function() canvas:StopMovingOrSizing() end)
    canvas:RegisterEvent("PLAYER_REGEN_DISABLED")
    canvas:SetScript("OnEvent", function() canvas:Hide() end)
    canvas:SetScript("OnHide", function() addon.ClearPreviews() end)
    canvas:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    canvas:SetBackdropColor(0.035, 0.035, 0.045, 0.98)
    canvas:SetBackdropBorderColor(0.35, 0.31, 0.22, 1)
    canvas:Hide()

    local icon = canvas:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", 14, -10)
    icon:SetTexture("Interface\\AddOns\\AwesomeForeverToolkit\\Media\\Icon.tga")
    addon.Widgets.Text(canvas, "Awesome Forever Toolkit", 60, -18, "GameFontNormalLarge")

    local close = CreateFrame("Button", nil, canvas, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() self:Close() end)
    self.closeButton = close
    local apply = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    apply:SetSize(160, 28)
    apply:SetPoint("BOTTOMRIGHT", -18, 12)
    apply:SetScript("OnClick", function() self:Close() end)
    self.applyButton = apply

    self.scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT", 204, -60)
    self.scroll:SetPoint("BOTTOMRIGHT", -36, 52)
    self.scroll:SetScript("OnSizeChanged", function(_, width)
        for _, entry in pairs(self.cache) do entry.frame:SetWidth(math.max(1, width)) end
    end)
    self.navigation = {}
    local rank = {general = 1, utilities = 2, ["warrior.reminders"] = 3, ["warrior.stance"] = 4, graphics = 5}
    table.sort(self.order, function(a, b) return (rank[a.id] or 99) < (rank[b.id] or 99) end)
    local y, parent = -64, nil
    for _, page in ipairs(self.order) do
        if not page.available or page.available() then
            if page.parent and page.parent ~= parent then
                addon.Widgets.Text(canvas, page.parent, 18, y, "GameFontNormal")
                y = y - 26
            end
            parent = page.parent
            local button = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
            button:SetSize(174, 28)
            button:SetPoint("TOPLEFT", 14, y)
            button:SetText(page.label)
            button:SetScript("OnClick", function() self:ShowPage(page.id) end)
            self.navigation[page.id] = button
            y = y - 34
        end
    end

    local warrior = addon.modules.Warrior
    if warrior and warrior.active then
        warrior.Config.Subscribe(function() self:MarkReloadRequired() end)
    end
    local utilities = addon.modules.Utilities
    if utilities and utilities.active then utilities.Config.Subscribe(function() self:Refresh() end) end

    if Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory
        and CreateSettingsButtonInitializer then
        local category, layout = Settings.RegisterVerticalLayoutCategory("Awesome Forever Toolkit")
        self.category = category
        layout:AddInitializer(CreateSettingsButtonInitializer("Configuration", "Open configuration",
            function() self:Open() end))
        Settings.RegisterAddOnCategory(category)
    end

    local last = addon.Config.GetSection("character", "ui").lastPage
    if not self:ShowPage(type(last) == "string" and last or "general") then self:ShowPage("general") end
    canvas:SetScript("OnShow", function()
        if not InCombatLockdown() then canvas:SetPropagateKeyboardInput(true) end
        self:Refresh()
    end)
    self:Refresh()
end
