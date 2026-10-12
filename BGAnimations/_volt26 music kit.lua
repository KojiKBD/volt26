-- Shared presentation kit for the two music selection screens
-- (ScreenVOLT26SelectPack and ScreenSelectMusic / ScreenSelectCourse).
--
-- Both screens are laid out in a virtual 1920x1080 design space and scaled to
-- the theme's real resolution, so every figure in their files is a design
-- pixel.  The kit holds the palette, the text and rule factories, artwork
-- fitting and the small formatting helpers both screens share.  It owns no
-- behaviour: pack data comes from VOLT26.PackSelection and song state from the
-- engine.
--
-- Usage: local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))

local K = { W = 1920, H = 1080 }

K.Scale = math.min(_screen.w / K.W, _screen.h / K.H)
K.Left = _screen.cx - K.W * K.Scale / 2
K.Top = _screen.cy - K.H * K.Scale / 2

-- Palette (the same near-black ground and red/blue player accents as the rest
-- of VOLT26).
K.Bg     = color("#0a0a0c")
K.Panel  = color("#141417")
K.Panel2 = color("#1b1b20")
K.Line   = color("#2c2c33")
K.Ink    = color("#f2f0ec")
K.Mute   = color("#8a8a94")
K.Dim    = color("#5a5a64")
K.Accent = color("#e03a2f")
K.P1     = color("#e03a2f")
K.P2     = color("#2f7de0")
K.Dash   = "--"

function K.PlayerColor(player)
	return player == PLAYER_2 and K.P2 or K.P1
end

-- Difficulty colours and the order charts are listed in.
local difficultyColors = {
	Difficulty_Beginner  = color("#3fc4d6"),
	Difficulty_Easy      = color("#55c24b"),
	Difficulty_Medium    = color("#e8c33a"),
	Difficulty_Hard      = color("#e03a2f"),
	Difficulty_Challenge = color("#a24fd8"),
	Difficulty_Edit      = color("#9a9aa6"),
}
local difficultyOrder = {
	Difficulty_Beginner=1, Difficulty_Easy=2, Difficulty_Medium=3,
	Difficulty_Hard=4, Difficulty_Challenge=5, Difficulty_Edit=6,
}

function K.DifficultyColor(difficulty)
	return difficultyColors[difficulty] or K.Mute
end

function K.DifficultyOrder(difficulty)
	return difficultyOrder[difficulty] or 7
end

