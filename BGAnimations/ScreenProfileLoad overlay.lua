-- The profile-load transition between the play-mode choice (ITG / Marathon,
-- ITG / FA+) and music selection: the "victory" banner that used to open the
-- stage evaluation (until fa9e0cb0), a torn red band with the emblem tearing
-- open across a black screen.  When it has played, the screen continues to
-- music selection.
--
-- Enhanced mode plays the frame sequence (Graphics/VOLT26/Transition/victory,
-- 1280x720 frames at 24 per second).  Performance mode slams in one still
-- frame of it instead of streaming the sequence from disk.

local FRAMES = { First = 7, Last = 44 }      -- the banner has settled by 44
local FPS = 24
local HOLD = 0.12                            -- on the last frame before leaving
local STILL = 30                             -- Performance mode's one frame

local function framePath(n)
	return THEME:GetPathG("", ("VOLT26/Transition/victory/victory_%05d.png"):format(n))
end

local function continue()
	local screen = SCREENMAN:GetTopScreen()
	if screen and screen.Continue then screen:Continue() end
end

local af = Def.ActorFrame{
	InitCommand=function(self) self:Center():draworder(101) end,
	OffCommand=function(self)
		-- By the time this screen's OffCommand is called, player mods should
		-- already have been read from file and applied to the SL[pn]
		-- ActiveModifiers table, so it is now safe to call ApplyMods() on any
		-- human players.
		for player in ivalues(GAMESTATE:GetHumanPlayers()) do
			ApplyMods(player)
		end
	end,
	-- Black over whatever the previous screen left.
	Def.Quad{
		InitCommand=function(self) self:zoomto(_screen.w, _screen.h):diffuse(Color.Black) end,
	},
}

if VOLT26.Performance.IsEnabled() then
	af[#af+1] = Def.Sprite{
		Texture=framePath(STILL),
		InitCommand=function(self) self:zoomto(_screen.w, _screen.h):diffusealpha(0) end,
		OnCommand=function(self)
			self:zoom(self:GetZoomX() * 1.35):diffusealpha(1)
				:decelerate(0.14):zoomto(_screen.w, _screen.h)
				:sleep(0.45):accelerate(0.12):diffusealpha(0)
				:queuecommand("Leave")
		end,
		LeaveCommand=function(self) continue() end,
	}
	return af
end

local sequence = Def.Sprite{
	Texture=framePath(FRAMES.First),
	InitCommand=function(self) self:zoomto(_screen.w, _screen.h) end,
	OnCommand=function(self)
		self:sleep(1 / FPS):queuecommand("Frame" .. (FRAMES.First + 1))
	end,
	LeaveCommand=function(self) continue() end,
}
for n = FRAMES.First + 1, FRAMES.Last do
	sequence["Frame" .. n .. "Command"] = function(self)
		self:Load(framePath(n))
		self:zoomto(_screen.w, _screen.h)
		if n < FRAMES.Last then
			self:sleep(1 / FPS):queuecommand("Frame" .. (n + 1))
		else
			-- The banner bursts out and the screen moves on.
			self:sleep(HOLD):accelerate(0.12):zoomto(_screen.w * 1.15, _screen.h * 1.15)
				:diffusealpha(0):queuecommand("Leave")
		end
	end
end
af[#af+1] = sequence

return af
