local underlay = Def.ActorFrame{
	Name="VOLT26DemonstrationUnderlay",
	OffCommand=function()
		for _, level in ipairs({"ModsLevel_Stage", "ModsLevel_Song"}) do
			GAMESTATE:GetPlayerState(PLAYER_2):GetPlayerOptions(level):Reverse(0)
		end
	end,
}

-- Present both supported scroll directions in every arcade demonstration.
-- Preferred options are deliberately untouched so the CPU preview cannot
-- change a player's persisted selection.
for _, level in ipairs({"ModsLevel_Stage", "ModsLevel_Song"}) do
	GAMESTATE:GetPlayerState(PLAYER_2):GetPlayerOptions(level):Reverse(1)
end

-- Keep the arcade demonstration visually related to normal gameplay while
-- avoiding player-owned statistics, tournament policy, and session state.
underlay[#underlay+1] = LoadActor("./ScreenGameplay underlay/Shared/Header.lua")
underlay[#underlay+1] = LoadActor("./ScreenGameplay underlay/Shared/SongInfoBar.lua")

underlay[#underlay+1] = LoadFont("Common Normal")..{
	Text="DEMONSTRATION",
	InitCommand=function(self)
		self:xy(_screen.cx, 55):zoom(0.55):diffuse(Color.White)
			:strokecolor(Color.Black):draworder(10)
	end,
}

for player, label in pairs({[PLAYER_1]="NORMAL", [PLAYER_2]="REVERSE"}) do
	underlay[#underlay+1] = LoadFont("Common Normal")..{
		Text=label,
		InitCommand=function(self)
			self:xy(player == PLAYER_1 and _screen.w * 0.25 or _screen.w * 0.75, 55)
				:zoom(0.45):diffuse(Color.White):strokecolor(Color.Black):draworder(10)
		end,
	}
end

return underlay
