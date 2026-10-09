-- The menu theme, shared by the title and every screen up to song selection
-- (profile, style, play mode, profile load).  Each of those screens asks the
-- engine to play this same file, and the engine does not restart a file that
-- is already playing, so the theme carries on from the title.  The title starts
-- it as engine music (BGAnimations/ScreenTitleMenu underlay/Media.lua).
return THEME:GetPathG("", "VOLT26/menuost.ogg")
