-- The backdrop shared with the song wheel, under the pack step's own set
-- (the red ground and stripes of overlay/Scene.lua).  The set is cleared off
-- when a pack is opened; the song select's own red scene fades in over it
-- meanwhile (Scene.lua "Bridge"), so the pack step hands over to the song
-- select's scenery instead of uncovering the backdrop.
local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local scene = LoadActor("./ScreenVOLT26SelectPack overlay/Scene.lua", { K=K })

return Def.ActorFrame{
	LoadActor(THEME:GetPathB("", "_volt26 music backdrop.lua")),
	Def.ActorFrame{
		InitCommand=function(self) self:xy(K.Left, K.Top):zoom(K.Scale) end,
		scene.Back,
	},
	LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/Scene.lua"), "Bridge"),
}
