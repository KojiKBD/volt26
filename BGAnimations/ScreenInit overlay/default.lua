-- VOLT26 opening credits.
local af = Def.ActorFrame{
	InitCommand=function(self) self:Center() end,
	OffCommand=function(self)
		_G.Volt26InitHandoff = true
	end
}

-- Keep startup compatibility checks active behind the intro.
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
		"VOLT26/Stars/star_%05d.png", frame))
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
	Texture=THEME:GetPathG("", "VOLT26/logo_main (doubleres).png"),
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
	File=THEME:GetPathG("", "VOLT26/knife.ogg"),
	OnCommand=function(self)
		self:sleep(logo_hit):queuecommand("PlayImpact")
	end,
	PlayImpactCommand=function(self) self:play() end
}

return af
