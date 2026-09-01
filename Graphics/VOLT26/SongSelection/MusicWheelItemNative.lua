-- Engine-native vertical Song Select row.  MusicWheel keeps ownership of
-- focus, sorting, input, and actor recycling; this actor only presents it.
local kind = ... or "Song"
local font = "Helvetica Normal"
local boldFont = "Helvetica Bold"
local fontZoom = 116 / 28
local boldFontZoom = 116 / 29
local railRed = color("#840000")
local focusRed = color("#ff0000")
local black = color("#f6eeee")
local muted = color("#bdaeb0")

local function hasNonASCII(text)
	return tostring(text or ""):find("[\128-\255]") ~= nil
end

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

local function focused(self)
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
	-- simple `Label or Text` silently erased the focused pack title.
	if params.Label and params.Label ~= "" then return params.Label end
	return params.Text or ""
end

local function compactSectionLabel(text)
	text = tostring(text or "")
	if #text <= 24 then return text end
	return text:sub(1,21).."..."
end

local function artworkPaths(song)
	if not song then return nil, nil end
	local small, large
	if song:HasJacket() then small = song:GetJacketPath() end
	if not small and song:HasBanner() then small = song:GetBannerPath() end
	if not small and song:HasBackground() then small = song:GetBackgroundPath() end
	large = small
	return small, large
end

local function sectionSongs(section)
	if not section or section == "" then return {} end
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(section) end)
	return ok and songs or {}
end

local function sectionArtwork(section)
	local ok, path = pcall(function() return SONGMAN:GetSongGroupBannerPath(section) end)
	if ok and path and path ~= "" then return path end
	local songs = sectionSongs(section)
	if songs[1] then
		local small, large = artworkPaths(songs[1])
		return large or small
	end
	return nil
end

local function centerCrop(sprite, x, y, width, height)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):zoom(1)
		:align(0.5,0.5):xy(x+width/2,y+height/2)
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

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
		self:SetUpdateFunction(function(frame)
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
		self.section = (not params.Song and not params.Course) and (params.Text or params.Label) or nil
		if self.song then
			self.smallArt, self.largeArt = artworkPaths(self.song)
		elseif self.section then
			local path = sectionArtwork(self.section)
			self.smallArt, self.largeArt = path, path
		else
			self.smallArt, self.largeArt = nil, nil
		end
		self.sectionTitle = self.section and label(params) or nil
		if self.section and (not self.sectionTitle or self.sectionTitle == "") then self.sectionTitle = self.section end
		self:GetChild("Title"):settext(self.section and compactSectionLabel(self.sectionTitle) or label(params))
		local songs = self.section and sectionSongs(self.section) or nil
		self.sectionSongCount = songs and #songs or 0
		local artistText = params.Song and params.Song:GetDisplayArtist()
			or (songs and ("PACK   -   "..self.sectionSongCount.." SONGS")) or ""
		self.artistUsesCJK = hasNonASCII(artistText)
		self:GetChild("Artist"):settext(artistText)
		self:GetChild("ArtistCJK"):settext(artistText)
		self:GetChild("PackMark"):settext("PACK")
		self.wasFocus = focused(self)
		self:playcommand("Focus", {Focused=self.wasFocus})
	end,
	FocusCommand=function(self, params)
		local on = params.Focused
		local title = self:GetChild("Title")
		local latinArtist = self:GetChild("Artist")
		local cjkArtist = self:GetChild("ArtistCJK")
		latinArtist:visible(false)
		cjkArtist:visible(false)
		local artist = self.artistUsesCJK and cjkArtist or latinArtist
		local compactArt = self:GetChild("Artwork")
		local hoverArt = self:GetChild("HoverArtwork")
		local art = compactArt
		local fallback = self:GetChild("ArtworkFallback")
		local packMark = self:GetChild("PackMark")
		local stroke = self:GetChild("ArtworkStroke")
		if self.section then
			title:settext(on and self.sectionTitle or compactSectionLabel(self.sectionTitle))
			latinArtist:settext("PACK   -   "..self.sectionSongCount.." SONGS")
			cjkArtist:settext("PACK   -   "..self.sectionSongCount.." SONGS")
		end
		local path = on and self.largeArt or self.smallArt
		hoverArt:visible(false)
		if path then
			local ok = pcall(function()
				-- Set and Focus can run back-to-back for the same recycled row.
				-- Reopening the same movie decoder on both commands makes animated
				-- banners accelerate after a few wheel movements.
				local cacheKey = "loadedArtPath"
				local loadedNew = self[cacheKey] ~= path
				if loadedNew then
					art:Load(path)
					-- Compact wheel artwork is deliberately a still frame.  This keeps
					-- every song's own banner visible without allowing recycled wheel
					-- rows to advance the same movie texture multiple times.
					art:animate(false)
					if art.SetDecodeMovie then art:SetDecodeMovie(false) end
					self[cacheKey] = path
				end
			end)
			if not ok then
				self.loadedArtPath = nil
			end
			art:visible(ok)
			fallback:visible(not ok)
			packMark:visible(self.section ~= nil and not ok)
		else
			compactArt:visible(false)
			hoverArt:visible(false)
			fallback:visible(self.song ~= nil or self.section ~= nil)
			packMark:visible(self.section ~= nil)
		end
		fallback:diffuse(self.section and color("#31090f") or color("#1c1214"))

		local dot = self:GetChild("Dot")
		dot:SetNumVertices(18):SetVertices(circleVertices(on and 7 or 3, on and focusRed or railRed))
		self:GetChild("SelectionTick"):visible(on)
		stroke:visible(self.section ~= nil):diffuse(on and focusRed or railRed)
		if on then
			centerCrop(art,24,-38,132,56)
			fallback:align(0,0):xy(24,-38):zoomto(132,56)
			stroke:align(0,0):xy(23,-39):zoomto(134,58)
			if self.section then
				-- Explicitly reuse the same actors as a focused song.  MusicWheel
				-- recycles these rows, so leaving the compact title actor around is
				-- what previously kept the pack name inside the artwork.
				title:settext(self.sectionTitle or self.section or ""):stoptweening():visible(true):diffusealpha(1):horizalign(left):xy(24,30):zoom(0.070*boldFontZoom):maxwidth(226/(0.070*boldFontZoom)):diffuse(black)
				artist:settext("PACK   -   "..self.sectionSongCount.." SONGS"):visible(true):horizalign(left):xy(24,46):zoom(0.041*fontZoom):maxwidth(226/(0.041*fontZoom)):diffuse(muted)
				packMark:xy(90,-10):zoom(0.052*boldFontZoom):maxwidth(104/(0.052*boldFontZoom))
			else
				title:horizalign(left):xy(24,30):zoom(0.070*boldFontZoom):maxwidth(226/(0.070*boldFontZoom)):diffuse(black)
				local zoom = self.artistUsesCJK and 0.42 or 0.041*fontZoom
				artist:horizalign(left):xy(24,46):zoom(zoom):maxwidth(226/zoom):diffuse(muted)
				packMark:visible(false)
			end
		else
			centerCrop(art,24,-14,28,28)
			fallback:align(0,0):xy(24,-14):zoomto(28,28)
			stroke:align(0,0):xy(23,-15):zoomto(30,30)
			local zoom = self.artistUsesCJK and 0.38 or 0.037*fontZoom
			artist:horizalign(left):xy(59,-7):zoom(zoom):maxwidth((self.section and 142 or 184)/zoom):diffuse(muted)
			title:horizalign(left):xy(59,8):zoom(0.058*boldFontZoom):maxwidth((self.section and 142 or 184)/(0.058*boldFontZoom)):diffuse(black)
			packMark:xy(38,0):zoom(0.025*boldFontZoom):maxwidth(24/(0.025*boldFontZoom))
		end
		-- FocusedBanner.lua is the sole owner of selected song banners.  Keeping
		-- this wheel copy visible underneath it produces a doubled, horizontally
		-- offset image for static banners and two movie actors for animated ones.
		if on and self.song and self.song:HasBanner() then
			art:visible(false)
			fallback:visible(false)
		end
		title:visible(self.song ~= nil or self.course ~= nil or self.section ~= nil)
		artist:visible(self.song ~= nil or self.section ~= nil)
	end,
}

