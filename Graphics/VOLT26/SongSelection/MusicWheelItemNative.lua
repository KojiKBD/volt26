-- Engine-native VOLT26 wheel row.  The real MusicWheel still owns focus,
-- scrolling, sorting, input, and actor recycling.
local kind = ... or "Song"
local font = "P5hatty"
local red = color("#ed1c24")
local white = color("#f5f5f2")
local muted = color("#a7a7a7")
local indexCache = setmetatable({}, {__mode="k"})

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

local function songIndex(song)
	if not song then return "" end
	if indexCache[song] then return indexCache[song] end
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(song:GetGroupName()) end)
	if ok and songs then
		for i, candidate in ipairs(songs) do
			if candidate == song then indexCache[song] = tostring(i); return tostring(i) end
		end
	end
	return "--"
end

local function bpm(song)
	if not song or not song.GetDisplayBpms then return "" end
	local ok, values = pcall(function() return song:GetDisplayBpms() end)
	if not ok or not values then return "" end
	local low, high = tonumber(values[1]), tonumber(values[2])
	if not low then return "" end
	local rate = VOLT26.MusicSelection.GetMusicRate()
	low = math.floor(low*rate+0.5)
	high = math.floor((high or low)*rate+0.5)
	return low == high and tostring(low) or (low.."-"..high)
end

local function label(params)
	if params.Song then return params.Song:GetDisplayMainTitle() end
	if params.Course then return params.Course:GetDisplayFullTitle() end
	return params.Label or params.Text or ""
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:x(12):visible(false)
		self:SetUpdateFunction(function(frame)
			local isFocus = focused(frame)
			if isFocus ~= frame.wasFocus then frame.wasFocus=isFocus; frame:playcommand("Focus", {Focused=isFocus}) end
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
		self:GetChild("Title"):settext(label(params)):maxwidth(166/0.065)
		self:GetChild("Artist"):settext(params.Song and params.Song:GetDisplayArtist() or "")
		self:GetChild("BPM"):settext(params.Song and ("BPM "..bpm(params.Song)) or "")
		self:GetChild("Index"):settext(params.Song and songIndex(params.Song) or (kind == "Section" and ">" or ""))
		self.wasFocus = focused(self)
		self:playcommand("Focus", {Focused=self.wasFocus})
	end,
	FocusCommand=function(self, params)
		local on = params.Focused
		local titleZoom = on and 0.074 or 0.065
		self:GetChild("Selected"):visible(on)
		self:GetChild("IndexBlock"):diffuse(on and white or color("#e6e6e6"))
		self:GetChild("Index"):diffuse(color("#101010"))
		self:GetChild("Title"):diffuse(on and white or muted):zoom(titleZoom):maxwidth(166/titleZoom)
		self:GetChild("Artist"):visible(on):diffuse(white)
		self:GetChild("BPM"):diffuse(on and white or muted)
	end,
}

af[#af+1] = Def.ActorMultiVertex{
	Name="Selected",
	InitCommand=function(self)
		self:SetDrawState({Mode="DrawMode_Fan"}):SetVertices({
			{{30,-17,0},red},{{264,-14,0},red},{{256,16,0},red},{{35,19,0},red},{{25,9,0},red}
		}):visible(false)
	end,
}
af[#af+1] = Def.Quad{
	Name="IndexBlock", InitCommand=function(self) self:x(14):zoomto(31,27):skewx(-0.12):diffuse(white) end,
}
af[#af+1] = Def.BitmapText{Name="Index", Font=font, InitCommand=function(self) self:x(14):zoom(0.067):diffuse(color("#101010")) end}
af[#af+1] = Def.BitmapText{Name="Title", Font=font, InitCommand=function(self) self:xy(37,-5):horizalign(left):zoom(0.065):maxwidth(166/0.065) end}
af[#af+1] = Def.BitmapText{Name="Artist", Font=font, InitCommand=function(self) self:xy(38,9):horizalign(left):zoom(0.038):maxwidth(154/0.038):visible(false) end}
af[#af+1] = Def.BitmapText{Name="BPM", Font=font, InitCommand=function(self) self:x(254):horizalign(right):zoom(0.044):maxwidth(52/0.044) end}
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(34,15):zoomto(220,1):rotationz(0.4):diffuse(white):diffusealpha(0.22) end}

return af
