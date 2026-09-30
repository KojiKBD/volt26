local firstFrame = 0
local lastFrame = 64
local frameDelay = 1 / 30
local sx = SCREEN_WIDTH / 1920
local sy = SCREEN_HEIGHT / 1080

local function artworkPath(song)
	if song and song:HasJacket() then return song:GetJacketPath() end
	if song and song:HasBanner() then return song:GetBannerPath() end
	return GetFallbackBanner()
end

local function cropToSquare(sprite, size)
	local width = math.max(1, sprite:GetWidth())
	local height = math.max(1, sprite:GetHeight())
	if width > height then
		local crop = (1 - height / width) / 2
		sprite:cropleft(crop):cropright(crop)
	else
		local crop = (1 - width / height) / 2
		sprite:croptop(crop):cropbottom(crop)
	end
	sprite:zoom(size / math.min(width, height))
end

local function chartInfo()
	local player = GAMESTATE:GetMasterPlayerNumber()
	local steps = player and GAMESTATE:GetCurrentSteps(player)
	if not steps then return "" end
	return ToEnumShortString(steps:GetDifficulty()):upper() .. "  /  " .. tostring(steps:GetMeter())
end

local function textAt(value, x, y, zoom, width)
	return LoadFont("Common Normal")..{
		InitCommand=function(self)
			self:xy(x * sx, y * sy):horizalign("left")
				:zoom(zoom * sy):maxwidth(width * sx):diffuse(color("#140505"))
			self:settext(value)
		end,
	}
end

local function framePath(index)
	return THEME:GetPathG("", "VOLT26/evaluation/eval_" .. string.format("%05d", index) .. ".png")
end

local animation = Def.Sprite{
	Texture=framePath(firstFrame),
	InitCommand=function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
	OnCommand=function(self)
		self:sleep(frameDelay):queuecommand("Frame" .. (firstFrame + 1))
	end,
}

for index = firstFrame + 1, lastFrame do
	animation["Frame" .. index .. "Command"] = function(self)
		self:Load(framePath(index))
		self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
		if index < lastFrame then
			self:sleep(frameDelay):queuecommand("Frame" .. (index + 1))
		end
	end
end

local course = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or nil
local song = not course and GAMESTATE:GetCurrentSong() or nil
local title = song and song:GetDisplayMainTitle() or course and course:GetDisplayFullTitle() or ""
local artist = song and song:GetDisplayArtist() or ""
local info = course and "COURSE" or chartInfo()
local bpm = song and StringifyDisplayBPMs() or ""

local songInfo = Def.ActorFrame{
	InitCommand=function(self)
		self:xy(SCREEN_LEFT + 518 * sx, SCREEN_TOP + 530 * sy):rotationz(-10):visible(false)
	end,
	OnCommand=function(self)
		self:sleep((lastFrame + 1) * frameDelay):queuecommand("Reveal")
	end,
	RevealCommand=function(self) self:visible(true) end,
	Def.Quad{
		InitCommand=function(self)
			self:zoomto(362 * sx, 362 * sy):diffuse(color("#140505"))
		end,
	},
	Def.Sprite{
		Texture=artworkPath(song),
		InitCommand=function(self)
			cropToSquare(self, 350 * sy)
		end,
	},
	textAt(title, -130, 215, 1.12, 235),
	textAt(artist, -130, 258, 0.76, 290),
	textAt(info, -130, 307, 0.7, 295),
	textAt(bpm ~= "" and (bpm .. " BPM") or "", 105, 225, 0.72, 115),
}

return Def.ActorFrame{
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/evaluation/bg_ss.png"),
		InitCommand=function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse({0.4, 0.4, 0.4, 1})
		end,
	},
	animation,
	songInfo,
}
