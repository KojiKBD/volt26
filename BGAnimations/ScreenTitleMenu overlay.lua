local introDuration = VOLT26.TitleMenu.GetIntroDurationSeconds()
local enabled = not _G.Volt26CityIntroPlayed
local red = color("#ED1C24")
local introFadeOutDuration = 0.36
local logoAt = 12.60
local logoFadeInDuration = 0.55
local logoFadeOutDuration = 0.78
local logoHoldDuration = introDuration - introFadeOutDuration - logoAt
	- logoFadeInDuration - logoFadeOutDuration
local paragraphFadeOutDuration = 0.25
local skipFadeOutDuration = 0.22

-- The opening vow runs as the screen overlay, not as the screen's "in"
-- transition. ScreenWithMenuElements::AllowCallbackInput() is !IsTransitioning(),
-- so while the "in" transition runs the engine drops every input event before any
-- Lua input callback sees it: a vow that *was* the transition could never be
-- skipped. As an overlay it draws in the same place, above the menu elements,
-- the screen is interactive from its first frame, and the vow holds input through
-- SCREENMAN:set_input_redirected (see underlay/Prototype3D.lua, which also owns
-- the Start-to-skip handling and broadcasts VOLT26_TitleIntroComplete).
--
-- ScreenInit's old red/logo handoff is intentionally retired. The title screen's
-- own opening now provides the complete transition into the city.
_G.Volt26InitHandoff = nil

local paragraphs = {
	{
		at=0.55, y=-148, zoom=1.18,
		text="I am thou, thou art I...\nThou hast found a new rhythm.",
		redWords={"thou", "new"},
	},
	{
		at=4.50, y=0, zoom=1.14,
		text="It shall become the strength\nthat carries thee forward.",
		redWords={"become", "forward"},
	},
	{
		at=8.20, y=164, zoom=1.06,
		text="With the birth of VOLT,\nI have obtained a new power\nthat shall lead us beyond our limits...",
		redWords={"birth", "VOLT", "beyond"},
	},
}

local function ApplyRedWords(actor, text, words)
	actor:ClearAttributes()
	for _, word in ipairs(words) do
		local offset = 1
		while offset <= #text do
			local first, last = string.find(text, word, offset, true)
			if not first then break end
			actor:AddAttribute(first - 1, {
				Length=last - first + 1,
				Diffuse=red,
			})
			offset = last + 1
		end
	end
end

local af = Def.ActorFrame{
	Name="VOLT26_OpeningVow",
	InitCommand=function(self)
		self:Center():draworder(10000):visible(enabled)
	end,
	OnCommand=function(self)
		if not enabled then return end
		self:sleep(introDuration - introFadeOutDuration)
			:linear(introFadeOutDuration):diffusealpha(0)
	end,
	-- Start skips the vow. The children keep running their own timelines, so
	-- fading this frame is what takes them off the screen.
	VOLT26_TitleIntroCompleteMessageCommand=function(self)
		if not enabled or self.VowDismissed then return end
		self.VowDismissed = true
		self:stoptweening():linear(skipFadeOutDuration):diffusealpha(0)
	end,
}

af[#af+1] = Def.Quad{
	Name="VowBlackout",
	InitCommand=function(self)
		self:zoomto(_screen.w, _screen.h):diffuse(0, 0, 0, 0.92)
	end,
}

for i, paragraph in ipairs(paragraphs) do
	af[#af+1] = LoadFont("Persona")..{
		Name="VowParagraph"..i,
		Text=paragraph.text,
		InitCommand=function(self)
			self:y(paragraph.y):zoom(paragraph.zoom)
				:maxwidth((_screen.w * 0.62) / paragraph.zoom)
				:diffuse(Color.White):shadowlength(0):diffusealpha(0)
			ApplyRedWords(self, paragraph.text, paragraph.redWords)
		end,
		OnCommand=function(self)
			if not enabled then return end
			self:sleep(paragraph.at):linear(0.28):diffusealpha(1)
				:sleep(logoAt - paragraphFadeOutDuration - paragraph.at - 0.28)
				:linear(paragraphFadeOutDuration):diffusealpha(0)
		end,
	}
end

