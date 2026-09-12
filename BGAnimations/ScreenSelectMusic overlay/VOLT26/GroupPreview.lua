-- Restores the recycled scrolling preview from ef389ebd, in the current
-- Song Select design space and palette. Only cached still thumbnails scroll.
local H = ...
local width = H.RowsW
local height = H.InnerBottom-H.InnerTop
local pad = 18
local headerH = 104
local footerH = 34
local rowCount = 9
local poolCount = rowCount+1
local listTop = headerH
local listBottom = height-footerH
local pitch = (listBottom-listTop)/rowCount
local artSize = math.min(56, pitch-12)
local textX = pad+artSize+18
local rowWidth = width-pad*2
local textWidth = width-textX-pad-110
local secondsPerSong = 0.9
local movies = {avi=true, f4v=true, flv=true, mkv=true, mp4=true, mpeg=true,
	mpg=true, mov=true, ogv=true, ogg=true, webm=true, wmv=true}

local function still(path)
	return path and path ~= "" and not movies[(path:match("%.([^.]+)$") or ""):lower()]
end

local function artwork(song)
	if song:HasJacket() and still(song:GetJacketPath()) then return song:GetJacketPath(), "Jacket" end
	if song:HasBanner() and still(song:GetBannerPath()) then return song:GetBannerPath(), "Banner" end
end

local function centerCrop(sprite, w, h)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):zoom(1):align(0.5,0.5)
	local sw, sh = math.max(1,sprite:GetWidth()), math.max(1,sprite:GetHeight())
	if sw/sh > w/h then
		local crop = (1-(w/h)/(sw/sh))/2
		sprite:cropleft(crop):cropright(crop):zoom(h/sh)
	else
		local crop = (1-(sw/sh)/(w/h))/2
		sprite:croptop(crop):cropbottom(crop):zoom(w/sw)
	end
end

local function setRow(row, song, index)
	row:visible(song ~= nil)
	if not song then return end
	H.SetDisplay(row:GetChild("Title"), song:GetDisplayMainTitle(), 28, textWidth)
	H.SetLabel(row:GetChild("Artist"), song:GetDisplayArtist(), 11, textWidth)
	H.SetLabel(row:GetChild("Index"), string.format("%02d",index), 12)
	local art = row:GetChild("Artwork")
	local path, cache = artwork(song)
	local loaded = false
	if path then
		loaded = pcall(function()
			if row.loadedArtPath ~= path then
				art:LoadFromCached(cache,path):animate(false)
				row.loadedArtPath = path
			end
			centerCrop(art,artSize,artSize)
		end)
		if not loaded then row.loadedArtPath = nil end
	end
	art:visible(loaded)
	row:GetChild("Fallback"):visible(not loaded)
end

local function updateRange(self)
	local count = #self.songs
	local first = self.scrollOffset+1
	local last = count <= rowCount and count or ((first+rowCount-2)%count)+1
	H.SetLabel(self:GetChild("Range"), count > 0 and
		string.format("%02d - %02d / %d",first,last,count) or "",11)
end

local function resetRows(self)
	self.scrollOffset, self.scrollPixels, self.scrollElapsed = 0, 0, 0
	self.rowOrder = {}
	for i=1,poolCount do
		local row = self:GetChild("Row"..i)
		self.rowOrder[i] = row
		row:xy(0,listTop+(i-0.5)*pitch)
		local count = #self.songs
		local index = count > 0 and ((i-1)%count)+1 or nil
		if count <= rowCount and i > count then index = nil end
		setRow(row,index and self.songs[index] or nil,index)
	end
	updateRange(self)
end

