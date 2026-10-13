-- Leaving the stage evaluation: the WANTED page's parts go back out (their
-- OffCommands, in the overlay and background) and the screen then fades to
-- black.  Long enough for the parts to clear before the fade covers them.
return Def.Quad{
	InitCommand=function(self) self:FullScreen():diffuse(0, 0, 0, 0) end,
	StartTransitioningCommand=function(self) self:sleep(0.28):linear(0.3):diffusealpha(1) end,
}
