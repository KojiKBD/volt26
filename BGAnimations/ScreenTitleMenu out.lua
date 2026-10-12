local color1 = GetHexColor(VOLT26.State.Global.ActiveColorIndex-2, true)
local color2 = GetHexColor(VOLT26.State.Global.ActiveColorIndex-1, true)
local performance = VOLT26.Performance.IsEnabled()

local assets = {}
assets.flycenter = THEME:GetPathG("", "VOLT26/TitleMenu flycenter")
assets.flytop    = THEME:GetPathG("", "VOLT26/TitleMenu flytop")
assets.flybottom = THEME:GetPathG("", "VOLT26/TitleMenu flybottom")

local timing = {}
timing.af_decel = 0.4
timing.af_accel = 0.5
timing.img_accel= 0.8

local t = Def.ActorFrame{}

-- Enhanced retains the original flying-shape composition. Performance uses
-- only the diagonal wipe of the shared menu transition.
if not performance then
-- centers
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+50) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-250)
		    :accelerate(timing.af_accel):addy(20):diffusealpha(0)
	end,

	--top center
	LoadActor(assets.flycenter)..{
		InitCommand=function(self) self:diffuse(color2):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(50):zoom(1):diffusealpha(0.4)
			    :sleep(0):zoom(0)
		end
	},
	LoadActor(assets.flycenter)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-50):zoom(0.6):diffusealpha(0.6)
			    :sleep(0):zoom(0)
		end
	},
}

t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+380) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-250)
		    :accelerate(timing.af_accel):addy(80):diffusealpha(0)
	end,

	--bottom center
	LoadActor(assets.flycenter)..{
		InitCommand=function(self) self:diffuse(color2):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(50):zoom(0.6):diffusealpha(0.6)
			    :sleep(0):zoom(0)
		end
	},
	LoadActor(assets.flycenter)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-50):zoom(1):diffusealpha(0.4)
			    :sleep(0):zoom(0)
		end
	}
}

-- up 200
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-200)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	--top left
	LoadActor(assets.flycenter)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-200):zoom(1):diffusealpha(0.6)
			    :sleep(0):zoom(0)
		end
	},
	--top right
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(200):zoom(1):diffusealpha(0.4)
			    :sleep(0):zoom(0)
		end
	}
}

--up 250
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-250)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	--top left
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color2):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-200):zoom(1.5):diffusealpha(0.3)
			    :sleep(0):zoom(0)
		end
	},
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-200):zoom(0.8):diffusealpha(0.6)
			    :sleep(0):zoom(0)
		end
	},
	--top right
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(200):zoom(1.5):diffusealpha(0.2)
			    :sleep(0):zoom(0)
		end
	},
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color2):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(200):zoom(0.8):diffusealpha(0.4)
			    :sleep(0):zoom(0)
		end
	}
}

--up 150, out 280
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-150)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	--top left
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-280):zoom(1.2):diffusealpha(0.6)
			    :sleep(0):zoom(0)
		end
	},
	--top right
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(280):zoom(1.2):diffusealpha(0.4)
			    :sleep(0):zoom(0)
		end
	}
}

--up 250, out 280
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-250)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	--top left
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-280):zoom(0.2):diffusealpha(0.3)
			    :sleep(0):zoom(0)
		end
	},
	--top right
	LoadActor(assets.flytop)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(280):zoom(0.2):diffusealpha(0.2)
			    :sleep(0):zoom(0)
		end
	}
}

--up 200
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-200)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	--bottom left
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-200):zoom(1):diffusealpha(0.3)
			    :sleep(0):zoom(0)
		end
	},
	--bottom right
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(200):zoom(1):diffusealpha(0.2)
			    :sleep(0):zoom(0)
		end
	}
}

--up 250
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-250)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	-- bottom left
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color2):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-200):zoom(1.5):diffusealpha(0.6)
			    :sleep(0):zoom(0)
		end
	},
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-200):zoom(0.8):diffusealpha(0.3)
			    :sleep(0):zoom(0)
		end
	},
	-- bottom right
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(200):zoom(1.5):diffusealpha(0.4)
			    :sleep(0):zoom(0)
		end
	},
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color2):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(200):zoom(0.8):diffusealpha(0.2)
			    :sleep(0):zoom(0)
		end
	}
}

--up 150, out 280
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-150)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	--bottom left
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-280):zoom(1.2):diffusealpha(0.3)
			    :sleep(0):zoom(0)
		end
	},
	--bottom right
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(280):zoom(1.2):diffusealpha(0.2)
			    :sleep(0):zoom(0)
		end
	}
}

--up 250, out 280
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy+200) end,
	OffCommand=function(self)
		self:decelerate(timing.af_decel):addy(-250)
		    :accelerate(timing.af_accel):addy(100):diffusealpha(0)
	end,

	--bottom left
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):rotationy(180):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(-280):zoom(0.2):diffusealpha(0.3)
				:sleep(0):zoom(0)
		end
	},
	--bottom right
	LoadActor(assets.flybottom)..{
		InitCommand=function(self) self:diffuse(color1):diffusealpha(0):zoom(0) end,
		OffCommand=function(self)
			self:accelerate(timing.img_accel):addx(280):zoom(0.2):diffusealpha(0.2)
			    :sleep(0):zoom(0)
		end
	}
}

end

-- VOLT26's menu transition (shared with the play-mode choice); it sets its
-- own length, longer than the flying shapes' when it needs to be.
t[#t+1] = LoadActor(THEME:GetPathB("", "_volt26 menu transition"))

return t
