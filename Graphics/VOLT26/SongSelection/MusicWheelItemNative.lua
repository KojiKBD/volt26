-- Engine-native vertical Song Select row.  MusicWheel keeps ownership of focus,
-- sorting, input, and actor recycling; this actor only presents it.
--
-- Every row carries its own slice of the vertical rail, one pitch tall and
-- drawn behind the dot, so the rail reads as one continuous guide without a
-- second actor having to track the list.
local kind = ... or "Song"

local G = VOLT26.MusicSelection.Wheel
local itemLeft = G.ItemOffset - G.GuideOffset
local itemWidth = G.Width - G.ItemOffset
local itemHeight = G.ItemHeight
local jacketX = itemLeft + 15
local jacketSize = 48
local textX = jacketX + jacketSize + 16
local meterX = itemLeft + itemWidth - 16
local textWidth = meterX - 24 - textX

local ink = color("#f2f0ec")
local mute = color("#8a8a94")
local dim = color("#5a5a64")
local line = color("#26262c")
local panel2 = color("#17171b")
local rail = color("#3a2020")
local accent = color("#e03a2f")

local function circleVertices(radius, tint)
	local vertices = {{{0,0,0}, tint}}
	for i=0,16 do
		local angle = i/16*math.pi*2
		vertices[#vertices+1] = {{math.cos(angle)*radius,math.sin(angle)*radius,0}, tint}
	end
	return vertices
end

local function selectedType()
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	return wheel and wheel:GetSelectedType(), wheel
end

-- MusicWheel wraps short lists, so one pack or song can hold several rows at
-- once.  GAMESTATE cannot tell those copies apart, and every copy claiming
-- focus would light up the highlight in several places.  The wheel's transform
-- function stamps each row with its distance from the centre, which is the only
-- per-row identity the engine hands out.
local function isCenterRow(self)
	local node = self:GetParent()
	while node do
		local offset = node.VOLT26Offset
		-- Mid-scroll two rows sit within one step of the centre; the GAMESTATE
		-- check below picks the right one, and duplicates are always further.
		if offset then return math.abs(offset) < 1 end
		node = node.GetParent and node:GetParent() or nil
	end
	return true
end

local function focused(self)
	if not isCenterRow(self) then return false end
	local selected, wheel = selectedType()
	if self.song then return selected == "WheelItemDataType_Song" and GAMESTATE:GetCurrentSong() == self.song end
	if self.course then return selected == "WheelItemDataType_Course" and GAMESTATE:GetCurrentCourse() == self.course end
	if self.section then
		return (selected == "WheelItemDataType_Section" or selected == "WheelItemDataType_ParentSection")
			and wheel and wheel:GetSelectedSection() == self.section
	end
	return false
end

local function label(params)
	if params.Song then return params.Song:GetDisplayMainTitle() end
	if params.Course then return params.Course:GetDisplayFullTitle() end
	-- MusicWheel section rows can provide Label as an empty string while Text
	-- carries the actual group name.  Empty strings are truthy in Lua, so a
	-- simple `Label or Text` silently erased the pack title.
	if params.Label and params.Label ~= "" then return params.Label end
	return params.Text or ""
end

-- A video banner is decoded in full when it is loaded, on a worker thread that
-- competes with the frame loop for as long as the decode takes.  Nothing that
-- expensive belongs behind a 48px thumbnail.
local movieExtensions = {
	avi=true, f4v=true, flv=true, mkv=true, mp4=true, mpeg=true,
	mpg=true, mov=true, ogv=true, webm=true, wmv=true,
}

local function isMovie(path)
	return movieExtensions[(path:match("%.([^.]+)$") or ""):lower()] == true
end

-- Answers the artwork path together with the image-cache directory it is
-- cached under, so the row can load the low-resolution copy instead of the
-- source file.  The song background is deliberately not a fallback: it is the
-- largest image in the folder, it is not cached, and the wheel would upload it
-- in full for every row that scrolls into view.
-- A still always wins: it costs one cached upload and can be shown on every row
-- at once.  A movie is answered only when it is the only artwork the song has,
-- and the caller decodes it for the focused row alone -- one decoder instead of
-- one per visible row, which is what made video artwork unaffordable here.
local function artwork(song)
	if not song then return nil end
	local movie, movieDir
	if song:HasJacket() then
		local path = song:GetJacketPath()
		if path and path ~= "" then
			if not isMovie(path) then return path, "Jacket", false end
			movie, movieDir = path, "Jacket"
		end
	end
	if song:HasBanner() then
		local path = song:GetBannerPath()
		if path and path ~= "" then
			if not isMovie(path) then return path, "Banner", false end
			if not movie then movie, movieDir = path, "Banner" end
		end
	end
	if movie then return movie, movieDir, true end
	return nil
end

local function sectionSongCount(section)
	if not section or section == "" then return 0 end
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(section) end)
	return ok and songs and #songs or 0
