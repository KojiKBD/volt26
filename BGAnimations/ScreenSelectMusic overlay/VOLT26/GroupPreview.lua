local H = ...
local rowCount = 9
local poolCount = rowCount+1
local rowStart = 31
local rowSpacing = 36
local secondsPerSong = 0.5

local function centerCrop(sprite,width,height)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):zoom(1):align(0.5,0.5)
	local sourceWidth, sourceHeight = math.max(1,sprite:GetWidth()), math.max(1,sprite:GetHeight())
	local sourceAspect, targetAspect = sourceWidth/sourceHeight, width/height
	if sourceAspect > targetAspect then
		local crop = (1-targetAspect/sourceAspect)/2
		sprite:cropleft(crop):cropright(crop):zoom(height/sourceHeight)
	else
		local crop = (1-sourceAspect/targetAspect)/2
		sprite:croptop(crop):cropbottom(crop):zoom(width/sourceWidth)
	end
end

local function artwork(song)
	if song:HasJacket() then return song:GetJacketPath() end
	-- Movie banners are rendered only by FocusedBanner.lua.  Loading the same
	-- movie into scrolling thumbnails makes StepMania advance its shared
	-- texture once per actor and visibly accelerates playback.
	if song:HasBanner() and not tostring(song:GetBannerPath()):lower():match("%.mp4$")
		and not tostring(song:GetBannerPath()):lower():match("%.avi$")
		and not tostring(song:GetBannerPath()):lower():match("%.og[gv]$") then
		return song:GetBannerPath()
	end
	if song:HasBackground() then return song:GetBackgroundPath() end
	return nil
end

local function setRow(row, song, songIndex)
	row:visible(song ~= nil)
	if not song then return end
	row:GetChild("Title"):settext(song:GetDisplayMainTitle()):maxwidth(294/H.BoldZoom(0.047))
	row:GetChild("Artist"):settext(song:GetDisplayArtist()):maxwidth(294/H.NormalZoom(0.033))
	local art, fallback = row:GetChild("Artwork"), row:GetChild("Fallback")
	local path = artwork(song)
	local loaded = false
	if path then
		loaded = pcall(function()
			local loadedNew = row.loadedArtPath ~= path
			if loadedNew then
				art:Load(path)
				row.loadedArtPath = path
			end
		end)
		if not loaded then row.loadedArtPath = nil end
	end
	art:visible(loaded)
	fallback:visible(not loaded)
	row:GetChild("Index"):visible(not loaded):settext(string.format("%02d",songIndex or 0))
	if loaded then centerCrop(art,32,32) end
end

local function updateRange(self)
	local songs = self.songs or {}
	local count = #songs
	if count <= rowCount then
		self:GetChild("More"):visible(false)
		return
	end
	local first = (self.scrollOffset or 0) + 1
	local last = ((first + rowCount - 2) % count) + 1
	local range = last >= first and string.format("%02d-%02d / %d",first,last,count)
		or string.format("%02d-%d + 01-%02d / %d",first,count,last,count)
	self:GetChild("More"):visible(true):settext(range)
end

local function resetRows(self)
	local songs = self.songs or {}
	local count = #songs
	self.rowOrder = {}
	self.scrollPixels = 0
	for i=1,poolCount do
		local row = self:GetChild("Row"..i)
		row:stoptweening():xy(0,rowStart+(i-1)*rowSpacing):diffusealpha(1)
		self.rowOrder[i] = row
		local rawIndex = (self.scrollOffset or 0)+i
		local index = count > 0 and ((rawIndex-1) % count)+1 or nil
		if count <= rowCount and rawIndex > count then index = nil end
		setRow(row, index and songs[index] or nil, index)
	end
	updateRange(self)
end

