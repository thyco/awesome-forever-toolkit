local _, root = ...
local addon = root.modules.Gamepad
local Overlay = {}
addon.Overlay = Overlay

Overlay.Routes = {
    A = { key = "PAD1", index = 4 },
    B = { key = "PAD2", index = 3 },
    X = { key = "PAD3", index = 1 },
    Y = { key = "PAD4", index = 2 },
}

function Overlay.BuildDriver(mode)
    if mode == "context" then
        return "[combat][@target,harm,nodead] override; [@target,exists] native; [@mouseover,harm,nodead] override; native"
    elseif mode == "always" then
        return "override"
    elseif mode == "native" then
        return "native"
    end
end

function Overlay.BuildMacro(name)
    if type(name) ~= "string" or name == "" or name:find("[\r\n;%[%]|]") then
        return nil
    end

    local body = "/cast [@target,exists][@mouseover,harm,nodead][] " .. name
    return #body <= 255 and body or nil
end

-- Adapted in principle from the user-supplied Controller Rebound 1.4.2:
-- stable override binding, restricted pre-click routing, native /click fallback.
-- The selected route remains unchanged until the physical press is released.
Overlay.ROUTER = [[
    if down then
        local state = GetGamePadState()
        local held = state and state.buttons
        local lt = held and held[self:GetAttribute("gaf-lt")]
        local rt = held and held[self:GetAttribute("gaf-rt")]
        local lb = held and held[self:GetAttribute("gaf-lb")]
        local rb = held and held[self:GetAttribute("gaf-rb")]
        local layer = "bare"
        if lb and rb then layer = "lbrb"
        elseif lb then layer = "lb"
        elseif rb then layer = "rb"
        elseif lt and rt then layer = "ltrt"
        elseif lt then layer = "lt"
        elseif rt then layer = "rt"
        end

        local bar = self:GetFrameRef(layer)
        local selected = layer
        local possess = self:GetFrameRef("possess")
        local stance = self:GetFrameRef("stance")
        if bar and possess and possess:IsShown() and possess:GetParent() == bar:GetParent() then
            selected = "possess"
        elseif bar and stance and stance:IsShown() and stance:GetParent() == bar:GetParent() then
            selected = "stance"
        end

        local macro = self:GetAttribute("gaf-native-" .. selected)
        local state = self:GetAttribute("gaf-state")
        local macroName
        if selected == "bare" and state and state ~= "native" then
            macroName = self:GetAttribute("gaf-macro-" .. state)
            macro = self:GetAttribute("gaf-text-" .. state)
        end
        local nativeButton = self:GetFrameRef("button-" .. selected)
        local directAction = (selected == "lt" or selected == "rt" or selected == "ltrt" or selected == "stance")
            and nativeButton and nativeButton:GetAttribute("type") == "action"
            and nativeButton:GetID() > 0

        -- A /click macro forwarding to an action-slot macro introduces macro
        -- nesting. Mirror the native storage ID/page on our own secure button
        -- instead. Reserved UI controls and flyouts retain their custom click path.
        if directAction then
            self:SetID(nativeButton:GetID())
            self:SetAttribute("actionpage", nativeButton:GetAttribute("actionpage"))
            self:SetAttribute("macro1", nil)
            self:SetAttribute("macrotext1", nil)
            self:SetAttribute("type1", "action")
        else
            self:SetID(0)
            self:SetAttribute("actionpage", nil)
            self:SetAttribute("macro1", macroName)
            self:SetAttribute("macrotext1", macro)
            self:SetAttribute("type1", "macro")
        end
    end
]]
