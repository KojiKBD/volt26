local af = Def.ActorFrame{}

-- VOLT26 keeps unlock markers but renders all song metadata with its native row.
for player in ivalues(PlayerNumber) do
	af[#af+1] = LoadActor("Unlocks.lua", player)
end

af[#af+1] = LoadActor(THEME:GetPathG("", "VOLT26/SongSelection/MusicWheelItem.lua"), "Song")

return af
