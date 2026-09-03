local tweentime = 0.30

return Def.ActorFrame{
	InitCommand=function(self)
		self:Center():draworder(101)
	end,
	OffCommand=function(self)
		-- by the time this screen's OffCommand is called, player mods should already have been read from file
		-- and applied to the SL[pn].ActiveModifiers table, so it is now safe to call ApplyMods() on any human players
		for player in ivalues(GAMESTATE:GetHumanPlayers()) do
			ApplyMods(player)
		end
	end,

	Def.Quad{
		Name="TransitionShade",
		InitCommand=function(self)
			self:horizalign(right):vertalign(bottom):FullScreen()
			self:diffuse(color("#090909")):diffusealpha(0)
		end,
		OnCommand=function(self)
			self:linear(tweentime):diffusealpha(0.92)
		end
	},

	Def.Quad{
		Name="AccentWipe",
		InitCommand=function(self)
			self:x(-_screen.cx-180):rotationz(-8)
				:diffuse(color("#ff0000")):zoomto(130,_screen.h*1.35)
		end,
		OnCommand=function(self)
			self:decelerate(tweentime):x(0)
				:sleep(0.08):accelerate(tweentime):x(_screen.cx+180)
				:queuecommand("Load")
		end,
		LoadCommand=function(self)
			SCREENMAN:GetTopScreen():Continue()
		end
	}
}
