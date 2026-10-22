local _, root = ...
local addon = {legacy = "GamepadAssistForever"}
root.RegisterModule("Gamepad", addon)

function addon:Start()
    self.Config.Initialize()
    self.Runtime.Start()
end

function addon:Diagnostics(command)
    self.Runtime.RunCommand(command or "")
end

function addon.OpenConfiguration()
    root.Window:Open()
    if not InCombatLockdown() then root.Window:ShowPage("gamepad.bindings") end
end
