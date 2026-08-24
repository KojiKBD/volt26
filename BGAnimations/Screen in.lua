local af = Def.ActorFrame{}

-- A transition can finish after its destination screen has loaded. Preserve
-- the inherited transition for every screen and add the VOLT26 receiver only
-- while a VOLT26 transition is actually in progress.
if VOLT26 and VOLT26.State.Global.Volt26TransData then
	af[#af+1] = LoadActor(THEME:GetPathB("", "_volt26 transition receiver"))
end

return af