end

local function centerCrop(sprite, x, y, width, height)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):zoom(1)
		:align(0.5,0.5):xy(x+width/2, y+height/2)
	local sourceWidth = math.max(1, sprite:GetWidth())
	local sourceHeight = math.max(1, sprite:GetHeight())
	local sourceAspect = sourceWidth/sourceHeight
	local targetAspect = width/height
	if sourceAspect > targetAspect then
		local crop = (1-targetAspect/sourceAspect)/2
		sprite:cropleft(crop):cropright(crop):zoom(height/sourceHeight)
	else
		local crop = (1-sourceAspect/targetAspect)/2
		sprite:croptop(crop):cropbottom(crop):zoom(width/sourceWidth)
	end
end

local function meterText(song)
	if not song then return "" end
	local style = GAMESTATE:GetCurrentStyle()
	local stepsType = style and style:GetStepsType() or nil
	if not stepsType then return "" end
	local ok, charts = pcall(function() return song:GetStepsByStepsType(stepsType) end)
	if not ok or not charts or #charts == 0 then return "" end
	local hardest = 0
	for chart in ivalues(charts) do hardest = math.max(hardest, tonumber(chart:GetMeter()) or 0) end
	return hardest > 0 and tostring(hardest) or ""
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
		self.focusPollElapsed = 0
		self:SetUpdateFunction(function(frame, delta)
			if not frame:GetVisible() then return end
			delta = delta or 0

			-- Video artwork waits for the row to settle before its decoder is
			-- opened, so holding a direction scrolls through a pack without
			-- starting one for every row it crosses.
			if frame.movieDelay then
				frame.movieDelay = frame.movieDelay - delta
				if frame.movieDelay <= 0 then
					frame.movieDelay = nil
					frame:playcommand("StartMovieArt")
				end
			end

			-- A movie has no size until its first frame is decoded, so the crop
			-- is retried until it does and then given up on.
			if frame.movieFit then
				frame.movieFit = frame.movieFit - delta
				local art = frame:GetChild("SongRow"):GetChild("Jacket")
				if art:GetWidth() > 1 and art:GetHeight() > 1 then
					centerCrop(art, jacketX, -jacketSize/2, jacketSize, jacketSize)
					frame.movieFit = nil
				elseif frame.movieFit <= 0 then
					frame.movieFit = nil
				end
			end

			frame.focusPollElapsed = frame.focusPollElapsed + delta
			local interval = VOLT26.Performance.IsEnabled() and (1/30) or 0
			if frame.focusPollElapsed < interval then return end
			frame.focusPollElapsed = 0
			local isFocus = focused(frame)
			if isFocus ~= frame.wasFocus then
				frame.wasFocus = isFocus
				frame:playcommand("Focus", {Focused=isFocus})
			end
		end)
	end,
	SetCommand=function(self, params)
		local matches = (kind == "Song" and params.Song)
			or (kind == "Course" and params.Course)
			or (kind == "Section" and not params.Song and not params.Course)
		self:visible(matches and true or false)
		if not matches then return end

		self.song, self.course = params.Song, params.Course
		self.movieDelay, self.movieFit = nil, nil
		self.section = (not params.Song and not params.Course) and (params.Text or params.Label) or nil
		if self.section == "" then self.section = params.Label end

		local isSong = self.song ~= nil or self.course ~= nil
		self:GetChild("SongRow"):visible(isSong)
		self:GetChild("PackRow"):visible(not isSong)

		if isSong then
			local row = self:GetChild("SongRow")
			self.artPath, self.artCacheDir, self.artIsMovie = artwork(self.song)
			VOLT26.Type.SetLabel(row:GetChild("Artist"),
				(self.song and self.song:GetDisplayArtist() or ""):upper(), 13, textWidth)
			VOLT26.Type.SetDisplay(row:GetChild("Title"), label(params), 26, textWidth)
			VOLT26.Type.SetLabel(row:GetChild("Meter"), meterText(self.song), 17)
		else
			local row = self:GetChild("PackRow")
			local title = self.section or ""
			VOLT26.Type.SetLabel(row:GetChild("Name"), title:upper(), 26, itemWidth - 110)
			VOLT26.Type.SetLabel(row:GetChild("Count"),
				string.format("%02d", sectionSongCount(self.section)), 14)
		end

		self.wasFocus = focused(self)
		self:playcommand("Focus", {Focused=self.wasFocus})
	end,
	FocusCommand=function(self, params)
		local on = params.Focused
		local tint = on and accent or rail

		-- The current row's dot grows into the accent while the rest stay small
		-- and unlit, so the eye finds the selection before reading a word.
		self:GetChild("Dot")
			:SetNumVertices(18):SetVertices(circleVertices(on and 6 or 4, tint))

		local highlight = self:GetChild("Highlight")
		local bar = self:GetChild("Bar")
		highlight:visible(on)
		bar:visible(on)

		if self.song or self.course then
			local row = self:GetChild("SongRow")
			row:GetChild("Artist"):diffuse(on and accent or dim)
			row:GetChild("Title"):diffuse(ink)
			row:GetChild("Meter"):diffuse(on and accent or mute)

			local art = row:GetChild("Jacket")
			local fallback = row:GetChild("JacketFallback")
			local loaded = false
			if self.artPath and not self.artIsMovie then
				self.movieDelay, self.movieFit = nil, nil
				loaded = pcall(function()
					if self.loadedArtPath ~= self.artPath then
						-- The cached copy is a small 16-bit texture; the source
						-- file is a multi-megabyte RGBA8 upload that the wheel
						-- would repeat for every row scrolling into view.
						art:LoadFromCached(self.artCacheDir, self.artPath)
						-- A still frame: recycled rows sharing one multi-frame
						-- texture advance it once per actor and visibly
						-- accelerate playback.
						art:animate(false)
						self.loadedArtPath = self.artPath
					end
				end)
				if not loaded then self.loadedArtPath = nil end
			elseif self.artPath and self.artIsMovie then
				-- The only artwork this song has is a movie, so it plays on the
				-- focused row and nowhere else.  Every other row keeps the plain
				-- block it had back when movies were skipped outright.
				if on then
					if self.loadedArtPath == self.artPath then
						loaded = true
					else
						self.movieDelay = self.movieDelay or 0.30
					end
				else
					self.movieDelay, self.movieFit = nil, nil
					if self.loadedArtPath then
						pcall(function()
							if art.SetDecodeMovie then art:SetDecodeMovie(false) end
							art:animate(false)
						end)
						self.loadedArtPath = nil
					end
				end
			end
			art:visible(loaded)
			fallback:visible(not loaded)
			if loaded then centerCrop(art, jacketX, -jacketSize/2, jacketSize, jacketSize) end
		else
			local row = self:GetChild("PackRow")
			row:GetChild("Name"):diffuse(on and accent or ink)
			row:GetChild("Count"):diffuse(on and accent or dim)
		end
	end,
	StartMovieArtCommand=function(self)
		if not (self.artPath and self.artIsMovie and self.wasFocus) then return end
		local row = self:GetChild("SongRow")
		local art = row:GetChild("Jacket")
		local ok = pcall(function()
			art:Load(self.artPath)
			if art.SetDecodeMovie then art:SetDecodeMovie(true) end
			art:animate(true)
		end)
		self.loadedArtPath = ok and self.artPath or nil
		art:visible(ok)
		row:GetChild("JacketFallback"):visible(not ok)
		self.movieFit = ok and 1.0 or nil
	end,
}

