local H = ...

local function centerCrop(sprite, width, height)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):zoom(1):align(0.5,0.5)
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

-- There must be exactly one actor decoding the selected movie banner.  Movie
-- textures are shared by StepMania, so putting a decoder in every recycled
-- MusicWheel row makes the same texture advance several times per frame.
return Def.Banner{
	Name="VOLT26FocusedBanner",
	InitCommand=function(self)
		-- The wheel is offset 32 units from the layout origin and focused
		-- artwork begins at x=24 plus the song indent, with a width of 132.
		-- Its center is therefore 32 + 24 + indent + 66, directly after the
		-- red connector, which stretches to cover the indent.
		self:xy(122 + VOLT26.MusicSelection.WheelSongIndent,230):visible(false)
	end,
	RefreshCommand=function(self)
		local song = GAMESTATE:GetCurrentSong()
		local selectedSong = H.SelectedType() == "WheelItemDataType_Song"
		if not selectedSong or not song or not song:HasBanner() then
			self:visible(false)
			return
		end
		local path = song:GetBannerPath()
		if self.loadedPath ~= path then
			-- Do not reuse the global banner cache here.  ITGmania keeps that
			-- cache alive across theme changes, so entering VOLT26 after Simply
			-- Love can otherwise retain the previous theme's movie state.
			local ok = pcall(function()
				self:Load(path)
				self:animate(true)
				if self.SetDecodeMovie then self:SetDecodeMovie(true) end
			end)
			if not ok then
				self.loadedPath = nil
				self:visible(false)
				return
			end
			self.loadedPath = path
		end
		centerCrop(self,132,56)
		self:visible(true)
	end,
	OnCommand=function(self) self:queuecommand("Refresh") end,
	CurrentSongChangedMessageCommand=function(self) self:queuecommand("Refresh") end,
	VOLT26SongSelectRefreshMessageCommand=function(self) self:queuecommand("Refresh") end,
}
