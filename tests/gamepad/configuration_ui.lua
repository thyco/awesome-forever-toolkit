local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end

-- Frame fixtures exercise the real UI callbacks; rendering remains an in-game check.
local function fixture()
    local frames, settings = {}, {}
    local function frame(kind, parent)
        local f = {kind = kind, parent = parent, scripts = {}, shown = true, enabled = true}
        local methods = {}
        function methods:SetScript(event, fn) self.scripts[event] = fn end
        function methods:RegisterEvent(event) self[event] = true end
        function methods:Hide() self.shown = false end
        function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
        function methods:IsShown() return self.shown end
        function methods:SetText(text) self.text = text end
        function methods:SetChecked(value) self.checked = value end
        function methods:GetChecked() return self.checked end
        function methods:SetEnabled(value) self.enabled = value end
        function methods:CreateFontString() return frame('FontString', self) end
        function methods:CreateTexture() return frame('Texture', self) end
        setmetatable(f, {__index = function(_, key) return methods[key] or function() end end})
        frames[#frames + 1] = f
        return f
    end
    UIParent = frame('Root')
    CreateFrame = function(kind, name, parent, template)
        local f = frame(kind, parent)
        if template == 'BasicFrameTemplateWithInset' then f.TitleText = frame('FontString', f) end
        return f
    end
    UISpecialFrames, tinsert = {}, table.insert
    Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
            settings.canvas, settings.name = canvas, name
            return {GetID = function() return 42 end}
        end,
        RegisterAddOnCategory = function(category) settings.category = category end,
    }
    local state = {mode = 'context', active = true, enabled = true}
    local addon = {
        Runtime = {
            IsLocked = function() return state.locked end,
            GetForms = function() return {} end,
            GetConfig = function() return {mode = state.mode, spellID = 133} end,
            Describe = function() return {name = 'Fireball', iconID = 1} end,
            IsActive = function() return state.active end,
            IsEnabled = function() return state.enabled end,
            RunCommand = function(command)
                state.enabled = command == "on"
                state.active = state.enabled
            end,
        },
        ConfigurationActions = {
            SetMode = function(_, mode)
                if state.reject then return false, 'Rejected' end
                state.mode = mode
                return true, 'Saved'
            end,
            Drop = function(face) state.dropped = face; return true, 'Saved' end,
        },
    }
    UnitClass = function() return "Hunter", "HUNTER" end
    local root = {modules = {Gamepad = addon}, Window = {}}
    root.Window.RegisterPage = function(_, page) settings.page = page end
    addon.active = true
    assert(loadfile('AwesomeForeverToolkit/Modules/Gamepad/Pages.lua'))('AwesomeForeverToolkit', root)
    addon.OpenConfiguration = function()
        if not settings.canvas then
            settings.canvas = frame('Content')
            settings.canvas.GetWidth = function() return 620 end
            settings.page.build(settings.canvas, {controls = {}})
        end
        settings.canvas:Show()
        addon.RefreshConfiguration()
    end
    return addon, state, frames, settings
end
local function checks(frames)
    local result = {}
    for _, f in ipairs(frames) do if f.kind == 'CheckButton' then result[#result + 1] = f end end
    return result
end

test('class page contains actual editable controls', function()
    local addon, _, frames, settings = fixture()

    assert(settings.page.parent == 'Hunter')
    addon.OpenConfiguration()

    assert(#checks(frames) == 13, 'four mode groups and an active checkbox expected in settings')
end)

test('only saved mode checked and clicking another mode updates group', function()
    local addon, state, frames = fixture()
    addon.OpenConfiguration()
    local controls = checks(frames)
    assert(#controls >= 12, 'checkbox controls missing')
    local first = #controls - 12
    assert(not controls[first].checked and controls[first + 1].checked and not controls[first + 2].checked)

    controls[first + 2].scripts.OnClick(controls[first + 2])

    assert(state.mode == 'always')
    assert(not controls[first + 1].checked and controls[first + 2].checked)
end)

test('rejected mode change restores actual saved checkmark', function()
    local addon, state, frames = fixture()
    addon.OpenConfiguration()
    local controls = checks(frames)
    assert(#controls >= 12, 'checkbox controls missing')
    local first = #controls - 12
    state.reject = true
    controls[first + 2]:SetChecked(true)

    controls[first + 2].scripts.OnClick(controls[first + 2])

    assert(state.mode == 'context' and controls[first + 1].checked and not controls[first + 2].checked)
end)

test('combat locks every mode control in the shared editor', function()
    local addon, state, frames, settings = fixture()
    addon.OpenConfiguration()
    if settings.canvas then settings.canvas:Show() end
    state.locked = true

    addon.RefreshConfiguration()

    assert(#checks(frames) > 0, 'checkbox controls missing')
    for _, control in ipairs(checks(frames)) do assert(control.enabled == false) end
end)

test('activation checkbox reflects saved preference after toggling', function()
    local addon, state, frames = fixture()
    addon.OpenConfiguration()
    local controls = checks(frames)
    assert(#controls == 13, 'one shared panel expected')
    local active = controls[#controls]
    assert(active.checked)
    active:SetChecked(false)

    active.scripts.OnClick(active)

    assert(not state.active and not active.checked)
end)

test('temporary runtime pause keeps saved activation checked', function()
    local addon, state, frames = fixture()
    addon.OpenConfiguration()
    state.active = false

    addon.RefreshConfiguration()

    local controls = checks(frames)
    assert(controls[#controls].checked, 'temporary pause must not look like explicit off')
    local found = false
    for _, frame in ipairs(frames) do
        if rawget(frame, 'text') == 'enabled, temporarily inactive' then found = true end
    end
    assert(found, 'paused runtime must be visible in the status')
end)

print(passed .. ' passed, ' .. failed .. ' failed')
os.exit(failed == 0 and 0 or 1)
