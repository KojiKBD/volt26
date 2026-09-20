local H = ...

-- The header carries song-level facts only: what every player is looking at.
-- Nothing here is per-player, which is what keeps the two columns below from
-- repeating it.
--
-- The band is read in three places that never move: the facts at the left
-- edge, the song in the middle above the wheel it was chosen from, and the
-- pack at the right edge over its own banner.
local bandTop = H.TopBarH
local bandHeight = H.HeaderH
local bandBottom = bandTop + bandHeight
-- The banner is allowed this much of the band before it is cropped from the
-- left, which is what stops a wide pack banner from reaching the title.
local bannerMaxWidth = 480
local factGap = 40
local factsX = H.Pad
local titleX = H.W/2
local titleWidth = 620
local packRight = H.W - H.Pad
local packScrimWidth = 460

local facts = {"Bpm", "Duration"}

local function bannerPath()
	local group = H.Pack()
	if group ~= "" then
		local ok, path = pcall(function() return SONGMAN:GetSongGroupBannerPath(group) end)
		if ok and path and path ~= "" then return path end
	end
	local song = GAMESTATE:GetCurrentSong()
	if song and song:HasBanner() then return song:GetBannerPath() end
	return nil
end

local function fitBanner(sprite)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):align(1,0)
	local sourceHeight = math.max(1, sprite:GetHeight())
	-- The design is explicit that the image lives inside the band rather than
	-- being blown up past it, so height drives the zoom and width follows.
	local zoom = bandHeight/sourceHeight
	sprite:zoom(zoom)
	local width = sprite:GetWidth()*zoom
	if width > bannerMaxWidth then sprite:cropleft(1 - bannerMaxWidth/width) end
	sprite:xy(H.W, bandTop)
end

local function bpmText()
	local player, chart = H.PreviewSource()
	if GAMESTATE:IsCourseMode() or not chart then
		local song = GAMESTATE:GetCurrentSong()
		local ok, bpms = pcall(function() return song and song:GetDisplayBpms() or nil end)
		if ok and type(bpms) == "table" and bpms[1] then
			if math.floor(bpms[1]+0.5) == math.floor(bpms[2]+0.5) then
				return tostring(math.floor(bpms[1]+0.5))
			end
			return string.format("%d-%d", math.floor(bpms[1]+0.5), math.floor(bpms[2]+0.5))
		end
		return H.Dash
	end
	return H.BPM(player, chart)
end

local af = Def.ActorFrame{
	Name="SongHeader",
	RefreshCommand=function(self)
		local item = H.Item()

		H.SetLabel(self:GetChild("BpmLabel"), "BPM", 9)
		H.SetLabel(self:GetChild("DurationLabel"), H.String("Duration"), 9)
		H.SetDisplay(self:GetChild("BpmValue"), bpmText(), 28, 220)
		H.SetDisplay(self:GetChild("DurationValue"), H.Length(), 28, 220)

		-- The facts run outwards from the left edge, each one starting past the
		-- widest line of the one before it.
		local x = factsX
		for _, fact in ipairs(facts) do
			local label = self:GetChild(fact.."Label")
			local value = self:GetChild(fact.."Value")
			label:x(x)
			value:x(x)
			x = x + math.max(label:GetZoomedWidth(), value:GetZoomedWidth()) + factGap
		end

		H.SetLabel(self:GetChild("PackLabel"), "PACK", 9)
		H.SetDisplay(self:GetChild("PackValue"), H.Pack():upper(), 28, 420)

		local banner = self:GetChild("Banner")
		local path = item and bannerPath() or nil
		if path and self.loadedPath ~= path then
			H.StopArt(banner)
			self.loadedPath = H.LoadArt(banner, path, "Banner") and path or nil
		elseif not path then
			H.StopArt(banner)
			self.loadedPath = nil
		end
		banner:visible(self.loadedPath ~= nil)
		-- The pack name stands on the banner, so the scrim under it is only
		-- there when the banner is.
		self:GetChild("PackScrim"):visible(self.loadedPath ~= nil)
		self.fitTries = 0
		if self.loadedPath then self:playcommand("FitBanner") end

		H.SetLabel(self:GetChild("Eyebrow"),
			H.String("NowSelected").." - "..H.String("SharedInfo"), 11, titleWidth)
		H.SetDisplay(self:GetChild("Title"), H.Title(item), 46, titleWidth)
		H.SetDisplay(self:GetChild("Artist"), H.Artist(item), 22, titleWidth)
	end,
	-- A movie banner has no size until its first frame is decoded, and fitting
	-- one before then measures nothing and blows it up to fill the screen.  The
	-- fit is retried for a second or so and then given up on, so a file the
	-- decoder cannot open does not leave this running for the life of the screen.
	FitBannerCommand=function(self)
		if not self.loadedPath then return end
		local banner = self:GetChild("Banner")
		if H.ArtReady(banner) then
			fitBanner(banner)
			return
		end
		self.fitTries = (self.fitTries or 0) + 1
		if self.fitTries > 40 then
			banner:visible(false)
			self:GetChild("PackScrim"):visible(false)
			return
		end
		banner:stoptweening():sleep(0.03):queuecommand("RetryFit")
	end,
}

af[#af+1] = Def.Sprite{
	Name="Banner",
	RetryFitCommand=function(self) self:GetParent():playcommand("FitBanner") end,
	InitCommand=function(self)
		self:visible(false)
		-- The fade is the sprite's own vertex alpha rather than a mask: the
		-- design wants the ramp baked into the image, and per-edge diffuse is
		-- the closest thing to that for artwork the theme does not own.
		self:diffuse(color("1,1,1,1")):diffuseleftedge(color("1,1,1,0"))
	end,
}
-- Enough ground under the pack name for it to be read off whatever artwork the
-- pack ships, and none where there is no artwork to read it off.
af[#af+1] = Def.Quad{
	Name="PackScrim",
	InitCommand=function(self)
		self:align(1,0):xy(H.W, bandTop):zoomto(packScrimWidth, bandHeight)
			:diffuse(H.Bg):diffusealpha(0.72):diffuseleftedge(color("0,0,0,0")):visible(false)
	end,
}
af[#af+1] = Def.Quad{
	Name="Veil",
	InitCommand=function(self)
		self:align(0,0):xy(0, bandTop):zoomto(H.W*0.30, bandHeight)
			:diffuse(H.P1):diffusealpha(0.20):diffuserightedge(color("0,0,0,0"))
	end,
}

af[#af+1] = H.LabelText{Name="Eyebrow", Px=11, Tint=H.Mute, Align=center, X=titleX, Y=bandTop+26}
af[#af+1] = H.DisplayText{Name="Title", Px=46, Tint=H.Ink, Align=center, X=titleX, Y=bandTop+62}
af[#af+1] = H.DisplayText{Name="Artist", Px=22, Tint=H.Mute, Align=center, X=titleX, Y=bandTop+100}

for _, fact in ipairs(facts) do
	af[#af+1] = H.LabelText{Name=fact.."Label", Px=9, Tint=H.Dim, Y=bandTop+52}
	af[#af+1] = H.DisplayText{Name=fact.."Value", Px=28, Tint=H.Ink, Y=bandTop+74}
end

af[#af+1] = H.LabelText{Name="PackLabel", Px=9, Tint=H.Dim, Align=right, X=packRight, Y=bandTop+52}
af[#af+1] = H.DisplayText{Name="PackValue", Px=28, Tint=H.Ink, Align=right, X=packRight, Y=bandTop+74}

af[#af+1] = H.Rule{Name="Divider", Y=bandBottom-1, Width=H.W, Height=1}

H.AddRefresh(af)
return af