af[#af+1] = Def.Quad{
	Name="Guide",
	InitCommand=function(self)
		self:align(0.5,0.5):zoomto(1, G.Pitch):diffuse(rail)
	end,
}
af[#af+1] = Def.Quad{
	Name="Highlight",
	InitCommand=function(self)
		self:align(0,0.5):x(itemLeft):zoomto(itemWidth, itemHeight)
			:diffuse(accent):diffusealpha(0.22):diffuserightedge(color("0,0,0,0")):visible(false)
	end,
}
af[#af+1] = Def.Quad{
	Name="Bar",
	InitCommand=function(self)
		self:align(0,0.5):x(itemLeft):zoomto(3, itemHeight):diffuse(accent):visible(false)
	end,
}

local songRow = Def.ActorFrame{Name="SongRow"}
songRow[#songRow+1] = Def.Quad{
	Name="JacketStroke",
	InitCommand=function(self)
		self:align(0,0.5):x(jacketX-1):zoomto(jacketSize+2, jacketSize+2):diffuse(line)
	end,
}
songRow[#songRow+1] = Def.Quad{
	Name="JacketFallback",
	InitCommand=function(self)
		self:align(0,0.5):x(jacketX):zoomto(jacketSize, jacketSize):diffuse(panel2)
	end,
}
songRow[#songRow+1] = Def.Banner{
	Name="Jacket",
	InitCommand=function(self) self:visible(false) end,
}
songRow[#songRow+1] = Def.BitmapText{
	Name="Artist", Font=VOLT26.Type.Label,
	InitCommand=function(self)
		self:xy(textX, -12):horizalign(left):vertalign(middle):shadowlength(0):diffuse(dim)
	end,
}
songRow[#songRow+1] = Def.BitmapText{
	Name="Title", Font=VOLT26.Type.Display,
	InitCommand=function(self)
		self:xy(textX, 11):horizalign(left):vertalign(middle):shadowlength(0):diffuse(ink)
	end,
}
songRow[#songRow+1] = Def.BitmapText{
	Name="Meter", Font=VOLT26.Type.Label,
	InitCommand=function(self)
		self:xy(meterX, 0):horizalign(right):vertalign(middle):shadowlength(0):diffuse(mute)
	end,
}
af[#af+1] = songRow

-- Pack rows wear the same face as the sticky heading they turn into once they
-- scroll off the top, so the transition reads as one label moving rather than
-- two labels swapping.
local packRow = Def.ActorFrame{Name="PackRow"}
packRow[#packRow+1] = Def.BitmapText{
	Name="Name", Font=VOLT26.Type.Label,
	InitCommand=function(self)
		self:xy(itemLeft+12, 0):horizalign(left):vertalign(middle):shadowlength(0):diffuse(ink)
	end,
}
packRow[#packRow+1] = Def.BitmapText{
	Name="Count", Font=VOLT26.Type.Label,
	InitCommand=function(self)
		self:xy(meterX, 0):horizalign(right):vertalign(middle):shadowlength(0):diffuse(dim)
	end,
}
af[#af+1] = packRow

af[#af+1] = Def.ActorMultiVertex{
	Name="Dot",
	InitCommand=function(self)
		self:SetDrawState({Mode="DrawMode_Fan"}):SetVertices(circleVertices(4, rail))
	end,
}

return af
