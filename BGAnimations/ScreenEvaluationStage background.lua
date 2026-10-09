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
	return ToEnumShortString(steps:GetDifficulty()):upper() .. " " .. tostring(steps:GetMeter())
end

local function lengthText(song)
	if not song then return "" end
	local seconds = song:MusicLengthSeconds() / VOLT26.MusicSelection.GetMusicRate()
	seconds = math.floor(seconds + 0.5)
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
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
	tagX = 14, tagY = 14, tagHeight = 38,
	artistY = 420, artistSize = 17,
	titleY = 474, titleSize = 44, titleHeight = 76,
	chipY = 552, chipHeight = 36, chipSize = 19, chipGap = 10,
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

-- A box sized to its text, laid on the card with its left edge at x.  `widths`
-- collects each chip's width in card pixels so a row can be packed.
local function chipOnCard(name, value, fill, ink, height, size, widths)
	return Def.ActorFrame{
		Name=name,
		Def.Quad{ Name="Box", InitCommand=function(self) self:halign(0):diffuse(fill) end },
		LoadFont("Wendy/_wendy small")..{
			InitCommand=function(self)
				self:halign(0):diffuse(ink):settext(value)
				self:zoom(size * sy / math.max(1, self:GetHeight()))
				local width = self:GetZoomedWidth() / sx + height * 0.6
				self:x(height * 0.3 * sx)
				self:GetParent():GetChild("Box"):zoomto(width * sx, height * sy)
				widths[name] = width
			end,
		},
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
	textAt(artist, layout.margin, layout.artistY, layout.artistSize, layout.contentWidth),
}

-- Bottom row of chips: difficulty and meter on black, BPM and length on white.
local chipWidths = {}
local chipSpecs = {}
if info ~= "" then chipSpecs[#chipSpecs+1] = {info, color("#000000"), color("#FFFFFF")} end
if bpm ~= "" then chipSpecs[#chipSpecs+1] = {bpm .. " BPM", color("#FFFFFF"), color("#000000")} end
local length = lengthText(song)
if length ~= "" then chipSpecs[#chipSpecs+1] = {length, color("#FFFFFF"), color("#000000")} end
local chipRow = Def.ActorFrame{
	OnCommand=function(self)
		local x = layout.margin
		for index = 1, #chipSpecs do
			local name = "Chip" .. index
			placeOnCard(self:GetChild(name), x, layout.chipY)
			x = x + (chipWidths[name] or 0) + layout.chipGap
		end
	end,
}
for index, spec in ipairs(chipSpecs) do
	chipRow[#chipRow+1] = chipOnCard("Chip" .. index, spec[1], spec[2], spec[3],
		layout.chipHeight, layout.chipSize, chipWidths)
end
songInfo[#songInfo+1] = chipRow

-- The STAGE CLEAR / STAGE FAILED tag over the card's top-left corner.
local tagWidths = {}
songInfo[#songInfo+1] = Def.ActorFrame{
	OnCommand=function(self)
		placeOnCard(self, layout.tagX, layout.tagY)
		self:addrotationz(-3)
	end,
	chipOnCard("Tag", VOLT26.Evaluation.AllPlayersFailed() and "STAGE FAILED" or "STAGE CLEAR",
		color("#000000"), color("#FFFFFF"), layout.tagHeight, 22, tagWidths),
}

-- The title is set in cutout lettering when the cutout faces can draw it.  A
-- title too long for one legible line is split at the space nearest its middle
-- into two lines; only a title that is still too long per line, or that uses
-- characters the faces lack, keeps the label face.  The cutout slots sit
-- outside songInfo so they can render while the sequence plays (a hidden actor
-- is not drawn), and are held until the reveal.
local lineMaxChars = 32
local singleLineChars = 22

local function charCount(text)
	return select(2, text:gsub("[^\128-\191]", ""))
end

local function titleLines(text)
	if charCount(text) <= singleLineChars then return { text } end
	local middle, best = #text / 2, nil
	for position in text:gmatch("() ") do
		if not best or math.abs(position - middle) < math.abs(best - middle) then best = position end
	end
	if not best then return { text } end
	return { text:sub(1, best - 1), text:sub(best + 1) }
end

local lines = titleLines(title)
local titleInCutout = charCount(title) > 0
for _, line in ipairs(lines) do
	if charCount(line) > lineMaxChars or VOLT26.Cutout.Layout(line) == nil then titleInCutout = false end
end

local titleCutout = Def.ActorFrame{}
if titleInCutout then
	local lineHeight = layout.titleHeight / #lines
	local base = layout.titleSize * (#lines == 1 and 1.15 or 0.7)
	for index, line in ipairs(lines) do
		local y = layout.titleY + (index - (#lines + 1) / 2) * lineHeight
		titleCutout[#titleCutout+1] = VOLT26.Cutout.CreateSlot{
			maxW = layout.contentWidth * sx, maxH = lineHeight * sy,
			halign = 0, valign = 0.5, maxChars = lineMaxChars, held = true,
			opts = { base = base * sy, tiltDeg = 0 },
			onInit = function(slot) placeOnCard(slot, layout.margin, y) end,
		}..{
			OnCommand=function(self) self:playcommand("CutoutSet", {text = line}) end,
			VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
				self:playcommand("CutoutHold", {held = false})
			end,
		}
	end
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
