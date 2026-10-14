-- The summary's ground: the navy alone.  The halves' art and the band are in
-- the overlay, among the cards (the faded ones go under the art).
local G = LoadActor(THEME:GetPathB("", "_volt26 gameover kit.lua"))
return G.Background(#G.Players() == 1, true)
