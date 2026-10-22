local _, root = ...
local addon = root.modules.Paladin
local tint = root.modules.Utilities.IconTint
addon.ButtonDesaturation = { Prepare = tint.Prepare, ClearOwner = tint.ClearOwner }

function addon.ButtonDesaturation.Set(button, owner, active)
    tint.Prepare(button)
    tint.SetOwner(button, owner, active == true)
end
