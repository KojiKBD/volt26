local W, H = 854, 480
local scale = math.min(_screen.w / W, _screen.h / H)
local left = _screen.cx - W * scale / 2
local top = _screen.cy - H * scale / 2
local players = GAMESTATE:GetHumanPlayers()

local FONT = "Helvetica Normal"
local FONT_BOLD = "Helvetica Bold"
local FONT_ZOOM = 116 / 28
local FONT_BOLD_ZOOM = 116 / 29
local WHITE = color("#f1eded")
local MUTED = color("#989092")
local SURFACE = color("#151515")
local LINE = color("#413b3c")
local P1 = color("#ff4b4b")
local P2 = color("#4388a6")
local timerTotal = tonumber(THEME:GetMetric("ScreenGameOver", "TimerSeconds")) or 23

local function normalZoom(value)
	return value * FONT_ZOOM
end

local function boldZoom(value)
	return value * FONT_BOLD_ZOOM
end

local function cleanLabel(value)
	return tostring(value or ""):gsub("[\r\n]+", " "):gsub("%s+", " ")
end

local function hasNonASCII(value)
	return tostring(value or ""):find("[\128-\255]") ~= nil
end

local function accentFor(player)
	return player == PLAYER_1 and P1 or P2
end

local function durationText(seconds)
	local duration = VOLT26.Session.FormatDuration(seconds)
	if duration.hours > 0 then
		return string.format("%d:%02d:%02d", duration.hours, duration.minutes, duration.seconds)
	end
	return string.format("%02d:%02d", duration.minutes, duration.seconds)
end

local function playerName(player, profile)
	if profile and profile.display_name and profile.display_name ~= "" then
		return profile.display_name
	end
	return THEME:GetString("ScreenSelectProfile", "GuestProfile")
end

local function centerCrop(sprite, width, height)
	sprite:cropleft(0):cropright(0):croptop(0):cropbottom(0):zoom(1):align(0.5, 0.5)
	local sourceWidth = math.max(1, sprite:GetWidth())
	local sourceHeight = math.max(1, sprite:GetHeight())
	local sourceAspect = sourceWidth / sourceHeight
	local targetAspect = width / height
	if sourceAspect > targetAspect then
		local crop = (1 - targetAspect / sourceAspect) / 2
		sprite:cropleft(crop):cropright(crop):zoom(height / sourceHeight)
	else
		local crop = (1 - sourceAspect / targetAspect) / 2
		sprite:croptop(crop):cropbottom(crop):zoom(width / sourceWidth)
	end
end

local function localizedName(name, width)
	local useCommon = hasNonASCII(name)
	return Def.ActorFrame{
		LoadFont(FONT_BOLD)..{
			Text=name,
			InitCommand=function(self)
				self:halign(0):visible(not useCommon):diffuse(WHITE)
					:zoom(boldZoom(0.074)):maxwidth(width / boldZoom(0.074))
			end,
		},
		LoadFont("Common Bold")..{
			Text=name,
			InitCommand=function(self)
				self:halign(0):visible(useCommon):diffuse(WHITE)
					:zoom(0.48):maxwidth(width / 0.48)
			end,
		},
	}
end

local function statCell(x, y, width, label, value)
	return Def.ActorFrame{
		InitCommand=function(self) self:xy(x, y) end,
		LoadFont(FONT_BOLD)..{
			Text=cleanLabel(label):upper(),
			InitCommand=function(self)
				self:halign(0):valign(0):diffuse(MUTED):zoom(boldZoom(0.030))
					:maxwidth(width / boldZoom(0.030))
			end,
		},
		LoadFont(FONT_BOLD)..{
			Text=tostring(value == nil and "--" or value),
			InitCommand=function(self)
				self:halign(0):valign(0):y(15):diffuse(WHITE):zoom(boldZoom(0.076))
					:maxwidth(width / boldZoom(0.076))
			end,
		},
	}
end

local function avatar(player, x, y, size, accent)
	local path = GetPlayerAvatarPath(player)
	local frame = Def.ActorFrame{
		InitCommand=function(self) self:xy(x, y) end,
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(size + 4, size + 4):diffuse(LINE)
			end,
		},
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(size, size):diffuse(color("#101010"))
			end,
		},
	}
	if path then
		frame[#frame+1] = Def.Sprite{
			Texture=path,
			InitCommand=function(self) centerCrop(self, size, size) end,
		}
	else
		frame[#frame+1] = LoadFont(FONT_BOLD)..{
			Text=ToEnumShortString(player),
			InitCommand=function(self)
				self:diffuse(accent):zoom(boldZoom(0.080)):maxwidth((size - 12) / boldZoom(0.080))
			end,
		}
	end
	return frame
end

