-- ScreenEvaluationStage background: what both players share on the WANTED
-- results page, back to front as in the owner's artwork:
--
--   * the white ground, the shaded star pattern, the black curve, the red
--     top band, the black frame and "WANTED" (Graphics/VOLT26/Wanted/
--     backdrop.png);
--   * the song's background in the frame's spiky window under its red overlay.
--
-- The pictures and every shape come from tools/evaluation/build_eval_art.py.
-- Each player's side and the title are in the overlay
-- (ScreenEvaluationStage overlay/default.lua).
local Art = LoadActor(THEME:GetPathB("ScreenEvaluationStage", "overlay/Wanted/Art.lua"))
local picture = THEME:GetPathB("ScreenEvaluationStage", "overlay/Wanted/Picture.lua")
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
		LoadActor(picture, {
			name = "Window", shape = Art.window, cover = Art.window.points, rot = Art.song.rot,
			multiply = { 0.377, 0.421, 0.300 }, add = { 0.623, 0, 0 },
		}),
	},
}
