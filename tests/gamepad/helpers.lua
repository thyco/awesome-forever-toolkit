local H = {}
local roots = setmetatable({}, {__mode = "k"})

-- Adapt only addon loading; execute the migrated production files themselves.
function H.loadfile(path)
    local source = assert(loadfile(path))
    return function(_, addon)
        local root = roots[addon]
        if not root then
            root = {modules = {Gamepad = addon}}
            roots[addon] = root
            assert(loadfile("AwesomeForeverToolkit/Core/Config.lua"))("AwesomeForeverToolkit", root)
        end

        if path:match("OverlayRuntime.lua$") then
            assert(loadfile("AwesomeForeverToolkit/Modules/Gamepad/Config.lua"))("AwesomeForeverToolkit", root)
            addon.Config.Initialize()
        end
        source("AwesomeForeverToolkit", root)
        if path:match("OverlayRuntime.lua$") then addon.Runtime.Start() end
    end
end
return H