local af = Def.ActorFrame{
	Name="GroupPreview",
	InitCommand=function(self)
		self:xy(H.RowsX,H.InnerTop):visible(false)
		self.songs = {}
		self:SetUpdateFunction(function(frame,delta)
			if not frame:GetVisible() then return end
			-- A movie banner reports no size until its first frame lands, so the
			-- crop waits for it here rather than measuring nothing.
			if frame.bannerFit then
				frame.bannerFit = frame.bannerFit-(delta or 0)
				local banner = frame:GetChild("Banner")
				if H.ArtReady(banner) then
					centerCrop(banner,300,72)
					frame.bannerFit = nil
				elseif frame.bannerFit <= 0 then
					frame.bannerFit = nil
				end
			end
			if frame.modalOpen or H.SelectedPack() ~= frame.group then return end
			if #frame.songs <= rowCount then return end
			frame.scrollElapsed = frame.scrollElapsed+(delta or 0)
			if VOLT26.Performance.IsEnabled() and frame.scrollElapsed < 1/30 then return end
			local distance = pitch*frame.scrollElapsed/secondsPerSong
			frame.scrollElapsed = 0
			frame.scrollPixels = frame.scrollPixels+distance
			-- At most one cycle is useful after a stalled frame.
			frame.scrollPixels = frame.scrollPixels % (#frame.songs*pitch)
			while frame.scrollPixels >= pitch do
				frame.scrollPixels = frame.scrollPixels-pitch
				frame.scrollOffset = (frame.scrollOffset+1)%#frame.songs
				local row = table.remove(frame.rowOrder,1)
				table.insert(frame.rowOrder,row)
				local index = ((frame.scrollOffset+poolCount-1)%#frame.songs)+1
				setRow(row,frame.songs[index],index)
			end
			for slot,row in ipairs(frame.rowOrder) do
				row:y(listTop+(slot-0.5)*pitch-frame.scrollPixels)
			end
			updateRange(frame)
		end)
	end,
	RefreshCommand=function(self)
		local group = H.SelectedPack()
		self:visible(group ~= nil)
		if not group then self.group = nil; return end
		if self.group == group then return end
		local ok,songs = pcall(function() return SONGMAN:GetSongsInGroup(group) end)
		self.songs = ok and type(songs) == "table" and songs or {}
		self.group = group
		resetRows(self)
		H.SetLabel(self:GetChild("Kicker"),H.String("PackPreview"),11)
		H.SetDisplay(self:GetChild("Heading"),group,38,width-400)
		H.SetLabel(self:GetChild("Count"),string.format(H.String("PackPreviewCount"),#self.songs),11)
		H.SetLabel(self:GetChild("Empty"),#self.songs == 0 and H.String("PackPreviewEmpty") or "",14)
		-- The pack's own banner is a single actor rather than one per scrolling
		-- row, so a video one is worth decoding here even though the thumbnails
		-- below stay on stills.
		local banner = self:GetChild("Banner")
		local found,path = pcall(function() return SONGMAN:GetSongGroupBannerPath(group) end)
		H.StopArt(banner)
		local loaded = found and H.LoadArt(banner,path,"Banner")
		banner:visible(loaded and true or false)
		self.bannerFit = loaded and 1.0 or nil
		if loaded and H.ArtReady(banner) then
			centerCrop(banner,300,72)
			self.bannerFit = nil
		end
	end,
	VOLT26ModalOverlayOpenedMessageCommand=function(self) self.modalOpen = true end,
	VOLT26ModalOverlayClosedMessageCommand=function(self) self.modalOpen = false end,
}

af[#af+1] = H.Rule{Name="Border", Width=width, Height=height}
af[#af+1] = H.Rule{Name="Surface", X=1, Y=1, Width=width-2, Height=height-2, Tint=H.Panel}

-- Keep the old preview's clipping contract: mask the recycled rows at both
-- edges, then clear depth before drawing the header and footer.
af[#af+1] = Def.Quad{InitCommand=function(self)
	self:align(0,1):xy(1,listTop):zoomto(width-2,height):MaskSource()
end}
af[#af+1] = Def.Quad{InitCommand=function(self)
	self:align(0,0):xy(1,listBottom):zoomto(width-2,height):MaskSource()
end}
for i=1,poolCount do
	local row = Def.ActorFrame{Name="Row"..i, InitCommand=function(self) self:MaskDest() end}
	row[#row+1] = H.Rule{X=pad,Y=-pitch/2+1,Width=rowWidth,Height=pitch-2,Tint=H.Panel2}
	row[#row+1] = H.Rule{X=pad,Y=pitch/2-1,Width=rowWidth,Height=1,Alpha=0.55}
	row[#row+1] = H.Rule{Name="Fallback",X=pad,Y=-artSize/2,Width=artSize,Height=artSize,Tint=H.Rail}
	row[#row+1] = Def.Sprite{Name="Artwork",InitCommand=function(self) self:xy(pad+artSize/2,0):visible(false) end}
	row[#row+1] = H.DisplayText{Name="Title",X=textX,Y=-12,Px=28,Tint=H.Ink}
	row[#row+1] = H.LabelText{Name="Artist",X=textX,Y=17,Px=11,Tint=H.Mute}
	row[#row+1] = H.LabelText{Name="Index",X=width-pad-16,Y=0,Px=12,Tint=H.Dim,Align=right}
	af[#af+1] = row
end
af[#af+1] = Def.Quad{InitCommand=function(self) self:diffusealpha(0):clearzbuffer(true) end}
af[#af+1] = H.Rule{Width=width,Height=2,Tint=H.P1}
af[#af+1] = H.Rule{Y=headerH,Width=width,Height=1}
af[#af+1] = H.LabelText{Name="Kicker",X=pad,Y=25,Px=11,Tint=H.Dim}
af[#af+1] = H.DisplayText{Name="Heading",X=pad,Y=63,Px=38,Tint=H.Ink}
af[#af+1] = Def.Sprite{Name="Banner",InitCommand=function(self) self:xy(width-pad-150,headerH/2):visible(false) end}
af[#af+1] = H.Rule{Y=listBottom,Width=width,Height=1}
af[#af+1] = H.LabelText{Name="Count",X=pad,Y=height-footerH/2,Px=11,Tint=H.Mute}
af[#af+1] = H.LabelText{Name="Range",X=width-pad,Y=height-footerH/2,Px=11,Tint=H.Dim,Align=right}
af[#af+1] = H.LabelText{Name="Empty",X=width/2,Y=(listTop+listBottom)/2,Px=14,Tint=H.Dim,Align=center}

H.AddSettledRefresh(af,0.35,0,12)
return af
