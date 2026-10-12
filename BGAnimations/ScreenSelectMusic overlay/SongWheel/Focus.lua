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

local function customLabel()
	local ok, text = pcall(function() return THEME:GetString("MusicWheel", "CustomItemBackToPacksText") end)
	return ok and text or ""
end

-- The words on the row: artist line, title and the top meter.
local function rowContent()
	local item = S.Item()
	if item then
		if S.IsCourseMode() then
			local ok, stages = pcall(function() return item:GetEstimatedNumStages() end)
			local count = ok and tonumber(stages) or 0
			return count > 0 and ("%d STAGES"):format(count) or "", item:GetDisplayFullTitle(), nil
		end
		return P.ArtistLine(item), item:GetDisplayMainTitle(), P.TopMeter(item)
	end
	local wheel = K.Wheel()
	local selected = wheel and wheel:GetSelectedType() or nil
	if selected == "WheelItemDataType_Custom" then return "", customLabel(), nil end
	local ok, section = pcall(function() return wheel:GetSelectedSection() end)
	return "", ok and section or "", nil
end

return Def.ActorFrame{
	Name="Focus",
	InitCommand=function(self) self:xy(ax, ay) end,
	RefreshCommand=function(self)
		local artist, title, meter = rowContent()
		local artistText = self:GetChild("Artist")
		artistText:ClearAttributes()
		artistText:settext(artist)
		if artist ~= "" then artistText:AddAttribute(0, { Length=1, Diffuse=P.Cyan }) end
		self:GetChild("Title"):settext(title)
		self:GetChild("FocusRank"):visible(meter ~= nil)
		P.SetBadge(self:GetChild("Badge"), meter, P.Ink.Plain, P.Ink.P1Box)
		if title ~= self.shown then
			self.shown = title
			-- A small kick on every new song; the full choreography comes later.
			self:stoptweening():zoom(1.04):decelerate(0.1):zoom(1)
		end
	end,

	P.Piece("FocusBands", ax, ay),
	P.Piece("FocusRank", ax, ay),
	P.Text{ Name="Title", Cap=TITLE.Cap, X=TITLE.X, Baseline=TITLE.Baseline,
		Width=TITLE.Width, Rot=TEXT_ROT, Tint=P.Black },
	P.Piece("FocusFront", ax, ay),
	P.Badge{ Name="Badge", X=F.Badge.X, Y=F.Badge.Y, Zoom=0.56, Rot=5 },
	P.Text{ Name="Artist", Cap=ARTIST.Cap, X=ARTIST.X, Baseline=ARTIST.Baseline,
		Width=ARTIST.Width, Rot=TEXT_ROT, Tint=P.White },
}
