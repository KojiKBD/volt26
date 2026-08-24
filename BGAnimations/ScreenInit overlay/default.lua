-- Use Simply Love's original ScreenInit for every non-VOLT visual style.
if ThemePrefs.Get("VisualStyle") ~= "VOLT26" then
local af = Def.ActorFrame{ InitCommand=function(self) self:Center() end }

-- check SM5 version, current game (dance, pump, etc.), and RTT support
af[#af+1] = LoadActor("./CompatibilityChecks.lua")

-- -----------------------------------------------------------------------

local slc = SL.Global.ActiveColorIndex

--semitransparent black quad as background for 7 decorative arrows
af[#af+1] = Def.Quad{
	InitCommand=function(self) self:zoomto(_screen.w,0):diffuse(Color.Black) end,
	OnCommand=function(self) self:accelerate(0.3):zoomtoheight(128):diffusealpha(0.9):sleep(2.1) end,
	OffCommand=function(self) self:accelerate(0.3):zoomtoheight(0) end
}

-- loop to add 7 SM5 logo arrows to the primary ActorFrame
for i=1,7 do

	local arrow = Def.ActorFrame{
		InitCommand=function(self) self:x((i-4) * 50):diffusealpha(0) end,
		OnCommand=function(self)
			-- thonk
			if ThemePrefs.Get("VisualStyle")=="Thonk" then
				self:diffusealpha(1):rotationy(-90):sleep(i*0.1 + 0.2)
				self:smooth(0.25):rotationy(0):sleep(0.8):bouncebegin(0.8):y(_screen.h)
			-- everything else
			else
				self:sleep(i*0.1 + 0.2)
				self:linear(0.75):diffusealpha(1):linear(0.75):diffusealpha(0)
			end

			self:queuecommand("Hide")
		end,
		HideCommand=function(self) self:visible(false) end,
	}

	-- desaturated SM5 logo
	arrow[#arrow+1] = LoadActor("logo.png")..{
		InitCommand=function(self) self:zoom(0.1):diffuse(GetHexColor(slc-i-4, true)) end,
	}

	-- only add Thonk asset if needed
	if ThemePrefs.Get("VisualStyle")=="Thonk" then
		arrow[#arrow+1] = LoadActor("thonk.png")..{
			InitCommand=function(self) self:zoom(0.1):xy(6,-2) end,
		}
	end

	af[#af+1] = arrow
end

return af

end

-- VOLT26 opening credits.
local af = Def.ActorFrame{
	InitCommand=function(self) self:Center() end,
	OffCommand=function(self)
		_G.Volt26InitHandoff = true
	end
}

-- Keep Simply Love's startup compatibility checks active behind the intro.
af[#af+1] = LoadActor("./CompatibilityChecks.lua")

local credits = {
	{ heading="CONCEPT & DESIGN", name="VOLT Team" },
	{ heading="VISUALS & ART", name="Koji" },
	{ heading="PROGRAMMING", name="Koji, Mrs GLM 5.2, Sir GPT" },
	{ heading="SPECIAL THANKS", name="Dando and the VOLT Team", sub="for testing, ideation, and QA" }
}

local credit_start = 0.35
local credit_step = 1.55
local logo_hit = 7.35
local star_frame_time = 1 / 20
local star_frame_count = 30
local star_loops = 2

af[#af+1] = Def.Quad{
	Name="CinematicBackground",
	InitCommand=function(self)
		self:zoomto(_screen.w, _screen.h):diffuse(Color.Black)
	end,
	OnCommand=function(self)
		self:sleep(logo_hit):linear(0.18):diffuse(color("#FF0000"))
	end
}

for i, credit in ipairs(credits) do
	local start_time = credit_start + (i - 1) * credit_step
	local card = Def.ActorFrame{
		Name="Credit" .. i,
		InitCommand=function(self) self:y(14):diffusealpha(0) end,
		OnCommand=function(self)
			self:sleep(start_time)
				:decelerate(0.20):y(0):diffusealpha(1)
				:sleep(0.78)
				:accelerate(0.22):y(-18):diffusealpha(0)
		end
	}

	card[#card+1] = LoadFont("Common Normal")..{
		Text=credit.heading,
		InitCommand=function(self)
			self:y(-22):zoom(0.68):maxwidth(_screen.w * 1.25)
				:diffuse(color("#FF3030")):shadowlength(2)
		end
	}
	card[#card+1] = LoadFont("Common Normal")..{
		Text=credit.name,
		InitCommand=function(self)
			self:y(12):zoom(0.82):maxwidth(_screen.w * 1.05)
				:diffuse(Color.White):shadowlength(2)
		end
	}
	if credit.sub then
		card[#card+1] = LoadFont("Common Normal")..{
			Text=credit.sub,
			InitCommand=function(self)
				self:y(43):zoom(0.58):maxwidth(_screen.w * 1.4)
					:diffuse(color("#D0D0D0")):shadowlength(2)
			end
		}
	end
	af[#af+1] = card
end

af[#af+1] = LoadFont("Common Normal")..{
	Name="VOLT26Disclaimer",
	Text="This is an unofficial, non-profit fan-made theme created strictly for personal enjoyment. All music, logos, art direction, and references to the Persona series\nbelong entirely to ATLUS / SEGA. This project is not affiliated with, endorsed by, or monetized in any way by ATLUS. All rights reserved to their respective owners.",
	InitCommand=function(self)
		self:y(_screen.h/2 - 24):valign(1):horizalign(center)
			:zoom(0.34):wrapwidthpixels((_screen.w * 0.94) / 0.34)
			:diffuse(color("#B8B8B8")):shadowlength(1)
	end,
	OnCommand=function(self)
		self:sleep(logo_hit - 0.20):linear(0.20):diffusealpha(0)
	end
}

local function StarFramePath(frame)
	return THEME:GetPathG("", string.format(
		"_VisualStyles/VOLT26/Stars/star_%05d.png", frame))
end

-- Exactly 60 displayed frames: the 30-frame sequence twice at 20fps.
local current_star_frame = 0
local displayed_star_frames = 1
af[#af+1] = Def.Sprite{
	Name="VOLT26IntroStars",
	Texture=StarFramePath(0),
	InitCommand=function(self)
		self:zoomto(_screen.w, _screen.h):diffusealpha(0)
	end,
	OnCommand=function(self)
		self:sleep(logo_hit):diffusealpha(1)
			:sleep(star_frame_time):queuecommand("NextFrame")
	end,
	NextFrameCommand=function(self)
		if displayed_star_frames >= star_frame_count * star_loops then return end
		current_star_frame = (current_star_frame + 1) % star_frame_count
		displayed_star_frames = displayed_star_frames + 1
		self:Load(StarFramePath(current_star_frame))
		if displayed_star_frames < star_frame_count * star_loops then
			self:sleep(star_frame_time):queuecommand("NextFrame")
		end
	end
}

af[#af+1] = Def.Sprite{
	Name="VOLT26IntroLogo",
	Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/logo_main (doubleres).png"),
	InitCommand=function(self) self:zoom(2.2):diffusealpha(0) end,
	OnCommand=function(self)
		self:sleep(logo_hit - 0.62)
			:diffusealpha(1):accelerate(0.42):zoom(0.26)
			:decelerate(0.20):zoom(0.30)
			:glow(1,1,1,0.65):linear(0.18):glow(1,1,1,0)
	end
}

af[#af+1] = Def.Sound{
	Name="VOLT26IntroKnifeSound",
	File=THEME:GetPathG("", "_VisualStyles/VOLT26/knife.ogg"),
	OnCommand=function(self)
		self:sleep(logo_hit):queuecommand("PlayImpact")
	end,
	PlayImpactCommand=function(self) self:play() end
}

return af
