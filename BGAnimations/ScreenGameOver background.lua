-- The ground of the end-of-session screens (see "_volt26 gameover kit.lua").
local G = LoadActor(THEME:GetPathB("", "_volt26 gameover kit.lua"))
return G.Background(#G.Players() == 1)
