-- ScreenProfileLoad sits between the play-mode choice (ITG / Marathon,
-- ITG / FA+) and music selection, in the middle of the menu transition that
-- the play-mode choice starts ("_volt26 menu transition.lua").  It holds the
-- sequence's fully covered frame while the profiles load and leaves the
-- transition data for the next screen, whose "Screen in.lua" plays the rest.
-- An entry without a transition in progress holds plain black.

local function continue()
	local screen = SCREENMAN:GetTopScreen()
	if screen and screen.Continue then screen:Continue() end
end

local af = Def.ActorFrame{
	InitCommand=function(self) self:draworder(1000) end,
	OnCommand=function(self) self:queuecommand("Load") end,
	LoadCommand=function(self) continue() end,
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
		InitCommand=function(self) self:FullScreen():diffuse(Color.Black) end,
	},
}

local data = VOLT26.State.Global.Volt26TransData
local covered = data and data.paths and data.next_frame and data.paths[data.next_frame - 1]
if covered then
	af[#af+1] = Def.Sprite{
		Texture=covered,
		InitCommand=function(self) self:Center():scaletoclipped(_screen.w, _screen.h) end,
	}
end

return af
