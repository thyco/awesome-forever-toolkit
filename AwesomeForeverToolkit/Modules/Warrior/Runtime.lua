local _, root = ...
local addon = root.modules.Warrior
local frame = CreateFrame("Frame")

local function label(value, allowed, fallback)
    if not addon.Client.Readable(value) or type(value) ~= "string" then
        return fallback
    end

    return allowed[value] and value or fallback
end

local outputs = { underlay = true, none = true }
local stances = { battle = true, defensive = true, berserker = true, unknown = true }
local signals = { usable = true, ["low-rage"] = true, overlay = true,
    opening = true, inactive = true, unknown = true }
local cooldowns = { ready = true, blocked = true, unknown = true, ["n/a"] = true }
local ranges = { ["in"] = true, out = true, skipped = true, unknown = true }

local function member(container, key)
    if not addon.Client.Readable(container) or type(container) ~= "table" then
        return nil
    end

    local ok, value = pcall(function() return container[key] end)
    if ok and addon.Client.Readable(value) then
        return value
    end
end

local function learnedLabel(kind)
    local ranks = member(addon.ReactiveSpells.ids, kind)
    if type(ranks) ~= "table" then
        return "unknown"
    end

    local ok, count = pcall(function() return #ranks end)
    return ok and count > 0 and "learned" or "unknown"
end

local function selectionLabel(kind)
    if addon.Buttons.Mode() ~= "keyboard" then
        return addon.Buttons.SelectionLabel(addon.Config, kind)
    end

    local bar = addon.Client.Number(addon.Config.Get(kind .. "Bar"))
    local button = addon.Client.Number(addon.Config.Get(kind .. "Button"))
    if not bar or bar == 0 then
        return "not selected"
    end

    if bar < 1 or bar > 8 or bar ~= math.floor(bar)
        or not button or button < 1 or button > 12 or button ~= math.floor(button) then
        return "unknown"
    end

    return "bar " .. bar .. " button " .. button
end

local function booleanLabel(value, yes, no, fallback)
    local safe = addon.Client.Boolean(value)
    if safe == true then return yes end
    if safe == false then return no end
    return fallback
end

local function reactiveDiagnostics(kind, title, status)
    local range = kind == "execute" and
        " / range " .. label(member(status, "range"), ranges, "unknown") or ""

    print(title .. ": " .. learnedLabel(kind)
        .. " / " .. booleanLabel(member(status, "ready"), "ready", "not ready", "unknown")
        .. " / " .. label(member(status, "signal"), signals, "unknown")
        .. " / " .. label(member(status, "cooldown"), cooldowns, "unknown")
        .. range
        .. " / " .. selectionLabel(kind)
        .. " / glow " .. booleanLabel(member(status, "active"), "active", "inactive", "inactive"))
end

local function diagnostics()
    local feature = addon.BattleShoutReminder:Status()
    local warrior = addon.Client.IsWarrior() and "active" or "inactive"

    print("Awesome Forever Toolkit 0.1.0 / client 16001 / Warrior " .. warrior)
    print("Battle Shout underlay enabled: " .. tostring(addon.Config.Get("battleShoutEnabled")))
    print("Reminder: " .. label(member(feature, "output"), outputs, "none"))

    local reactive = addon.ReactiveAbilities:Status()
    print("Stance: " .. label(member(reactive, "stance"), stances, "unknown"))
    reactiveDiagnostics("overpower", "Overpower", member(reactive, "overpower"))
    reactiveDiagnostics("revenge", "Revenge", member(reactive, "revenge"))
    reactiveDiagnostics("execute", "Execute", member(reactive, "execute"))
    reactiveDiagnostics("victoryRush", "Victory Rush", member(reactive, "victoryRush"))
    reactiveDiagnostics("shieldBlock", "Shield Block", member(reactive, "shieldBlock"))
end

function addon:Diagnostics()
    diagnostics()
end

function addon:StartRuntime()
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    }) do
        frame:RegisterEvent(event)
    end
end

function addon:OnEvent(event)
    if event == "PLAYER_LOGIN" then
        self:Start()
        return
    end

    if not self.started or not self.active then
        return
    end

    local reminder = self.BattleShoutReminder
    if event == "PLAYER_LEAVING_WORLD" then
        reminder:Stop()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        reminder:Initialize()
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        self.BattleShoutIcon:ApplySettings()
    end

    reminder:Refresh()
end

frame:SetScript("OnEvent", function(_, event)
    addon:OnEvent(event)
end)
