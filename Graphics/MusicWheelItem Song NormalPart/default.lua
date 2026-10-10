local af = Def.ActorFrame{}

-- Unlock markers keep their own per-player logic (and the guest reset they do
-- when a player joins); the row itself is VOLT26's song wheel row.
for player in ivalues(PlayerNumber) do
	af[#af+1] = LoadActor("Unlocks.lua", player)
end

af[#af+1] = LoadActor(THEME:GetPathG("", "VOLT26/SongWheel/Row.lua"), "Song")

return af
