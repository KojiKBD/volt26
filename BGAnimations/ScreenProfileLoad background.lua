-- Plain black under the profile-load hold of the menu transition (see
-- ScreenProfileLoad overlay.lua).  It used to borrow the song select's
-- scenery, which showed dimmed behind the transition.
return Def.Quad{
	InitCommand=function(self) self:FullScreen():diffuse(Color.Black) end,
}
