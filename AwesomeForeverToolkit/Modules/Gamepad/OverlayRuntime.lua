local addonName, root = ...
local addon = root.modules.Gamepad
local O = addon.Overlay
local M = addon.ActionModel
local VERSION = root.version or "0.1.0"
local active = {}
local routers = {}
local visuals = {}
local history = {}
local pendingStop = false
local pendingRefresh = false
local pendingRestore = false
local faulted = false
local macroStartupDeadline = GetTime() + 5
local faces = { "A", "B", "X", "Y" }
local barNames = {
    bare = "topBar", lt = "leftBar", rt = "rightBar", ltrt = "bottomBar",
    lb = "friendlyTargetingBar", rb = "hostileTargetingBar", lbrb = "shortcutsBar",
    stance = "stanceBar", possess = "possessBar",
}

local function Log(text)
    local line = string.format("%.1f %s", GetTime(), tostring(text))
    history[#history + 1] = line
    if #history > 40 then table.remove(history, 1) end
    print("|cff65c9ffAwesome Forever Toolkit gamepad " .. VERSION .. ":|r " .. line)
end

local function Database()
    return addon.Config.Bindings()
end

local function Enabled()
    return addon.Config.Enabled()
end

local function Combat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local function Unit()
    return GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
end

local function NativeButton(bar, face)
    return bar and bar.Right and bar.Right["ActionButton" .. O.Routes[face].index]
end

local function NativeMacro(button)
    local name = button and button:GetName()
    if not name then return nil end

    local macro = string.format("/click %s LeftButton 1\n/click %s LeftButton 0", name, name)
    return #macro <= 255 and macro or nil
end

local function Visual(face, native)
    if visuals[face] then return visuals[face] end

    local frame = addon.OverlayVisual.Create(native)

    visuals[face] = frame
    return frame
end

local function Stop(face, forgetPreference)
    -- Internal cleanup must never change the user's saved activation choice.
    if forgetPreference then
        for _, current in ipairs(faces) do
            if not face or current == face then Enabled()[current] = nil end
        end
    end

    if Combat() then
        pendingStop = true
        return false, "Stopping after combat; /reload stops immediately."
    end

    for _, current in ipairs(faces) do
        if (not face or current == face) and active[current] then
            local router = routers[current]
            ClearOverrideBindings(router)
            UnregisterAttributeDriver(router, "gaf-state")
            active[current] = nil
            visuals[current]:Hide()
        end
    end
    pendingStop = false
    return true, "Override disabled; native controls restored."
end

local function Arm(face, config)
    if Combat() then return false, "Bindings can only be changed outside combat." end
    if faulted then return false, "An error occurred. Use /reload first." end
    if not O.Routes[face] or type(config) ~= "table" or not O.BuildDriver(config.mode) then
        return false, "Invalid button or mode."
    end
    local actions, driver, reason = M.Prepare(config)
    if not actions then return false, driver, reason end
    if not next(actions) then return Stop(face) end

    if C_AddOns and C_AddOns.IsAddOnLoaded("ControllerRebound") then
        return false, "Disable Controller Rebound and /reload; both addons would claim the same buttons."
    end

    local unit = Unit()
    local bars = unit and unit.actionBars
    if not bars or not InputUtil or not InputUtil.IsGamepadUIEnabled() then
        return false, "Enable the Blizzard gamepad layout first."
    end

    local native = NativeButton(bars.topBar, face)
    if not native or not native.SpecialActionIcon then return false, "Native face button is missing." end

    local macros = {}
    for layer, name in pairs(barNames) do
        macros[layer] = NativeMacro(NativeButton(bars[name], face))
        if not macros[layer] then return false, "Native layer is missing or its name is too long: " .. layer end
    end

    local indices = {}
    for key, binding in pairs({ lt = "PADLTRIGGER", rt = "PADRTRIGGER", lb = "PADLSHOULDER", rb = "PADRSHOULDER" }) do
        local index = C_GamePad.ButtonBindingToIndex(binding)
        if type(index) ~= "number" or index < 0 then return false, "Gamepad index is missing: " .. binding end
        indices[key] = index + 1
    end

    Stop(face)
    local router = routers[face]
    if not router then
        router = CreateFrame("Button", "AFTGamepadRouter" .. face, UIParent,
            "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
        router:SetSize(1, 1)
        router:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
        router:EnableMouse(false)
        router:RegisterForClicks("AnyDown", "AnyUp")
        router:SetAttribute("useOnKeyDown", true)
        SecureHandlerWrapScript(router, "OnClick", router, O.ROUTER)
        routers[face] = router
    end

    for layer, name in pairs(barNames) do
        router:SetFrameRef(layer, bars[name])
        router:SetFrameRef("button-" .. layer, NativeButton(bars[name], face))
        router:SetAttribute("gaf-native-" .. layer, macros[layer])
    end
    for key, index in pairs(indices) do router:SetAttribute("gaf-" .. key, index) end
    for key, action in pairs(actions) do
        router:SetAttribute("gaf-text-" .. key, action.macrotext)
        router:SetAttribute("gaf-macro-" .. key, action.macroName)
    end
    router:SetID(0)
    router:SetAttribute("actionpage", nil)
    router:SetAttribute("macro1", nil)
    router:SetAttribute("type1", "macro")
    router:SetAttribute("macrotext1", macros.bare)
    router:SetAttribute("gaf-state", "native")

    local visual = Visual(face, native)
    visual:Hide()
    active[face] = { actions = actions, native = native }
    RegisterAttributeDriver(router, "gaf-state", driver)
    if faulted or not active[face] then return false, "Activation blocked; use /reload." end

    SetOverrideBindingClick(router, true, O.Routes[face].key, router:GetName(), "LeftButton")
    if faulted or not active[face] then
        ClearOverrideBindings(router)
        return false, "Binding blocked; use /reload."
    end

    return true, face .. " active: Base and form profiles applied."
end

local function HasOverride(config)
    if config.mode and config.mode ~= "native" then return true end
    for _, profile in pairs(config.stances or {}) do
        if profile.mode and profile.mode ~= "native" then return true end
    end
    return false
end

-- Shared entry point for chat commands and the configuration window.
addon.Runtime = {
    IsLocked = Combat,
    IsActive = function(face) return active[face] ~= nil end,
    IsEnabled = function(face) return Enabled()[face] == true end,
    GetConfig = function(face, stanceID)
        local config = Database()[face] or { mode = "native" }
        return M.Profile(config, stanceID)
    end,
    GetForms = M.Forms,
    Describe = M.Resolve,
}

function addon.Runtime.Configure(face, mode, action, stanceID, inherit)
    if Combat() then return false, "Bindings can only be changed outside combat." end
    if not O.Routes[face] or not O.BuildDriver(mode) then
        return false, "Invalid button or mode."
    end
    if stanceID and (type(stanceID) ~= "number" or stanceID <= 0) then
        return false, "Invalid form."
    end

    local profile = type(action) == "table" and M.Copy(action) or { spellID = action }
    profile.stances = nil
    profile.mode = mode
    if mode ~= "native" and not inherit then
        local resolved, message = M.Resolve(profile)
        if not resolved then return false, message end
    end

    local config = M.WithProfile(Database()[face] or {mode = "native"}, stanceID, not inherit and profile or nil)
    local executed, ok, message = pcall(Arm, face, config)
    if not executed then
        faulted = true
        pendingStop = true
        pcall(Stop)
        Log("Configuration failed: " .. tostring(ok) .. ". Use /reload.")
        return false, "Configuration failed; use /reload. See chat for details."
    end

    if ok then
        Database()[face] = config
        Enabled()[face] = HasOverride(config) or nil
    end
    return ok, message
end

local function RefreshVisuals()
    local unit = Unit()
    local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
    local gameplay = unit and InputUtil.IsGamepadUIEnabled() and GamepadMainActionBarFrame:IsShown()
        and manager and manager:IsOnlyCoreBindingSetActive()
        and unit:GetActiveBar() == unit.actionBars.topBar

    for face, config in pairs(active) do
        local visual = visuals[face]
        local action = config.actions[routers[face]:GetAttribute("gaf-state")]
        local show = gameplay and config.native:IsShown() and action ~= nil
        if show then show = addon.OverlayVisual.Sync(visual, config.native) end
        visual:SetShown(show == true)
        if show then
            visual.icon:SetTexture(action.iconID)
            local spellID = action.spellID
            if action.macroName and GetMacroSpell then spellID = GetMacroSpell(action.macroName) end
            local duration = spellID and C_Spell.GetSpellCooldownDuration(spellID)
            if duration then visual.cooldown:SetCooldownFromDurationObject(duration)
            else visual.cooldown:Clear() end
        end
    end
end

-- Optional visual-only integration. Consumers receive fresh descriptors, never
-- secure routers or configuration tables. No dependency on Utils is required.
addon.Visuals = {
    version = 1,
    GetFrames = function()
        local frames = {}
        for _, visual in pairs(visuals) do frames[#frames + 1] = visual end
        return frames
    end,
    GetEntries = function()
        local entries = {}
        for face, config in pairs(active) do
            local visual = visuals[face]
            local action = config.actions[routers[face]:GetAttribute("gaf-state")]
            if visual and visual:IsShown() and action then
                entries[#entries + 1] = {button = visual, spellID = action.spellID, macroName = action.macroName}
            end
        end
        return entries
    end,
}

local function Status()
    local version, build = GetBuildInfo()
    Log("build=" .. version .. "/" .. build .. " faulted=" .. tostring(faulted))
    for _, face in ipairs(faces) do
        local cfg = Database()[face]
        local router = routers[face]
        Log(face .. " mode=" .. tostring(cfg and cfg.mode or "native") .. " enabled=" .. tostring(Enabled()[face] == true) .. " active=" .. tostring(active[face] ~= nil)
            .. " state=" .. tostring(router and router:GetAttribute("gaf-state")))
    end
    Log("hard=" .. tostring(UnitExists("target")) .. " mouseover=" .. tostring(UnitExists("mouseover")))
end

local function Command(text)
    local command, rest = text:match("^%s*(%S*)%s*(.-)%s*$")
    if command == "set" then
        local face, mode, spell = rest:match("^(%S+)%s+(%S+)%s*(.*)$")
        face = face and face:upper()
        if not O.Routes[face] or not O.BuildDriver(mode) then
            Log("/aft gamepad set A context <spell ID or spell link> | /aft gamepad set A always <spell> | /aft gamepad set A native")
            return
        end
        if Combat() then Log("Bindings can only be changed outside combat."); return end

        local id = tonumber(spell:match("|Hspell:(%d+)")) or tonumber(spell)
        if mode == "native" then id = addon.Runtime.GetConfig(face) end

        local ok, message = addon.Runtime.Configure(face, mode, id)
        Log(message)
    elseif command == "on" then
        if Combat() then Log("Activation is only available outside combat."); return end

        if not next(Database()) then
            local storage = GamepadActionBarBindingUtil
                and GamepadActionBarBindingUtil.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID
            if not InputUtil or not InputUtil.IsGamepadUIEnabled or not InputUtil.IsGamepadUIEnabled()
                or not storage or not GetActionInfo then
                Log("Enable the Blizzard gamepad layout first.")
                return
            end

            local index = storage(1, 13)
            if type(index) ~= "number" then
                Log("The native gamepad action slots are not ready yet.")
                return
            end

            local kind, id = GetActionInfo(index)
            if kind ~= "spell" then Log("Place a spell on page 1, LT+X first."); return end
            Database().A = { mode = "context", spellID = id }
        end
        for _, face in ipairs(faces) do
            local cfg = Database()[face]
            if cfg then
                Enabled()[face] = HasOverride(cfg) or nil
                local _, message = Arm(face, cfg)
                Log(message)
            end
        end
    elseif command == "off" then
        local _, message = Stop(nil, true)
        Log(message)
    elseif command == "config" or command == "" then
        addon.OpenConfiguration()
    elseif command == "status" then
        Status()
        Log("/aft gamepad config | on | off | set A context/always <spell ID or spell link> | set A native | log")
    elseif command == "log" then
        for _, line in ipairs(history) do print("AFT gamepad " .. line) end
    else
        Log("Use /aft gamepad for help.")
    end
end

addon.Runtime.RunCommand = function(text)
    local ok, err = pcall(Command, text)
    if not ok then
        faulted = true
        pendingStop = true
        Log("ERROR: " .. tostring(err) .. ". Use /reload before continuing.")
        if not Combat() then pcall(Stop) end
    end
    if addon.RefreshConfiguration then addon.RefreshConfiguration() end
end

-- A missing macro during startup may simply not have been loaded yet.
-- Keep retrying briefly; all other errors and explicit user commands report immediately.
local function ApplySavedBinding(face, prefix)
    local executed, ok, message, reason = pcall(Arm, face, Database()[face])
    if executed and ok then return end

    pcall(Stop, face)
    if executed and reason == "missing-macro" and not faulted and GetTime() < macroStartupDeadline then
        pendingRestore = true
        return
    end

    Log(face .. prefix .. tostring(executed and message or ok))
end

local function RefreshBindings()
    if faulted then return end
    if Combat() then pendingRefresh = true; return end
    pendingRefresh = false

    for _, face in ipairs(faces) do
        if Enabled()[face] and Database()[face] then
            ApplySavedBinding(face, ": ")
        end
    end
end

local function NativeReady()
    local unit = Unit()
    if not unit or not unit.actionBars or not InputUtil or not InputUtil.IsGamepadUIEnabled() then return false end

    for _, face in ipairs(faces) do
        if Enabled()[face] and Database()[face] then
            for _, barName in pairs(barNames) do
                local button = NativeButton(unit.actionBars[barName], face)
                if not button or not button:GetName() then return false end
            end
            if not NativeButton(unit.actionBars.topBar, face).SpecialActionIcon then return false end
        end
    end
    return true
end

local function RestoreBindings()
    if not pendingRestore or Combat() or faulted then return end
    local enabled = Enabled()
    if next(enabled) and not NativeReady() then return end

    pendingRestore = false
    for _, face in ipairs(faces) do
        if enabled[face] and Database()[face] then
            ApplySavedBinding(face, " was not automatically activated: ")
        end
    end
    if addon.RefreshConfiguration then addon.RefreshConfiguration() end
end

function addon.Runtime.Start()
    if addon.Runtime.frame then return end

    macroStartupDeadline = GetTime() + 5
    pendingRestore = true
    local events = CreateFrame("Frame")
    addon.Runtime.frame = events
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "UPDATE_MACROS", "UPDATE_SHAPESHIFT_FORMS", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, blamedAddon, action)
        if event == "PLAYER_LOGIN" then
            macroStartupDeadline = GetTime() + 5
            pendingRestore = true
            RestoreBindings()
        elseif event == "UPDATE_MACROS" or event == "UPDATE_SHAPESHIFT_FORMS"
            or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            RefreshBindings()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingStop then
                local ok, _, message = pcall(Stop)
                Log(ok and message or "Stopping failed; use /reload.")
            end
            if pendingRefresh then RefreshBindings() end
        elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN")
            and blamedAddon == addonName and next(active) then
            faulted = true
            pendingStop = true
            Log(event .. ": " .. tostring(blamedAddon) .. " / " .. tostring(action) .. ". Use /reload.")
            if not Combat() then pcall(Stop) end
        end

        if addon.RefreshConfiguration then addon.RefreshConfiguration() end
    end)

    local elapsedSinceRestore = 0
    local elapsedSinceRefresh = 0
    events:SetScript("OnUpdate", function(_, elapsed)
        if not next(active) and not pendingRestore then return end
        elapsedSinceRestore = elapsedSinceRestore + elapsed
        elapsedSinceRefresh = elapsedSinceRefresh + elapsed
        if elapsedSinceRefresh < 0.05 then return end
        elapsedSinceRefresh = 0
        if pendingRestore and elapsedSinceRestore >= 0.5 then
            elapsedSinceRestore = 0
            RestoreBindings()
        end

        local ok, err = pcall(RefreshVisuals)
        if not ok and not faulted then
            faulted = true
            pendingStop = true
            Log("Overlay update failed: " .. tostring(err) .. ". Use /reload.")
            if not Combat() then pcall(Stop) end
        end
    end)
end
