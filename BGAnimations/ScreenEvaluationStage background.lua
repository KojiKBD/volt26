-- ScreenEvaluationStage background: what both players share on the WANTED
-- results page, back to front as in the owner's artwork:
--
--   * the white ground, the shaded star pattern and the black curve
--     (Graphics/VOLT26/Wanted/backdrop.png);
--   * the top band: the song's background under the artwork's dark red;
--   * the black frame;
--   * "WANTED" (Graphics/VOLT26/Wanted/wanted.png);
--   * the song's background in the frame's spiky window under its red overlay.
--
-- The pictures and every shape come from tools/evaluation/build_eval_art.py.
-- Each player's side and the title are in the overlay
-- (ScreenEvaluationStage overlay/default.lua).
local Art = LoadActor(THEME:GetPathB("ScreenEvaluationStage", "overlay/Wanted/Art.lua"))
local picture = THEME:GetPathB("ScreenEvaluationStage", "overlay/Wanted/Picture.lua")
local S = SCREEN_HEIGHT / 1080
local OX = (SCREEN_WIDTH - 1920 * S) / 2

-- The band's picture covers the box the artwork places it in.
local box = Art.band.picture
local bandCover = {
	{ box.x, box.y }, { box.x + box.w, box.y }, { box.x + box.w, box.y + box.h }, { box.x, box.y + box.h },
}

local function frameVertices()
	local vertices, black = {}, { 0, 0, 0, 1 }
	for _, tri in ipairs(Art.frame.triangles) do
		for _, index in ipairs(tri) do
			local pt = Art.frame.points[index]
			vertices[#vertices+1] = { { pt[1], pt[2], 0 }, black }
		end
	end
	return vertices
end

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
			name = "Band", shape = Art.band, cover = bandCover, rot = 0,
			multiply = { Art.band.multiply, Art.band.multiply, Art.band.multiply }, add = Art.band.add,
		}),
		Def.ActorMultiVertex{
			Name="Frame",
			InitCommand=function(self)
				self:SetDrawState{ Mode="DrawMode_Triangles" }:SetVertices(frameVertices())
			end,
		},
		Def.Sprite{
			Name="Wanted",
			Texture=THEME:GetPathG("", "VOLT26/Wanted/wanted.png"),
			InitCommand=function(self) self:align(0, 0):xy(Art.wanted.x, Art.wanted.y) end,
		},
		LoadActor(picture, {
			name = "Window", shape = Art.window, cover = Art.window.points, rot = Art.song.rot,
			multiply = { 0.377, 0.421, 0.300 }, add = { 0.623, 0, 0 },
		}),
	},
}
