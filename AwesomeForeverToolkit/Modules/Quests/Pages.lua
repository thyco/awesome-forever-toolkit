local _, root = ...
local addon = root.modules.Quests
root.Window:RegisterPage({
    id = 'quests', label = 'Quest tracker', available = function() return addon.active == true end,
    build = function(parent, context)
        local layout = root.Widgets.Layout(parent, context, 'quests', addon.Config)
        layout:Heading('Blizzard quest tracker')
        layout:Text('Enhances the existing Blizzard quest tracker. Experimental: disable QuestTagsForever and reload before testing.')
        layout:Field('Checkbox', 'enabled', 'Enable quest tracker enhancements')
        layout:Field('Checkbox', 'showTags', 'Show quest levels and E / D / R type tags')
        layout:Field('Checkbox', 'showCount', 'Show quest log count')
        layout:Text('Title changes wait until combat ends. Blizzard continues updating objective progress normally.')
        layout:Finish()
    end,
})
