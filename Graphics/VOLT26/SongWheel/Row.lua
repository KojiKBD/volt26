-- One row of the song wheel, drawn after the owner's mockup: a black band with
-- "ARTIST - BPM" and RANK over a white band with the song's name, and the
-- highest meter of the song as a badge at the end.  The engine MusicWheel owns
-- focus, sorting, input and the recycling of rows; this actor only presents
-- the item it is handed.  The row the wheel is focused on is hidden
-- (VOLT26.MusicSelection.PositionWheelItem) and drawn larger by the overlay
-- (BGAnimations/ScreenSelectMusic overlay/SongWheel/Focus.lua).
--
-- Loaded by the MusicWheelItem NormalPart graphics with the kind of item the
-- part stands for: "Song", "Section", "Course" or "Custom" (the song wheel's
-- PACK SELECTION row; see [VOLT26SongWheel] in metrics.ini).  The
-- origin is the row's anchor, the top-left corner of its black band, in the
-- design units of the 1920x1080 mockup; the wheel itself is scaled by the
-- overlay.
local kind = ... or "Song"

local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local R = P.Art.Row

-- Text placement measured on the mockup (baselines, relative to the anchor).
local ARTIST = { X=14, Baseline=48, Cap=30, Width=300 }
local TITLE = { X=8, Baseline=102, Cap=38, Width=385 }
local TEXT_ROT = 1.2
local BPM_SIZE = 0.72
-- PACK SELECTION: left edge and vertical centre over both bands.
local LABEL = { X=18, Y=58 }
local BADGE_ZOOM = 0.52
local BADGE_ROT = 5

local function sectionSongCount(name)
	if not name or name == "" then return 0 end
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(name) end)
	return ok and type(songs) == "table" and #songs or 0
end

-- MusicWheel can hand a section row an empty Label while Text carries the
-- section's name; an empty string is truthy in Lua, so both are checked.
local function sectionName(params)
	if params.Text and params.Text ~= "" then return params.Text end
	return params.Label or ""
end

return Def.ActorFrame{
	InitCommand=function(self) self:visible(false) end,
	SetCommand=function(self, params)
		local isSong = params.Song ~= nil
		local isCourse = params.Course ~= nil
		local isCustom = params.Type == "Custom"
		local matches = (kind == "Song" and isSong)
			or (kind == "Course" and isCourse)
			or (kind == "Custom" and isCustom)
			or (kind == "Section" and not isSong and not isCourse and not isCustom)
		self:visible(matches and true or false)
		if not matches then return end

		local artist, bpm, title, meter = "", "", "", nil
		if isSong then
			artist, bpm = P.ArtistParts(params.Song)
			title = params.Song:GetDisplayMainTitle()
			meter = P.TopMeter(params.Song)
		elseif isCourse then
			local course = params.Course
			title = course:GetDisplayFullTitle()
			local ok, stages = pcall(function() return course:GetEstimatedNumStages() end)
			if ok and tonumber(stages) and stages > 0 then artist = ("%d STAGES"):format(stages) end
		elseif isCustom then
			title = params.Label or ""
		else
			title = sectionName(params)
			local songs = sectionSongCount(title)
			if songs > 0 then artist = ("%d SONGS"):format(songs) end
		end

		-- PACK SELECTION fills both bands in cutout lettering.
		-- A long title shrinks, then narrows; a long artist is shortened with
		-- an ellipsis so the BPM beside it always shows whole.
		self:GetChild("Artist"):visible(not isCustom)
		self:GetChild("Bpm"):visible(not isCustom)
		P.SetArtistLineShrink(ARTIST.X, self:GetChild("Artist"), self:GetChild("Bpm"),
			artist, bpm, ARTIST.Width, 0.78)
		self:GetChild("Title"):visible(not isCustom)
		P.FitText(self:GetChild("Title"), title, TITLE.Width, 0.72, true)
		local label = self:GetChild("Label")
		label:visible(isCustom)
		if isCustom then P.SetCutout(label, title) end
		self:GetChild("Rank"):visible(meter ~= nil)
		P.SetBadge(self:GetChild("Badge"), meter)
	end,

	-- The pieces were cut from the row just above the focused one.
	P.Piece("RowBands", R.Anchors[-1][1], R.Anchors[-1][2]),
	P.Piece("Rank", R.Anchors[-1][1], R.Anchors[-1][2]),
	P.Text{ Name="Artist", Cap=ARTIST.Cap, X=ARTIST.X, Baseline=ARTIST.Baseline,
		Rot=TEXT_ROT, Tint=P.White },
	-- The BPM, a size smaller than the artist, on the same baseline.
	P.Text{ Name="Bpm", Cap=ARTIST.Cap * BPM_SIZE, X=ARTIST.X, Baseline=ARTIST.Baseline,
		Rot=TEXT_ROT, Tint=P.White },
	P.Text{ Name="Title", Cap=TITLE.Cap, X=TITLE.X, Baseline=TITLE.Baseline,
		Rot=TEXT_ROT, Tint=P.Black },
	P.Badge{ Name="Badge", X=R.Badge.X, Y=R.Badge.Y, Zoom=BADGE_ZOOM, Rot=BADGE_ROT },
	P.CutoutSlot{ Name="Label", Id="BackLabel", X=LABEL.X, Y=LABEL.Y, Scale=P.Scale },
}
