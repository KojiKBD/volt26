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
timing.duration = 1

local t = Def.ActorFrame{}

t.OffCommand=function(self)
	self:sleep(timing.duration)
end

-- Enhanced retains the original flying-shape composition. Performance uses
-- only the same clean diagonal wipe as ScreenProfileLoad.
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

-- VOLT26 transition animations
do
	local knife_delay = 0.35
	if performance then
		local wipe_time = 0.30
		local wipe_pause = 0.08
		timing.duration = knife_delay + wipe_time + wipe_pause + wipe_time

		t.OffCommand=function(self)
			VOLT26.State.Global.Volt26TransData = nil
			self:sleep(timing.duration)
		end

		-- Match the text-free ScreenProfileLoad wipe that precedes Song Select.
		local transition = Def.ActorFrame{
			Name="VOLT26_PerformanceTransition",
			InitCommand=function(self) self:draworder(1000) end,
		}
		transition[#transition+1] = Def.Quad{
			Name="TransitionShade",
			InitCommand=function(self)
				self:Center():zoomto(_screen.w, _screen.h)
					:diffuse(color("#090909")):diffusealpha(0)
			end,
			OffCommand=function(self)
				self:sleep(knife_delay):linear(wipe_time):diffusealpha(0.92)
			end,
		}
		transition[#transition+1] = Def.Quad{
			Name="AccentWipe",
			InitCommand=function(self)
				self:xy(-180, _screen.cy):rotationz(-8)
					:diffuse(color("#ff0000")):zoomto(130, _screen.h*1.35)
			end,
			OffCommand=function(self)
				self:sleep(knife_delay):decelerate(wipe_time):x(_screen.cx)
					:sleep(wipe_pause):accelerate(wipe_time):x(_screen.w+180)
			end,
		}
		t[#t+1] = transition
	else
		local frame_time = 1/30
		local volt_transitions = {
			-- switch_screen is a fully-covered frame. Everything after it is
			-- rendered by "Screen in.lua" over the newly-loaded screen.
			{ folder="VOLT26/TransMenu",  prefix="TransMenu",  frames=16, switch_screen=8  },
			{ folder="VOLT26/TransMenu2", prefix="TransMenu2", frames=28, switch_screen=17 }
		}

		local selected = volt_transitions[math.random(#volt_transitions)]
		local paths = {}
		for i=0, selected.frames-1 do
			paths[#paths+1] = THEME:GetPathG("",
				string.format("%s/%s_%05d.png", selected.folder, selected.prefix, i))
		end

		if PREFETCHMAN then
			for _, path in ipairs(paths) do PREFETCHMAN:Add(path) end
		end

		-- Let the press animation land before the covering frames begin.
		timing.duration = knife_delay + selected.switch_screen * frame_time

		-- Store the selected sequence when the menu actually exits. The table
		-- survives the screen swap; the generic Screen "in" actor consumes it.
		t.OffCommand=function(self)
			VOLT26.State.Global.Volt26TransData = {
				paths=paths,
				next_frame=selected.switch_screen+1,
				frame_time=frame_time
			}
			self:sleep(timing.duration)
		end

		local transition = Def.Sprite{
			InitCommand=function(self)
				self:Center():scaletoclipped(_screen.w, _screen.h)
					:draworder(1000):diffusealpha(0)
			end,
			OffCommand=function(self)
				self:sleep(knife_delay):queuecommand("VoltFrame1")
			end,
			VoltFrame1Command=function(self)
				self:Load(paths[1]):diffusealpha(1)
					:sleep(frame_time):queuecommand("VoltFrame2")
			end
		}

		for i=2, selected.switch_screen do
			transition["VoltFrame"..i.."Command"] = function(self)
				self:Load(paths[i]):sleep(frame_time)
				if i < selected.switch_screen then
					self:queuecommand("VoltFrame"..(i+1))
				end
			end
		end

		t[#t+1] = transition
	end
end
return t
