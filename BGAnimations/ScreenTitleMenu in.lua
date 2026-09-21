local introDuration = VOLT26.TitleMenu.GetIntroDurationSeconds()
-- The opening vow belongs to the 3D city; the classic Performance-mode title
-- has no cinematic.
local enabled = not VOLT26.TitleMenu.UsesClassicLayout() and not _G.Volt26CityIntroPlayed
local red = color("#ED1C24")
local introFadeOutDuration = 0.36
local logoAt = 12.60
local logoFadeInDuration = 0.55
local logoFadeOutDuration = 0.78
local logoHoldDuration = introDuration - introFadeOutDuration - logoAt
	- logoFadeInDuration - logoFadeOutDuration
local paragraphFadeOutDuration = 0.25

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
	StartTransitioningCommand=function(self)
		if not enabled then return end
		self:sleep(introDuration - introFadeOutDuration)
			:linear(introFadeOutDuration):diffusealpha(0)
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
		StartTransitioningCommand=function(self)
			if not enabled then return end
			self:sleep(paragraph.at):linear(0.28):diffusealpha(1)
				:sleep(logoAt - paragraphFadeOutDuration - paragraph.at - 0.28)
				:linear(paragraphFadeOutDuration):diffusealpha(0)
		end,
	}
end

af[#af+1] = Def.Sprite{
	Name="VOLT26IntroLogo",
	Texture=THEME:GetPathG("", "VOLT26/logo_main (doubleres).png"),
	InitCommand=function(self)
		self:zoom(0.30):shadowlength(0):diffusealpha(0):visible(enabled)
	end,
	StartTransitioningCommand=function(self)
		if not enabled then return end
		self:sleep(logoAt):linear(logoFadeInDuration):diffusealpha(1)
			:sleep(logoHoldDuration)
			:linear(logoFadeOutDuration):diffusealpha(0)
	end,
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
