-- Game over: each player's session in the dress of the session summary
-- ("gameover" artboard; shared pieces in "_volt26 gameover kit.lua").  The
-- player's card carries their name in cutout lettering, their avatar in the
-- jacket frame and the best grade of the session; its score plate and two
-- more beside it hold the figures (songs and notes this session, time
-- played, the profile's total songs and today's calories).  Player 1 fills
-- the upper half, player 2 the lower one mirrored; one player sits in the
-- middle.  The countdown to the next screen runs along the band.
local G = LoadActor(THEME:GetPathB("", "_volt26 gameover kit.lua"))
local K = G.K
local players = G.Players()
local solo = #players == 1
local timerTotal = tonumber(THEME:GetMetric("ScreenGameOver", "TimerSeconds")) or 23

local function clock(seconds)
	local d = VOLT26.Session.FormatDuration(seconds)
	if d.hours > 0 then return ("%d:%02d:%02d"):format(d.hours, d.minutes, d.seconds) end
	return ("%d:%02d"):format(d.minutes, d.seconds)
end

local function playerName(player, profile)
	if profile and profile.display_name and profile.display_name ~= "" then return profile.display_name end
	return ToEnumShortString(player)
end

local function label(key) return ScreenString(key):upper() end

-- The two plates beside the card, on player 1's artboard.
local PLATES = { { X = 1000, Y = 300, Zoom = 1.25 }, { X = 1530, Y = 300, Zoom = 1.25 } }

local function half(player, delay)
	local a = G.Anchor(player, solo)
	local m = a.M
	local session = VOLT26.Session.GetSummary(player)
	local profile = VOLT26.Session.GetProfileSummary(player)

	local af = Def.ActorFrame{
		Name = "Half" .. ToEnumShortString(player),
		InitCommand = function(self) self:xy(a.X, a.Y) end,
		OnCommand = function(self)
			local card = self:GetChild("Card")
			G.SetSlot(card:GetChild("Name"), playerName(player, profile))
			G.SetTitle(card, label("Session"))
			G.SetJacket(card, GetPlayerAvatarPath(player), ToEnumShortString(player))
			G.SetGrade(card:GetChild("Grade"), G.BestGrade(player))

			local songs, notes = card:GetChild("Itg"), card:GetChild("Ex")
			G.SetLine(songs, tostring(session.songs_played or 0), "")
			G.SetLine(notes, tostring(session.tap_hits or 0), "")

			local time, total = G.PlateLines(self:GetChild("Plate1"))
			G.SetLine(time, clock(session.active_seconds or 0), "")
			G.SetLine(total, profile and tostring(profile.total_songs or K.Dash) or K.Dash, "")

			local kcal, rest, _, restLine = G.PlateLines(self:GetChild("Plate2"))
			G.SetLine(kcal, profile and profile.calories and tostring(profile.calories) or K.Dash, "")
			rest:visible(false)
			restLine:visible(false)

			G.Arrive(self, m, delay)
		end,
		OffCommand = function(self) G.Leave(self, m) end,
	}
	-- The card's plate: songs and notes this session.
	local card = G.Card("Card", m, { Rank = false, TagA = label("StatSongs"), TagB = label("StatNotes"), TagCap = 12 })
	af[#af+1] = card
	af[#af+1] = G.Plate("Plate1", m, PLATES[1].X, PLATES[1].Y, PLATES[1].Zoom, label("StatTime"), label("StatTotal"), 12)
	af[#af+1] = G.Plate("Plate2", m, PLATES[2].X, PLATES[2].Y, PLATES[2].Zoom, label("StatCalories"), "", 12)
	return af
end

local root = G.Root{ Name = "VOLT26GameOver" }
for i, player in ipairs(players) do root[#root+1] = half(player, 0.08 + (i - 1) * 0.08) end
root[#root+1] = G.Title("GAME OVER", solo)

-- The countdown: the seconds and a bar draining along the band's right end.
local COUNT = { X = 1700, Y = solo and 150 or G.Art.Band.Y, W = 300 }
root[#root+1] = Def.ActorFrame{
	Name = "GameOverCountdown",
	InitCommand = function(self) self:xy(COUNT.X, COUNT.Y):diffusealpha(0) end,
	OnCommand = function(self)
		self:sleep(0.3):linear(0.2):diffusealpha(1)
		self:SetUpdateFunction(function(frame)
			local screen = SCREENMAN:GetTopScreen()
			local timer = screen and screen:GetChild("Timer")
			local seconds = timer and math.max(0, timer:GetSeconds()) or timerTotal
			frame:GetChild("Seconds"):settext(("%02d"):format(math.ceil(seconds)))
			frame:GetChild("Remaining"):zoomtowidth(COUNT.W * math.min(1, seconds / timerTotal))
		end)
	end,
	OffCommand = function(self)
		self:SetUpdateFunction(nil)
		self:stoptweening():linear(0.12):diffusealpha(0)
	end,
	Def.Quad{ InitCommand = function(self) self:align(0, 0.5):xy(-COUNT.W / 2, 26):zoomto(COUNT.W, 4):diffuse(G.Black):diffusealpha(0.6) end },
	Def.Quad{ Name = "Remaining", InitCommand = function(self) self:align(0, 0.5):xy(-COUNT.W / 2, 26):zoomto(COUNT.W, 4):diffuse(G.Pink) end },
	LoadFont(G.Font.Score)..{
		Name = "Seconds",
		InitCommand = function(self) self:valign(1):y(16):zoom(40 / (68 / 96) / 96):diffuse(G.White) end,
	},
}

return root
