local af = LoadFallbackB()

-- ScreenInit can leave its final VOLT26 frame here so it fades over the
-- fully-created title menu. Other visual styles retain the inherited
-- ScreenTitleMenu transition without loading VOLT26 assets.
if _G.Volt26InitHandoff == true then
	af[#af+1] = LoadActor(THEME:GetPathB("", "_volt26 init handoff"))
end

return af
