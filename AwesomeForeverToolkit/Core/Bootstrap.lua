local _, addon = ...
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function() addon.Start() end)

SLASH_AWESOMEFOREVERTOOLKIT1 = "/aft"
SLASH_AWESOMEFOREVERTOOLKIT2 = "/af"
SlashCmdList.AWESOMEFOREVERTOOLKIT = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()

    if command == "" or command == "config" then
        if addon.Window then addon.Window:Open() end
        return
    end

    local module = command == "warrior" and addon.modules.Warrior
        or command == "hunter" and addon.modules.Hunter
        or command == "utilities" and addon.modules.Utilities
        or command == "gamepad" and addon.modules.Gamepad
    if module and module.active and module.Diagnostics then
        module:Diagnostics(rest)
        return
    end

    print("Awesome Forever Toolkit " .. addon.version .. " | /aft config")
    for _, entry in ipairs(addon.moduleOrder) do
        print(entry.id .. ": " .. (entry.status or "not started"))
    end
end