local function playerCard(player, x, y, width, height, delay, direction)
	local accent = accentFor(player)
	local session = VOLT26.Session.GetSummary(player)
	local profile = VOLT26.Session.GetProfileSummary(player)
	local name = playerName(player, profile)
	local padding = 24
	local avatarSize = #players == 1 and 92 or 76
	local contentX = padding + avatarSize + 22
	local statWidth = (width - padding * 2 - 18) / 3
	local lowerWidth = (width - padding * 2 - 12) / 2
	local card = Def.ActorFrame{
		Name="GameOverCard"..ToEnumShortString(player),
		InitCommand=function(self)
			self:xy(x + direction * 36, y):diffusealpha(0)
		end,
		OnCommand=function(self)
			self:sleep(delay):decelerate(0.32):x(x):diffusealpha(1)
		end,
		OffCommand=function(self)
			self:accelerate(0.18):addx(direction * 24):diffusealpha(0)
		end,
		Def.Quad{
			InitCommand=function(self)
				self:align(0, 0):zoomto(width, height):diffuse(SURFACE):diffusealpha(0.94)
			end,
		},
		Def.Quad{
			InitCommand=function(self)
				self:align(0, 0):zoomto(5, height):diffuse(accent)
			end,
		},
		LoadFont(FONT_BOLD)..{
			Text=ToEnumShortString(player),
			InitCommand=function(self)
				self:xy(padding, 24):halign(0):diffuse(accent):zoom(boldZoom(0.040))
			end,
		},
		avatar(player, padding + avatarSize / 2, 82, avatarSize, accent),
		Def.ActorFrame{
			InitCommand=function(self) self:xy(contentX, 54) end,
			localizedName(name, width - contentX - padding),
			LoadFont(FONT)..{
				Text=profile and "VOLT26" or cleanLabel(THEME:GetString("ScreenSelectProfile", "GuestProfile")):upper(),
				InitCommand=function(self)
					self:xy(0, 23):halign(0):diffuse(MUTED):zoom(normalZoom(0.032))
				end,
			},
		},
		Def.Quad{
			InitCommand=function(self)
				self:align(0, 0.5):xy(padding, 143):zoomto(width - padding * 2, 1)
					:diffuse(LINE)
			end,
		},
		statCell(padding, 166, statWidth, ScreenString("SongsPlayedThisGame"), session.songs_played),
		statCell(padding + statWidth + 9, 166, statWidth, ScreenString("NotesHitThisGame"), session.tap_hits),
		statCell(padding + (statWidth + 9) * 2, 166, statWidth, ScreenString("TimeSpentThisGame"), durationText(session.active_seconds)),
		statCell(padding, 238, lowerWidth, ScreenString("TotalSongsPlayed"), profile and profile.total_songs or nil),
		statCell(padding + lowerWidth + 12, 238, lowerWidth, ScreenString("CaloriesBurned"), profile and profile.calories or nil),
	}
	return card
end

local layout = Def.ActorFrame{
	Name="VOLT26GameOver",
	InitCommand=function(self) self:xy(left, top):zoom(scale) end,
	Def.ActorFrame{
		InitCommand=function(self) self:xy(W / 2, 36):addy(-14):diffusealpha(0) end,
		OnCommand=function(self) self:decelerate(0.30):addy(14):diffusealpha(1) end,
		OffCommand=function(self) self:accelerate(0.16):addy(-10):diffusealpha(0) end,
		LoadFont(FONT_BOLD)..{
			Text="GAME OVER",
			InitCommand=function(self) self:diffuse(WHITE):zoom(boldZoom(0.115)) end,
		},
		LoadFont(FONT)..{
			Text="SESSION SUMMARY",
			InitCommand=function(self) self:y(26):diffuse(MUTED):zoom(normalZoom(0.034)) end,
		},
		Def.Quad{
			InitCommand=function(self) self:y(44):zoomto(0, 2):diffuse(P1) end,
			OnCommand=function(self) self:sleep(0.12):decelerate(0.30):zoomto(112, 2) end,
		},
	},
}

if #players == 1 then
	layout[#layout+1] = playerCard(players[1], 147, 103, 560, 310, 0.08, players[1] == PLAYER_1 and -1 or 1)
else
	layout[#layout+1] = playerCard(PLAYER_1, 45, 103, 374, 310, 0.08, -1)
	layout[#layout+1] = playerCard(PLAYER_2, 435, 103, 374, 310, 0.13, 1)
end

layout[#layout+1] = Def.ActorFrame{
	Name="GameOverCountdown",
	InitCommand=function(self) self:xy(W / 2, 447):diffusealpha(0) end,
	OnCommand=function(self)
		self:sleep(0.22):decelerate(0.22):diffusealpha(1)
		self:SetUpdateFunction(function(frame)
			local screen = SCREENMAN:GetTopScreen()
			local timer = screen and screen:GetChild("Timer")
			local seconds = timer and math.max(0, timer:GetSeconds()) or timerTotal
			local display = frame:GetChild("Seconds")
			local remaining = frame:GetChild("Remaining")
			if display then display:settext(string.format("%02d", math.ceil(seconds))) end
			if remaining then remaining:zoomtowidth(240 * math.min(1, seconds / timerTotal)) end
		end)
	end,
	OffCommand=function(self) self:stoptweening():linear(0.12):diffusealpha(0) end,
	Def.Quad{
		InitCommand=function(self)
			self:align(0, 0.5):x(-120):zoomto(240, 3):diffuse(LINE)
		end,
	},
	Def.Quad{
		Name="Remaining",
		InitCommand=function(self)
			self:align(0, 0.5):x(-120):zoomto(240, 3):diffuse(P1)
		end,
	},
	LoadFont("_Combo Fonts/VOLT26/VOLT26")..{
		Name="Seconds",
		Text=string.format("%02d", timerTotal),
		InitCommand=function(self) self:y(-13):diffuse(WHITE):zoom(0.20) end,
	},
	LoadFont(FONT)..{
		Text="NEXT SCREEN",
		InitCommand=function(self) self:y(12):diffuse(MUTED):zoom(normalZoom(0.027)) end,
	},
}

return layout