-- The closing logo misfires like the one on volt26.it: a power flicker shortly
-- after it lands, then a sideways tear. The site animates the bolt and the
-- lettering as separate layers; this logo is a single texture, so the whole mark
-- moves and the flicker is softened to match. Poses are held, never eased, and
-- they are applied to this wrapper from an update function so the sprite's own
-- fade timeline is left alone.
local function LogoGlitchTimeline(level, width, height)
	local flickerAt, tearAt = logoAt + 0.80, logoAt + 1.90
	local timeline = {
		{at=flickerAt,         pose={alpha=0.25}},
		{at=flickerAt + 0.056, pose={zoom=1.03, rot=-1}},
		{at=flickerAt + 0.112, pose={alpha=0.45}},
		{at=flickerAt + 0.168, pose={}},
		{at=tearAt,            pose={x=-0.025*width, y=0.01*height, skew=-0.176}, kick=true},
		{at=tearAt + 0.06,     pose={x=0.02*width, y=-0.01*height, skew=0.105}},
		{at=tearAt + 0.12,     pose={x=-0.01*width, zoomx=1.04}},
		{at=tearAt + 0.18,     pose={}},
	}
	if level == "Full" then
		local secondAt = logoAt + 3.30
		timeline[#timeline+1] = {at=secondAt,        pose={x=-0.01*width, zoomx=1.04}, kick=true}
		timeline[#timeline+1] = {at=secondAt + 0.06, pose={x=0.02*width, y=-0.01*height, skew=0.105}}
		timeline[#timeline+1] = {at=secondAt + 0.12, pose={x=-0.025*width, y=0.01*height, skew=-0.176}}
		timeline[#timeline+1] = {at=secondAt + 0.18, pose={}}
	end
	return timeline
end

local function ApplyLogoPose(frame, pose)
	local zoom = pose.zoom or 1
	frame:xy(pose.x or 0, pose.y or 0):skewx(pose.skew or 0)
		:zoom(zoom):zoomx(zoom * (pose.zoomx or 1))
		:rotationz(pose.rot or 0):diffusealpha(pose.alpha or 1)
end

af[#af+1] = Def.ActorFrame{
	Name="VOLT26IntroLogoGlitch",
	OnCommand=function(self)
		local level = VOLT26.ThemePrefs.Get("GlitchIntensity")
		if not enabled or not VOLT26.Glitch.GetLevel() then return end
		local logo = self:GetChild("VOLT26IntroLogo")
		local timeline = LogoGlitchTimeline(
			level, logo:GetZoomedWidth(), logo:GetZoomedHeight())
		local elapsed, nextStep = 0, 1
		self:SetUpdateFunction(function(frame, delta)
			elapsed = elapsed + (delta or 0)
			while timeline[nextStep] and elapsed >= timeline[nextStep].at do
				local step = timeline[nextStep]
				ApplyLogoPose(frame, step.pose)
				if step.kick then VOLT26.Glitch.Kick(2) end
				nextStep = nextStep + 1
			end
		end)
	end,
	VOLT26_TitleIntroCompleteMessageCommand=function(self)
		self:SetUpdateFunction(nil)
		ApplyLogoPose(self, {})
	end,
	Def.Sprite{
		Name="VOLT26IntroLogo",
		Texture=THEME:GetPathG("", "VOLT26/logo_main (doubleres).png"),
		InitCommand=function(self)
			self:zoom(0.30):shadowlength(0):diffusealpha(0):visible(enabled)
		end,
		OnCommand=function(self)
			if not enabled then return end
			self:sleep(logoAt):linear(logoFadeInDuration):diffusealpha(1)
				:sleep(logoHoldDuration)
				:linear(logoFadeOutDuration):diffusealpha(0)
		end,
	},
}

af[#af+1] = LoadFont("Persona")..{
	Name="VOLT26Disclaimer",
	Text="THIS IS AN UNOFFICIAL, NON-PROFIT FAN-MADE THEME CREATED STRICTLY FOR PERSONAL ENJOYMENT. ALL MUSIC, LOGOS, ART DIRECTION, AND REFERENCES TO THE PERSONA SERIES\nBELONG ENTIRELY TO ATLUS / SEGA. THIS PROJECT IS NOT AFFILIATED WITH, ENDORSED BY, OR MONETIZED IN ANY WAY BY ATLUS. ALL RIGHTS RESERVED TO THEIR RESPECTIVE OWNERS.",
	InitCommand=function(self)
		self:y(_screen.h/2 - 18):valign(1):horizalign(center)
			:zoom(0.20):wrapwidthpixels((_screen.w * 0.94) / 0.20)
			:diffuse(Color.White):shadowlength(0)
	end,
}

return af
