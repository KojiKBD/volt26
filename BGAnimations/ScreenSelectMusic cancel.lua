-- Back from the song wheel returns to the pack step, which is drawn as part of
-- the same screen: the overlay plays the motion (default.lua, leaveToPacks)
-- and this transition only holds until it has finished, with nothing drawn
-- over it.  The course wheel has no pack step and keeps its fade.
if GAMESTATE:IsCourseMode() then
	return LoadActor(THEME:GetPathB("", "_fade out normal"))
end

local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
return Def.Actor{
	StartTransitioningCommand=function(self) self:sleep(K.HandoffHold) end,
}
