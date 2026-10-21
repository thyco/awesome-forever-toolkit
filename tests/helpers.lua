local H = {}
function H.new()
    local world = { addon = {}, frames = {}, class = "WARRIOR", loaded = {}, messages = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.SlashCmdList = {}
    env.UnitClass = function() return world.class, world.class end
    env.InCombatLockdown = function() return world.combat == true end
    env.C_AddOns = { IsAddOnLoaded = function(name) return world.loaded[name] == true end }
    env.print = function(message) world.messages[#world.messages + 1] = message end
    env.CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        world.frames[#world.frames + 1] = frame
        return frame
    end
    world.env = env

    function world:load(files)
        for _, path in ipairs(files) do
            assert(loadfile("AwesomeForeverToolkit/" .. path .. ".lua", "t", env))("AwesomeForeverToolkit", self.addon)
        end
        return self.addon
    end

    function world:loadManifest()
        for line in io.lines("AwesomeForeverToolkit/AwesomeForeverToolkit.toc") do
            if line:match("%.lua$") and not line:match("^Libs/") then
                self:load({(line:gsub("%.lua$", ""))})
            end
        end
        return self.addon
    end

    function world:fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end
    return world
end
return H
