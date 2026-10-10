-- One row of the song wheel, in the style of Simply Love's wheel: a full-width
-- bar with the title on top and a second line under it.  The engine MusicWheel
-- owns focus, sorting, input and the recycling of rows; this actor only
-- presents the item it is handed.  The highlight on the focused row is the
-- wheel's own (Graphics/MusicWheel highlight.lua).
--
-- Loaded by the MusicWheelItem NormalPart graphics with the kind of item the
-- part stands for: "Song", "Section" or "Course".  Rows are drawn from the
-- wheel origin (the left edge of the row) in the design units of
-- VOLT26.MusicSelection.Wheel; the wheel itself is scaled by the overlay.
local kind = ... or "Song"

local G = VOLT26.MusicSelection.Wheel
local width = G.Width
local height = G.ItemHeight
local textX = 28
local rightX = width - 24
local textWidth = width - textX - 150

local panel = color("#141417")
local section = color("#22161a")
local line = color("#2c2c33")
local ink = color("#f2f0ec")
local mute = color("#8a8a94")
local accent = color("#e03a2f")

local function sectionSongCount(name)
	if not name or name == "" then return 0 end
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(name) end)
	return ok and type(songs) == "table" and #songs or 0
end

local function isFavorite(song)
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local ok, favorite = pcall(function() return VOLT26.Favorites.HasSong(player, song) end)
		if ok and favorite then return true end
	end
	return false
end

-- MusicWheel can hand a section row an empty Label while Text carries the
-- section's name; an empty string is truthy in Lua, so both are checked.
local function sectionName(params)
	if params.Text and params.Text ~= "" then return params.Text end
	return params.Label or ""
end

local function setText(actor, text, px, display, maxWidth)
	local zoom = display and VOLT26.Type.DisplayZoom(px) or VOLT26.Type.LabelZoom(px)
	actor:settext(tostring(text or "")):zoom(zoom):maxwidth(maxWidth / zoom)
end

return Def.ActorFrame{
	InitCommand=function(self) self:visible(false) end,
	SetCommand=function(self, params)
		local isSong = params.Song ~= nil
		local isCourse = params.Course ~= nil
		local matches = (kind == "Song" and isSong)
			or (kind == "Course" and isCourse)
			or (kind == "Section" and not isSong and not isCourse)
		self:visible(matches and true or false)
		if not matches then return end

		local title, sub, right = "", "", ""
		local rightTint = mute
		if isSong then
			local song = params.Song
			title = song:GetDisplayMainTitle()
			local subtitle = song:GetDisplaySubTitle() or ""
			local artist = song:GetDisplayArtist() or ""
			sub = subtitle ~= "" and (subtitle .. "   /   " .. artist) or artist
			if isFavorite(song) then right, rightTint = "FAV", accent end
		elseif isCourse then
			local course = params.Course
			title = course:GetDisplayFullTitle()
			local ok, stages = pcall(function() return course:GetEstimatedNumStages() end)
			if ok and tonumber(stages) and stages > 0 then right = tostring(stages) end
		else
			title = sectionName(params)
			local songs = sectionSongCount(title)
			if songs > 0 then right = string.format("%d", songs) end
		end

		setText(self:GetChild("Title"), title, 30, true, textWidth)
		setText(self:GetChild("Sub"), sub:upper(), 12, false, textWidth)
		setText(self:GetChild("Right"), right, 14, false, 120)
		self:GetChild("Right"):diffuse(rightTint)

		local isSection = not isSong and not isCourse
		self:GetChild("Bg"):diffuse(isSection and section or panel):diffusealpha(0.92)
		self:GetChild("Stripe"):diffuse(isSection and accent or line)
		-- A section row has no second line, so its name sits on the centre.
		self:GetChild("Title"):y(isSection and 0 or -10)
	end,

	Def.Quad{
		Name="Bg",
		InitCommand=function(self)
			self:align(0, 0.5):zoomto(width, height):diffuse(panel):diffusealpha(0.92)
		end,
	},
	Def.Quad{
		Name="Stripe",
		InitCommand=function(self)
			self:align(0, 0.5):zoomto(6, height):diffuse(line)
		end,
	},
	Def.BitmapText{
		Name="Title", Font=VOLT26.Type.Display,
		InitCommand=function(self)
			self:xy(textX, -10):horizalign(left):vertalign(middle):shadowlength(0):diffuse(ink)
		end,
	},
	Def.BitmapText{
		Name="Sub", Font=VOLT26.Type.Label,
		InitCommand=function(self)
			self:xy(textX, 18):horizalign(left):vertalign(middle):shadowlength(0):diffuse(mute)
		end,
	},
	Def.BitmapText{
		Name="Right", Font=VOLT26.Type.Label,
		InitCommand=function(self)
			self:xy(rightX, 0):horizalign(right):vertalign(middle):shadowlength(0):diffuse(mute)
		end,
	},
}
