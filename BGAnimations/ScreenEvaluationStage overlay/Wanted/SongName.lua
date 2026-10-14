-- The song name plate on the WANTED page: the owner's songname.svg
-- (Graphics/VOLT26/Wanted/songname.png, rendered from the SVG at 1:1) under
-- the "WANTED" lettering, with the song's name over it in Helvetica Bold.
-- One plate for the screen, the same with one or two players: both played the
-- same song.  It is drawn over the players' sides.
--
-- Everything is in artboard pixels (1920x1080), like the rest of the page.
-- PLATE is the plate's centre and size, measured on the owner's Illustrator
-- screenshot of 2026-10-14; TEXT is the name's centre, slope and size inside
-- the plate's white face, relative to the plate's top-left corner (the SVG's
-- own coordinates).
local args = ...
local T = args.Text

local PLATE = { cx = 1013, cy = 156, w = 529, h = 80 }
local TEXT = {
	cx = 258, cy = 42,  -- middle of the white face
	rot = -2,           -- the face's top and bottom edges fall about 2 degrees
	cap = 30,           -- capital height
	width = 440,        -- longest name before it is squeezed
}
-- Helvetica Bold draws a 26 px capital at zoom 1 (Fonts/Helvetica Bold.ini:
-- Baseline 45 - Top 19).
local FONT_CAP = 26

local function name()
	local course = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or nil
	local song = GAMESTATE:GetCurrentSong()
	return course and course:GetDisplayFullTitle() or song and song:GetDisplayMainTitle() or ""
end

local text = name()
local covered = T.Covered(text)

return Def.ActorFrame{
	Name="SongName",
	InitCommand=function(self)
		self:xy(PLATE.cx, PLATE.cy - 60):diffusealpha(0)
	end,
	VOLT26EvaluationWantedIntroMessageCommand=function(self)
		self:finishtweening():y(PLATE.cy - 60):diffusealpha(0)
			:sleep(0.3):decelerate(0.25):y(PLATE.cy):diffusealpha(1)
	end,
	OffCommand=function(self)
		self:stoptweening():accelerate(0.2):y(PLATE.cy - 60):diffusealpha(0)
	end,

	Def.Sprite{
		Name="Plate",
		Texture=THEME:GetPathG("", "VOLT26/Wanted/songname.png"),
		InitCommand=function(self) self:zoomto(PLATE.w, PLATE.h) end,
	},
	LoadFont(covered and "Helvetica Bold" or T.Font.Fallback)..{
		Name="Text",
		InitCommand=function(self)
			self:xy(TEXT.cx - PLATE.w / 2, TEXT.cy - PLATE.h / 2):rotationz(TEXT.rot)
				:diffuse(color("#000000")):settext(text)
			-- The fallback font's capitals are not known: fit its line instead.
			local zoom = covered and TEXT.cap / FONT_CAP or TEXT.cap * 1.45 / math.max(1, self:GetHeight())
			self:zoom(zoom)
			local w = self:GetWidth() * zoom
			if w > TEXT.width then self:zoomx(zoom * TEXT.width / w) end
		end,
	},
}
