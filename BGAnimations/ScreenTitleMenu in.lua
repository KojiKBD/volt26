-- Intentionally empty: the title screen has no "in" transition.
--
-- The opening vow used to live here, which made the transition as long as the
-- cinematic. ScreenWithMenuElements::AllowCallbackInput() is !IsTransitioning(),
-- so for those seconds the engine dropped every input event before any Lua input
-- callback could see it. The vow now runs in "ScreenTitleMenu overlay.lua"; see
-- underlay/Prototype3D.lua for the second half of the story, the engine's own
-- input lock.
return Def.ActorFrame{}
