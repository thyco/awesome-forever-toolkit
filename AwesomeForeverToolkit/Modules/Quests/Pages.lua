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
        layout:Heading('Quest order')
        layout:Field('ChoiceDropdown', 'sortOrder', 'Sort quests', {
            {value = 'native', label = 'Blizzard order'},
            {value = 'ascending', label = 'Lowest level first'},
            {value = 'descending', label = 'Highest level first'},
        })
        layout:Field('Checkbox', 'groupZones', 'Group by zone (current zone first)')
        layout:Text('Each zone has its own heading. Sorting waits until combat ends. Headings hide during combat and use existing gaps.')
        layout:Text('Title changes wait until combat ends. Blizzard continues updating objective progress normally.')
        layout:Finish()
    end,
})
