local H = ...

-- The header carries song-level facts only: what every player is looking at.
-- Nothing here is per-player, which is what keeps the two rows below from
-- repeating it.
local bandTop = H.TopBarH
local bandHeight = H.HeaderH
local bandBottom = bandTop + bandHeight
-- The banner is allowed this much of the band before it is cropped from the
-- left, which is what stops a wide pack banner from reaching the titles.
local bannerMaxWidth = 960
local metaGap = 40
local textGap = 56

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
		H.SetLabel(self:GetChild("PackLabel"), "PACK", 9)
		H.SetDisplay(self:GetChild("BpmValue"), bpmText(), 28, 220)
		H.SetDisplay(self:GetChild("DurationValue"), H.Length(), 28, 220)
		H.SetDisplay(self:GetChild("PackValue"), H.Pack():upper(), 28, 300)

		local banner = self:GetChild("Banner")
		local path = item and bannerPath() or nil
		if path and self.loadedPath ~= path then
			local ok = pcall(function()
				banner:Load(path)
				banner:animate(true)
				if banner.SetDecodeMovie then banner:SetDecodeMovie(true) end
			end)
			self.loadedPath = ok and path or nil
		elseif not path then
			self.loadedPath = nil
		end
		banner:visible(self.loadedPath ~= nil)
		if self.loadedPath then fitBanner(banner) end

		local eyebrow = self:GetChild("Eyebrow")
		H.SetLabel(eyebrow, H.String("NowSelected").." - "..H.String("SharedInfo"), 11, 620)

		local title = self:GetChild("Title")
		H.SetDisplay(title, H.Title(item), 52, 620)
		local artist = self:GetChild("Artist")
		H.SetDisplay(artist, H.Artist(item), 24, 620)

		-- The metadata block starts one gap past whichever of the three title
		-- lines runs longest, so it never overlaps and never drifts.
		local textWidth = math.max(eyebrow:GetZoomedWidth(), title:GetZoomedWidth(), artist:GetZoomedWidth())
		local x = H.Pad + textWidth + textGap
		for _, field in ipairs({"Bpm", "Duration", "Pack"}) do
			local label = self:GetChild(field.."Label")
			local value = self:GetChild(field.."Value")
			label:x(x)
			value:x(x)
			x = x + math.max(label:GetZoomedWidth(), value:GetZoomedWidth()) + metaGap
		end
	end,
}

af[#af+1] = Def.Sprite{
	Name="Banner",
	InitCommand=function(self)
		self:visible(false)
		-- The fade is the sprite's own vertex alpha rather than a mask: the
		-- design wants the ramp baked into the image, and per-edge diffuse is
		-- the closest thing to that for artwork the theme does not own.
		self:diffuse(color("1,1,1,1")):diffuseleftedge(color("1,1,1,0"))
	end,
}
af[#af+1] = Def.Quad{
	Name="Veil",
	InitCommand=function(self)
		self:align(0,0):xy(0, bandTop):zoomto(H.W*0.45, bandHeight)
			:diffuse(H.P1):diffusealpha(0.20):diffuserightedge(color("0,0,0,0"))
	end,
}

af[#af+1] = H.LabelText{Name="Eyebrow", Px=11, Tint=H.Mute, X=H.Pad, Y=bandTop+31}
af[#af+1] = H.DisplayText{Name="Title", Px=52, Tint=H.Ink, X=H.Pad, Y=bandTop+62}
af[#af+1] = H.DisplayText{Name="Artist", Px=24, Tint=H.Mute, X=H.Pad, Y=bandTop+100}

for _, field in ipairs({"Bpm", "Duration", "Pack"}) do
	af[#af+1] = H.LabelText{Name=field.."Label", Px=9, Tint=H.Dim, Y=bandTop+52}
	af[#af+1] = H.DisplayText{Name=field.."Value", Px=28, Tint=H.Ink, Y=bandTop+74}
end

af[#af+1] = H.Rule{Name="Divider", Y=bandBottom-1, Width=H.W, Height=1}

H.AddRefresh(af)
return af
