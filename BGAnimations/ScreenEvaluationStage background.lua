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

-- The card in the last sequence frame is drawn in perspective, so it is not a
-- plain rotated rectangle.  Its corners are measured on eval_00064.png (1920x1080)
-- and content is laid out in flat card pixels, then mapped onto that quad: each
-- actor takes the position and the tilt of the card at its own height.
local card = {
	topLeft = {259, 367}, topRight = {692, 281},
	bottomLeft = {397, 976}, bottomRight = {813, 860},
	width = 437, height = 608,
}

local function between(a, b, t)
	return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
end

local function placeOnCard(actor, x, y)
	local u, v = x / card.width, y / card.height
	local leftX, leftY = between(card.topLeft, card.bottomLeft, v)
	local rightX, rightY = between(card.topRight, card.bottomRight, v)
	local dx, dy = (rightX - leftX) * sx, (rightY - leftY) * sy
	actor:xy(leftX * sx + dx * u, leftY * sy + dy * u)
	actor:rotationz(math.deg(math.atan2(dy, dx)))
end

-- Flat card layout, in card pixels from its top-left corner.
local layout = {
	margin = 37,
	artSize = 350, artBorder = 6, artCenterY = 218,
	titleY = 447, titleSize = 40, titleHeight = 84,
	artistY = 499, artistSize = 25,
	infoY = 541, infoSize = 22,
	bpmWidth = 135, columnGap = 16,
}
layout.contentWidth = card.width - layout.margin * 2

local function textAt(value, x, y, size, width, align)
	return LoadFont(VOLT26.Type.Label)..{
		InitCommand=function(self)
			placeOnCard(self, x, y)
			self:horizalign(align or "left"):diffuse(color("#140505"))
			VOLT26.Type.SetLabel(self, value:upper(), size * sy, width * sx)
		end,
	}
end

local function framePath(index)
	return THEME:GetPathG("", "VOLT26/evaluation/eval_" .. string.format("%05d", index) .. ".png")
end

local animation = Def.Sprite{
	Name="Animation",
	Texture=framePath(firstFrame),
	InitCommand=function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
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

local outerArt = layout.artSize + layout.artBorder * 2
local rightEdge = card.width - layout.margin

local songInfo = Def.ActorFrame{
	InitCommand=function(self) self:visible(false) end,
	OnCommand=function(self)
		self:sleep((lastFrame + 1) * frameDelay):queuecommand("Reveal")
	end,
	RevealCommand=function(self)
		self:visible(true)
		-- The inherited results (overlay) and the cutout title wait for this.
		MESSAGEMAN:Broadcast("VOLT26EvaluationSequenceFinished")
	end,
	Def.Quad{
		InitCommand=function(self)
			placeOnCard(self, card.width / 2, layout.artCenterY)
			self:zoomto(outerArt * sx, outerArt * sy):diffuse(color("#140505"))
		end,
	},
	Def.Sprite{
		Texture=artworkPath(song),
		InitCommand=function(self)
			placeOnCard(self, card.width / 2, layout.artCenterY)
			cropToSquare(self, layout.artSize * sy)
		end,
	},
	textAt(artist, layout.margin, layout.artistY, layout.artistSize,
		layout.contentWidth - layout.bpmWidth - layout.columnGap),
	textAt(bpm ~= "" and (bpm .. " BPM") or "", rightEdge, layout.artistY, layout.infoSize,
		layout.bpmWidth, "right"),
	textAt(info, layout.margin, layout.infoY, layout.infoSize, layout.contentWidth),
}

-- The title is set in cutout lettering when the cutout faces can draw it and it
-- is short enough to stay legible across the card; otherwise it keeps the label
-- face.  The cutout slot sits outside songInfo so it can render while the
-- sequence plays (a hidden actor is not drawn), and is held until the reveal.
local titleMaxChars = 28
local titleChars = select(2, title:gsub("[^\128-\191]", ""))
local titleInCutout = titleChars > 0 and titleChars <= titleMaxChars
	and VOLT26.Cutout.Layout(title) ~= nil

local titleCutout = Def.ActorFrame{}
if titleInCutout then
	titleCutout = VOLT26.Cutout.CreateSlot{
		maxW = layout.contentWidth * sx, maxH = layout.titleHeight * sy,
		halign = 0, valign = 0.5, maxChars = titleMaxChars, held = true,
		opts = { base = layout.titleSize * sy * 1.15, tiltDeg = 0 },
		onInit = function(slot) placeOnCard(slot, layout.margin, layout.titleY) end,
	}..{
		OnCommand=function(self) self:playcommand("CutoutSet", {text = title}) end,
		VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
			self:playcommand("CutoutHold", {held = false})
		end,
	}
else
	songInfo[#songInfo+1] = textAt(title, layout.margin, layout.titleY, layout.titleSize, layout.contentWidth)
end

return Def.ActorFrame{
	OnCommand=function(self)
		self:GetChild("SequenceAudio"):play()
		self:GetChild("Animation"):sleep(frameDelay):queuecommand("Frame" .. (firstFrame + 1))
	end,
	OffCommand=function(self)
		self:GetChild("SequenceAudio"):stop()
	end,
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/evaluation/bg_ss.png"),
		InitCommand=function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse({0.4, 0.4, 0.4, 1})
		end,
	},
	animation,
	Def.Sound{
		Name="SequenceAudio",
		File=THEME:GetPathS("", "VOLT26/evaluation/result_sequence.ogg"),
	},
	songInfo,
	titleCutout,
}
