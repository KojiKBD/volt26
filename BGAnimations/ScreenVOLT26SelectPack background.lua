-- The backdrop shared with the song wheel, under the pack step's own set
-- (the red ground and stripes of overlay/Scene.lua).  The set is cleared off
-- when a pack is opened, so the song wheel's backdrop is what remains.
local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local scene = LoadActor("./ScreenVOLT26SelectPack overlay/Scene.lua", { K=K })

return Def.ActorFrame{
	LoadActor(THEME:GetPathB("", "_volt26 music backdrop.lua")),
	Def.ActorFrame{
		InitCommand=function(self) self:xy(K.Left, K.Top):zoom(K.Scale) end,
		scene.Back,
	},
}
