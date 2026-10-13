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

-- Motion: the backdrop is already there, dimmed, under the victory / defeat
-- transition, a little larger than it will be; when the page comes in
-- (VOLT26EvaluationWantedIntro, from the overlay) it settles to its size and
-- the song's picture fades into the window.  Leaving, it pushes in again
-- under the out transition.
local SETTLE = 1.08

return Def.ActorFrame{
	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(color("#000000")) end,
	},
	-- Zoomed about the screen's centre: the outer frame is the pivot.
	Def.ActorFrame{
		Name="WantedBackdrop",
		InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoom(S * SETTLE) end,
		VOLT26EvaluationWantedIntroMessageCommand=function(self)
			self:finishtweening():zoom(S * SETTLE):decelerate(0.5):zoom(S)
		end,
		OffCommand=function(self)
			self:finishtweening():accelerate(0.5):zoom(S * 1.05)
		end,
		Def.ActorFrame{
			InitCommand=function(self) self:xy(-960, -540) end,
			Def.Sprite{
				Texture=THEME:GetPathG("", "VOLT26/Wanted/backdrop.png"),
				InitCommand=function(self) self:align(0, 0):xy(0, 0) end,
			},
			Def.ActorFrame{
				InitCommand=function(self) self:diffusealpha(0) end,
				VOLT26EvaluationWantedIntroMessageCommand=function(self)
					self:finishtweening():diffusealpha(0):sleep(0.15):linear(0.35):diffusealpha(1)
				end,
				LoadActor(picture, {
					name = "Window", shape = Art.window, cover = Art.window.points, rot = Art.song.rot,
					multiply = { 0.377, 0.421, 0.300 }, add = { 0.623, 0, 0 },
				}),
			},
		},
	},
}