af[#af+1] = Def.Quad{
	Name="SelectionTick",
	InitCommand=function(self) self:align(0,0.5):xy(7,0):zoomto(16,2):diffuse(focusRed):visible(false) end,
}
af[#af+1] = Def.ActorMultiVertex{
	Name="Dot",
	InitCommand=function(self)
		self:SetDrawState({Mode="DrawMode_Fan"}):SetVertices(circleVertices(3, railRed))
	end,
}
af[#af+1] = Def.Quad{
	Name="ArtworkStroke",
	InitCommand=function(self) self:align(0,0):diffuse(focusRed):visible(false) end,
}
af[#af+1] = Def.Quad{
	Name="ArtworkFallback",
	InitCommand=function(self) self:align(0,0):diffuse(color("#1c1214")):visible(false) end,
}
af[#af+1] = Def.Banner{
	Name="Artwork",
	InitCommand=function(self) self:visible(false) end,
}
af[#af+1] = Def.Banner{
	Name="HoverArtwork",
	InitCommand=function(self) self:visible(false) end,
}
af[#af+1] = Def.BitmapText{
	Name="PackMark", Font=boldFont,
	InitCommand=function(self) self:horizalign(center):diffuse(color("#fff4f4")):visible(false) end,
}
af[#af+1] = Def.BitmapText{
	Name="Title", Font=boldFont,
	InitCommand=function(self) self:horizalign(left):diffuse(black) end,
}
af[#af+1] = Def.BitmapText{
	Name="Artist", Font=font,
	InitCommand=function(self) self:horizalign(left):diffuse(muted) end,
}
af[#af+1] = Def.BitmapText{
	Name="ArtistCJK", Font="Common Normal",
	InitCommand=function(self) self:horizalign(left):diffuse(muted):visible(false) end,
}

return af
