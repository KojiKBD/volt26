-- The focused row of the song wheel, as the mockup draws it: larger than the
-- others, its upper band red, with red flags laid over both ends in a
-- difference blend.  The wheel hides its own copy of this row
-- (VOLT26.MusicSelection.PositionWheelItem), so the two never show at once.
--
-- The flags' blend is baked against the bands and the scenery behind them
-- (FocusFront, tools/song-select/build_song_select_art.py).  What changes
-- with the song is recoloured to match: the first letter of the artist line
-- turns cyan where the left flag crosses it, and the badge's later digits
-- show cyan where the right flag does.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local F = P.Art.Focus
local ax, ay = F.Anchor[1], F.Anchor[2]

local ARTIST = { X=15, Baseline=51, Cap=32.5, Width=330 }
local TITLE = { X=9, Baseline=110, Cap=41, Width=420 }
local TEXT_ROT = 1.2
local BPM_SIZE = 0.72
local BADGE = { Zoom = 0.56, Rot = 5 }
local LABEL_ZOOM = 1.08

local function customLabel()
	local ok, text = pcall(function() return THEME:GetString("MusicWheel", "CustomItemBackToPacksText") end)
	return ok and text or ""
end

local function isCustom()
	if S.Item() then return false end
	local wheel = K.Wheel()
	return wheel ~= nil and wheel:GetSelectedType() == "WheelItemDataType_Custom"
end

-- The words on the row: artist line, title and the top meter.
local function rowContent()
	local item = S.Item()
	if item then
		if S.IsCourseMode() then
			local ok, stages = pcall(function() return item:GetEstimatedNumStages() end)
			local count = ok and tonumber(stages) or 0
			return count > 0 and ("%d STAGES"):format(count) or "", "", item:GetDisplayFullTitle(), nil
		end
		local artist, bpm = P.ArtistParts(item)
		return artist, bpm, VOLT26.SongBrowsing.WheelTitle(item), P.TopMeter(item)
	end
	local wheel = K.Wheel()
	local selected = wheel and wheel:GetSelectedType() or nil
	if selected == "WheelItemDataType_Custom" then return "", "", customLabel(), nil end
	local ok, section = pcall(function() return wheel:GetSelectedSection() end)
	section = ok and section or ""
	-- A pack row (the Simply Love layout lists them all) counts its songs,
	-- as the wheel's own rows do (Graphics/VOLT26/SongWheel/Row.lua).
	local okSongs, songs = pcall(function() return SONGMAN:GetSongsInGroup(section) end)
	local count = section ~= "" and okSongs and type(songs) == "table" and #songs or 0
	if count > 0 then return ("%d SONGS"):format(count), "", section, nil end
	-- A series of packs (a parent section).
	if VOLT26.PackSelection.IsSeries(section) then return "COLLECTION", "", section, nil end
	return "", "", section, nil
end

return Def.ActorFrame{
	Name="Focus",
	InitCommand=function(self) self:xy(ax, ay) end,
	RefreshCommand=function(self)
		local artist, bpm, title, meter = rowContent()
		-- PACK SELECTION fills both bands in cutout lettering.
		local custom = isCustom()
		-- A long title shrinks, then scrolls; a long artist scrolls while
		-- the BPM beside it stays whole.
		local artistFrame = self:GetChild("Artist")
		artistFrame:visible(not custom)
		self:GetChild("Bpm"):visible(not custom)
		P.SetArtistLine(ARTIST.X, self:GetChild("Bpm"), artist, bpm, ARTIST.Width,
			function(text, room) return P.SetMarquee(artistFrame, text, room) end)
		local artistText = P.MarqueeText(artistFrame)
		artistText:ClearAttributes()
		if artist ~= "" then artistText:AddAttribute(0, { Length=1, Diffuse=P.Cyan }) end
		self:GetChild("Title"):visible(not custom)
		P.SetMarquee(self:GetChild("Title"), title)
		local label = self:GetChild("LabelFrame")
		label:visible(custom)
		if custom then P.SetCutout(label:GetChild("Label"), title) end
		self:GetChild("FocusRank"):visible(meter ~= nil)
		P.SetBadge(self:GetChild("Badge"), meter, P.Ink.Plain, P.Ink.P1Box)
		if title ~= self.shown then
			self.shown = title
			-- Every new song slams the row in from the left, the flags snap
			-- after it and the badge punches up.
			self:stoptweening():x(ax - 46):zoom(1.05)
				:decelerate(0.1):x(ax + 6):zoom(1):decelerate(0.06):x(ax)
			-- Absolute positions: the wheel can change songs faster than this
			-- plays, and relative moves (addx) cut short by stoptweening would
			-- leave the flags a little further left every time.
			local frontX = P.Art.Pieces.FocusFront.X - ax
			self:GetChild("FocusFront"):stoptweening():x(frontX - 34):diffusealpha(0.4)
				:sleep(0.04):decelerate(0.1):x(frontX):diffusealpha(1)
			local badge = self:GetChild("Badge")
			badge:stoptweening():zoom(BADGE.Zoom * 1.45):rotationz(BADGE.Rot + 18)
				:decelerate(0.16):zoom(BADGE.Zoom):rotationz(BADGE.Rot)
		end
	end,
	-- Arriving: the row sweeps in from the left after the black panel.
	OnCommand=function(self)
		self:stoptweening():x(ax - 760):zoom(1):sleep(0.06):decelerate(0.17):x(ax + 24):decelerate(0.06):x(ax)
	end,
	-- The song is chosen: the row swells and its flags flash.
	SongChosenMessageCommand=function(self)
		self:finishtweening():decelerate(0.1):zoom(1.08):accelerate(0.16):zoom(1.02)
		self:GetChild("FocusFront"):glowblink():effectperiod(0.1):effectcolor1(color("1,1,1,0.9")):effectcolor2(color("1,1,1,0"))
	end,

	P.Piece("FocusBands", ax, ay),
	P.Piece("FocusRank", ax, ay),
	P.Marquee{ Name="Title", Cap=TITLE.Cap, X=TITLE.X, Baseline=TITLE.Baseline,
		Width=TITLE.Width, MinScale=0.8, Rot=TEXT_ROT, Tint=P.Black },
	P.Piece("FocusFront", ax, ay),
	P.Badge{ Name="Badge", X=F.Badge.X, Y=F.Badge.Y, Zoom=BADGE.Zoom, Rot=BADGE.Rot },
	P.Marquee{ Name="Artist", Cap=ARTIST.Cap, X=ARTIST.X, Baseline=ARTIST.Baseline,
		Width=ARTIST.Width, MinScale=0.85, Rot=TEXT_ROT, Tint=P.White },
	-- The BPM, a size smaller than the artist, on the same baseline.
	P.Text{ Name="Bpm", Cap=ARTIST.Cap * BPM_SIZE, X=ARTIST.X, Baseline=ARTIST.Baseline,
		Rot=TEXT_ROT, Tint=P.White },
	-- The focused row is the plain row drawn larger.
	Def.ActorFrame{
		Name="LabelFrame",
		InitCommand=function(self) self:zoom(LABEL_ZOOM):visible(false) end,
		P.CutoutSlot{ Name="Label", Id="BackLabel", X=18, Y=58, Scale=K.Scale },
	},
}