local af = Def.ActorFrame{
	Name="GroupPreview",
	InitCommand=function(self)
		self:xy(250,82)
		self.scrollOffset = 0
		self.scrollPixels = 0
		self:SetUpdateFunction(function(frame, delta)
			if not frame:GetVisible() then return end
			if not frame.songs or #frame.songs <= rowCount then return end
			local distance = rowSpacing*(delta or 0)/secondsPerSong
			frame.scrollPixels = frame.scrollPixels+distance
			for _,row in ipairs(frame.rowOrder or {}) do row:addy(-distance) end
			while frame.scrollPixels >= rowSpacing do
				frame.scrollPixels = frame.scrollPixels-rowSpacing
				frame.scrollOffset = (frame.scrollOffset+1) % #frame.songs
				local row = table.remove(frame.rowOrder,1)
				table.insert(frame.rowOrder,row)
				local index = ((frame.scrollOffset+poolCount-1) % #frame.songs)+1
				setRow(row,frame.songs[index],index)
				for slot,positionedRow in ipairs(frame.rowOrder) do
					positionedRow:xy(0,rowStart+(slot-1)*rowSpacing-frame.scrollPixels)
				end
				updateRange(frame)
			end
		end)
	end,
	RefreshCommand=function(self)
		local selected = H.SelectedType()
		local group = H.SelectedSection()
		local visible = (selected == "WheelItemDataType_Section" or selected == "WheelItemDataType_ParentSection") and group and group ~= ""
		self:visible(visible and true or false)
		if not visible then return end
		local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(group) end)
		songs = ok and songs or {}
		self:GetChild("Heading"):settext(group):maxwidth(270/H.BoldZoom(0.060))
		self:GetChild("Count"):settext(#songs.." SONGS")
		if self.scrollGroup ~= group then
			self:stoptweening()
			self.scrollGroup = group
			self.songs = songs
			self.scrollOffset = 0
			resetRows(self)
		else
			self.songs = songs
			updateRange(self)
		end
	end,
}

af[#af+1] = Def.Quad{
	Name="Surface",
	InitCommand=function(self) self:align(0,0):xy(-8,-8):zoomto(370,374):diffuse(H.Surface):diffusealpha(H.SurfaceAlpha) end,
}
af[#af+1] = Def.BitmapText{
	Name="Heading", Font=H.FontBold,
	InitCommand=function(self) self:xy(0,4):horizalign(left):zoom(H.BoldZoom(0.060)):diffuse(H.White) end,
}
af[#af+1] = Def.BitmapText{
	Name="Count", Font=H.FontBold,
	InitCommand=function(self) self:xy(354,4):horizalign(right):zoom(H.BoldZoom(0.034)):diffuse(color("#ff4b4b")) end,
}

af[#af+1] = Def.Quad{
	InitCommand=function(self) self:align(0,1):xy(-8,rowStart-17):zoomto(370,400):MaskSource() end,
}
af[#af+1] = Def.Quad{
	InitCommand=function(self) self:align(0,0):xy(-8,rowStart+(rowCount-1)*rowSpacing+17):zoomto(370,400):MaskSource() end,
}

for i=1,poolCount do
	local row = Def.ActorFrame{Name="Row"..i, InitCommand=function(self) self:xy(0,rowStart+(i-1)*rowSpacing):MaskDest() end}
	row[#row+1] = Def.Quad{InitCommand=function(self) self:align(0,0.5):xy(0,0):zoomto(354,34):diffuse(H.Surface):diffusealpha(i%2==0 and 0.76 or 0.90) end}
	row[#row+1] = Def.Quad{Name="Fallback", InitCommand=function(self) self:xy(17,0):zoomto(32,32):diffuse(color("#291d20")) end}
		row[#row+1] = Def.Sprite{Name="Artwork", InitCommand=function(self) self:xy(17,0):visible(false) end}
	row[#row+1] = Def.BitmapText{Name="Index", Font=H.FontBold, InitCommand=function(self) self:xy(17,0):zoom(H.BoldZoom(0.039)):diffuse(color("#d9666b")):visible(false) end}
	row[#row+1] = Def.BitmapText{Name="Title", Font=H.FontBold, InitCommand=function(self) self:xy(40,-6):horizalign(left):zoom(H.BoldZoom(0.047)):diffuse(H.Black) end}
	row[#row+1] = Def.BitmapText{Name="Artist", Font=H.Font, InitCommand=function(self) self:xy(40,9):horizalign(left):zoom(H.NormalZoom(0.033)):diffuse(H.Muted) end}
	af[#af+1] = row
end

af[#af+1] = Def.Quad{InitCommand=function(self) self:diffusealpha(0):clearzbuffer(true) end}

af[#af+1] = Def.BitmapText{
	Name="More", Font=H.FontBold,
	InitCommand=function(self) self:xy(354,361):horizalign(right):zoom(H.BoldZoom(0.031)):diffuse(H.Muted):visible(false) end,
}

H.AddRefresh(af)
return af
