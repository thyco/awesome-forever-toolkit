local _, root = ...
local Blessings = {}
root.modules.Paladin.Blessings = Blessings

-- Kings from another Paladin counts, even if the player has not learned it.
-- Freedom temporarily suppresses the missing-Kings reminder. Other blessings
-- do not satisfy this reminder's condition.
Blessings.groups = {
    {key = 'kings', spellIDs = {20217}},
    {key = 'greater-kings', spellIDs = {25898}},
    {key = 'freedom', spellIDs = {1044}},
}
