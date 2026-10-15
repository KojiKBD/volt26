-- A black cover with LOADING in the cutout lettering over the song reloads
-- the theme starts by itself at startup (VOLT26.Secret installing its hidden
-- song: ScreenVOLT26SecretReload, ScreenVOLT26SecretReloadAll).  Those are
-- the engine's ScreenReloadSongs, which has no overlay of its own and prints
-- its progress in plain text; ScreenSystemLayer draws above every screen, so
-- the cover hides it.  The credit line stays on top.
local covered = {
	ScreenVOLT26SecretReload = true,
	ScreenVOLT26SecretReloadAll = true,
}
local style = VOLT26.Cutout.Style("Loading")

local function coveredNow()
	local screen = SCREENMAN:GetTopScreen()
	return screen ~= nil and covered[screen:GetName()] == true
end

return Def.ActorFrame{
	Name="VOLT26LoadingCover",
	InitCommand=function(self) self:visible(false) end,
	ScreenChangedMessageCommand=function(self) self:visible(coveredNow()) end,

	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(Color.Black) end,
	},
	VOLT26.Cutout.CreateSlot{
		x = _screen.cx, y = _screen.cy,
		maxW = style.maxW, maxH = style.maxH, maxChars = style.maxChars,
		halign = 0.5, valign = 0.5, opts = style.opts,
	}..{
		OnCommand=function(self) self:playcommand("CutoutSet", { text = "LOADING" }) end,
	},
}
