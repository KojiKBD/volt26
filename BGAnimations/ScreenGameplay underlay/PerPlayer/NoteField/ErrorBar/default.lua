local player, layout = ...
local pn = ToEnumShortString(player)
local mods = VOLT26[pn].ActiveModifiers

if mods.ErrorBar == "None" then
    return
end

local a = LoadActor(mods.ErrorBar .. ".lua", player, layout)

return a
