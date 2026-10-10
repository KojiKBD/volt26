-- Opening a pack hands over to the song wheel, which is drawn as part of the
-- same screen: the overlay shrinks the jacket into the song wheel's header
-- badge (default.lua, leaveToSongWheel) and this transition only holds until
-- that motion has finished, with nothing drawn over it.
local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
return Def.Actor{
	StartTransitioningCommand=function(self) self:sleep(K.HandoffHold) end,
}
