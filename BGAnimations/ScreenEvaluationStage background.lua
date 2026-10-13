-- ScreenEvaluationStage background: what both players share on the WANTED
-- results page -- the artwork's ground, star pattern, curves, black frame and
-- "WANTED" (Graphics/VOLT26/Wanted/backdrop.png, rendered from the owner's
-- Illustrator page by tools/evaluation/build_eval_art.py) and the song's
-- background in the frame's window.  Each player's side and the title are in
-- the overlay (ScreenEvaluationStage overlay/default.lua).
local Art = LoadActor(THEME:GetPathB("ScreenEvaluationStage", "overlay/Wanted/Art.lua"))
local S = SCREEN_HEIGHT / 1080
local OX = (SCREEN_WIDTH - 1920 * S) / 2

return Def.ActorFrame{
	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(color("#000000")) end,
	},
	Def.ActorFrame{
		Name="WantedBackdrop",
		InitCommand=function(self) self:xy(OX, 0):zoom(S) end,
		Def.Sprite{
			Texture=THEME:GetPathG("", "VOLT26/Wanted/backdrop.png"),
			InitCommand=function(self) self:align(0, 0):xy(0, 0) end,
		},
		LoadActor(THEME:GetPathB("ScreenEvaluationStage", "overlay/Wanted/Window.lua"), Art),
	},
}
