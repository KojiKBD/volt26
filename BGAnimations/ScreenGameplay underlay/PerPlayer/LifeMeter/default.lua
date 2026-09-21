local player = ...
if SL[ToEnumShortString(player)].ActiveModifiers.HideLifebar then return end

local lifemeter_actor

-- We have the choice a "Standard" LifeMeter (at the top of the screen)
-- a "Surround" LifeMeter, which occupies the space behind the arrows,
-- or a "Vertical" LifeMeter, which mimics the sizing and positioning used in ITG2.
local lifemeter_type = SL[ToEnumShortString(player)].ActiveModifiers.LifeMeterType or CustomOptionRow("LifeMeterType").Choices[1]
lifemeter_actor = LoadActor(lifemeter_type .. ".lua", player)

return lifemeter_actor