-- Strings live in the [VOLT26MusicSelect] section of Languages/*.ini.
function K.String(key)
	return THEME:GetString("VOLT26MusicSelect", key)
end

function K.DifficultyName(difficulty)
	local short = tostring(difficulty or ""):gsub("^Difficulty_", "")
	if difficultyOrder["Difficulty_" .. short] == nil then return short:upper() end
	return K.String("Difficulty" .. short)
end

-- Typography: VOLT26.Type owns the two faces and the px-to-zoom metrics.
K.Display = VOLT26.Type.Display
K.Label = VOLT26.Type.Label
K.SetLabel = VOLT26.Type.SetLabel
K.SetDisplay = VOLT26.Type.SetDisplay

-- Text factory.  t = {Name, Role="Label"|"Display", Px, Tint, Align, VAlign,
-- X, Y, Text, Width}.  The text is vertically centred on Y unless VAlign says
-- otherwise.
function K.Text(t)
	local display = t.Role == "Display"
	local zoomFor = display and VOLT26.Type.DisplayZoom or VOLT26.Type.LabelZoom
	return Def.BitmapText{
		Name = t.Name,
		Font = display and K.Display or K.Label,
		InitCommand = function(self)
			local zoom = zoomFor(t.Px or 14)
			self:xy(t.X or 0, t.Y or 0)
				:horizalign(t.Align or left):vertalign(t.VAlign or middle)
				:shadowlength(0):zoom(zoom):diffuse(t.Tint or (display and K.Ink or K.Mute))
			if t.Width then self:maxwidth(t.Width / zoom) end
			if t.Text then self:settext(t.Text) end
		end,
	}
end

-- Filled rectangle drawn from its top-left corner unless AlignX/AlignY say
-- otherwise.  t = {Name, X, Y, Width, Height, Tint, Alpha, AlignX, AlignY}.
function K.Rule(t)
	return Def.Quad{
		Name = t.Name,
		InitCommand = function(self)
			self:align(t.AlignX or 0, t.AlignY or 0):xy(t.X or 0, t.Y or 0)
				:zoomto(t.Width or 1, t.Height or 1)
				:diffuse(t.Tint or K.Line):diffusealpha(t.Alpha or 1)
		end,
	}
end

-- A one-pixel-wide outline as four quads, centred on the frame's origin.
function K.Outline(t)
	local w, h, s = t.Width, t.Height, t.Stroke or 2
	local frame = Def.ActorFrame{ Name = t.Name }
	frame[#frame+1] = K.Rule{ X=-w/2, Y=-h/2, Width=w, Height=s, Tint=t.Tint }
	frame[#frame+1] = K.Rule{ X=-w/2, Y=h/2-s, Width=w, Height=s, Tint=t.Tint }
	frame[#frame+1] = K.Rule{ X=-w/2, Y=-h/2, Width=s, Height=h, Tint=t.Tint }
	frame[#frame+1] = K.Rule{ X=w/2-s, Y=-h/2, Width=s, Height=h, Tint=t.Tint }
	return frame
end

-- Artwork -------------------------------------------------------------------

local movieExtensions = {
	avi=true, f4v=true, flv=true, mkv=true, mp4=true, mpeg=true,
	mpg=true, mov=true, ogv=true, ogg=true, webm=true, wmv=true,
}

function K.IsMovie(path)
	return type(path) == "string"
		and movieExtensions[(path:match("%.([^.]+)$") or ""):lower()] == true
end

-- Loads a still image into a sprite and answers whether it worked.  With a
-- cache directory ("Banner" or "Jacket", see [Common] ImageCache) the small
-- cached copy is used; without one the file itself is loaded.  Movies are
-- refused: decoding one behind a thumbnail costs more than the low-end path
-- can spare.
function K.LoadStill(sprite, path, cacheDir)
	if type(path) ~= "string" or path == "" or K.IsMovie(path) then return false end
	return pcall(function()
		if cacheDir then
			sprite:LoadFromCached(cacheDir, path)
		else
			sprite:Load(path)
		end
		sprite:animate(false)
	end)
end

local function resetCrop(sprite)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):zoom(1)
end

local function sourceSize(sprite)
	return math.max(1, sprite:GetWidth()), math.max(1, sprite:GetHeight())
end

-- Fills a w x h box centred on the sprite's position, cropping whichever
-- dimension overflows.
function K.Cover(sprite, w, h)
	resetCrop(sprite)
	local sw, sh = sourceSize(sprite)
	if sw / sh > w / h then
		local crop = (1 - (w / h) / (sw / sh)) / 2
		sprite:cropleft(crop):cropright(crop):zoom(h / sh)
	else
		local crop = (1 - (sw / sh) / (w / h)) / 2
		sprite:croptop(crop):cropbottom(crop):zoom(w / sw)
	end
end

-- Fits the whole image inside a w x h box centred on the sprite's position.
function K.Contain(sprite, w, h)
	resetCrop(sprite)
	local sw, sh = sourceSize(sprite)
	sprite:zoom(math.min(w / sw, h / sh))
end

-- Song artwork: the jacket when the song has a still one, otherwise its
-- banner.  Answers path, cache directory.
function K.SongArt(song)
	if not song then return nil end
	local ok, path = pcall(function() return song:HasJacket() and song:GetJacketPath() or nil end)
	if ok and type(path) == "string" and path ~= "" and not K.IsMovie(path) then return path, "Jacket" end
	ok, path = pcall(function() return song:HasBanner() and song:GetBannerPath() or nil end)
	if ok and type(path) == "string" and path ~= "" and not K.IsMovie(path) then return path, "Banner" end
	return nil
end

function K.CourseArt(course)
	if not course then return nil end
	local ok, path = pcall(function() return course:HasBanner() and course:GetBannerPath() or nil end)
	if ok and type(path) == "string" and path ~= "" and not K.IsMovie(path) then return path, "Banner" end
	return nil
end

-- Formatting ----------------------------------------------------------------

function K.Clock(seconds)
	seconds = tonumber(seconds)
	if not seconds or seconds <= 0 then return K.Dash end
	seconds = math.floor(seconds + 0.5)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local rest = seconds % 60
	if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, rest) end
	return string.format("%d:%02d", minutes, rest)
end

-- Up to two capital letters standing in for missing pack artwork.
function K.Initials(name)
	local letters = {}
	for word in tostring(name or ""):gmatch("[%w]+") do
		letters[#letters+1] = word:sub(1, 1):upper()
		if #letters == 2 then break end
	end
	if #letters == 0 then return "?" end
	return table.concat(letters)
end

-- Shared screen furniture ---------------------------------------------------
--
-- Both screens wear the same header and footer bands, in the same places, so
-- that moving between them only changes the words in them (the song wheel no
-- longer draws them; the pack step still may).  The chosen pack's jacket
-- shrinks into the song wheel's jacket frame and grows back out of it; K.Badge
-- is that spot (the frame of the song select mockup, see
-- ScreenSelectMusic overlay/SongWheel/Jacket.lua), and K.TileSize the
-- jacket's full carousel size.
K.HeaderHeight = 96
K.FooterTop = 1004
K.TileSize = 560
K.Badge = { X = 1678, Y = 193, Size = 284 }
-- Seconds of the shared hand-off motion.  The screens' out and cancel
-- transitions hold for K.HandoffHold so the motion finishes before the next
-- screen replaces this one.
K.HandoffSeconds = 0.22
K.HandoffHold = 0.26

function K.ModeText()
	local style = GAMESTATE:GetCurrentStyle()
	local name = style and style:GetName() or ""
	local parts = { name:upper() }
	-- The versus style already says it; the others say whether one or two play.
	if name ~= "versus" then
		parts[#parts+1] = #GAMESTATE:GetHumanPlayers() > 1 and K.String("Versus") or K.String("Solo")
	end
	if GAMESTATE:IsCourseMode() then parts[#parts+1] = K.String("Marathon") end
	return table.concat(parts, "   /   ")
end

-- Header and footer bands with the screen title, the play mode under it and
-- the button hints.  t = {Title, Hints}.  The words fade in on "ChromeIn" and
-- out on "ChromeOut"; the bands themselves never move.
function K.Chrome(t)
	local function words(def)
		def.ChromeInCommand = function(self)
			self:stoptweening():diffusealpha(0):sleep(0.08):linear(0.18):diffusealpha(1)
		end
		def.ChromeOutCommand = function(self)
			self:stoptweening():linear(0.12):diffusealpha(0)
		end
		return def
	end
	local af = Def.ActorFrame{ Name="Chrome" }
	af[#af+1] = K.Rule{ Name="HeaderBand", X=-K.W, Width=K.W*3, Height=K.HeaderHeight, Tint=K.Bg, Alpha=0.94 }
	af[#af+1] = K.Rule{ Name="HeaderDivider", Y=K.HeaderHeight-1, Width=K.W, Height=1 }
	af[#af+1] = K.Rule{ Name="Mark", X=40, Y=26, Width=6, Height=44, Tint=K.Accent }
	af[#af+1] = words(K.Text{ Name="Title", Px=30, Tint=K.Ink, X=62, Y=38, Text=t.Title })
	local mode = K.Text{ Name="Mode", Px=12, Tint=K.Dim, X=62, Y=72, Text=K.ModeText() }
	mode.PlayerJoinedMessageCommand = function(self) K.SetLabel(self, K.ModeText(), 12) end
	mode.PlayerUnjoinedMessageCommand = mode.PlayerJoinedMessageCommand
	af[#af+1] = mode
	af[#af+1] = K.Rule{ Name="FooterBand", X=-K.W, Y=K.FooterTop, Width=K.W*3, Height=K.H, Tint=K.Bg, Alpha=0.94 }
	af[#af+1] = K.Rule{ Name="FooterDivider", Y=K.FooterTop, Width=K.W, Height=1 }
	af[#af+1] = words(K.Text{ Name="Hints", Px=13, Tint=K.Mute, X=40, Y=K.FooterTop+38, Text=t.Hints })
	return af
end

function K.Wheel()
	local screen = SCREENMAN:GetTopScreen()
	return screen and screen.GetMusicWheel and screen:GetMusicWheel() or nil
end

return K
