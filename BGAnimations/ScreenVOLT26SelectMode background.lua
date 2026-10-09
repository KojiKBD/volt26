-- ScreenVOLT26SelectMode: the red field and black jagged panel with the
-- "SELECT YOUR MODE" title, exported from the owner's Illustrator artboard
-- (charter_card.ai, "MODES").  The rows and the OK button are the overlay.
return Def.Sprite{
	Texture=THEME:GetPathG("", "VOLT26/ModeSelect/bg.png"),
	InitCommand=function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
}
