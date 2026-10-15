-- The hidden song's gameplay (VOLT26.Secret): nothing but the arrows over its
-- own scenery.  The gameplay interface is not built for it (ScreenGameplay
-- underlay/default.lua), and the engine's judgment and combo are hidden here.
--
--   * the ground is black, and red rises from the bottom as the song plays,
--     reaching the top as the music ends;
--   * the lyrics (VOLT26.Secret.Lyrics, from the song's .lrc) show one line at
--     a time in the cutout lettering, behind the arrows.
local song = GAMESTATE:GetCurrentSong()
local length = song and tonumber(song:MusicLengthSeconds()) or 0
if not length or length <= 0 then length = 1 end

local RED = color("#e40001")
local EDGE = 70             -- height of the glow above the red, in theme units at 1080
local LYRIC_Y = 0.72        -- of the screen height
local scale = SCREEN_HEIGHT / 1080
local style = VOLT26.Cutout.Style("SecretLyric")

local function progress()
	local t = GAMESTATE:GetCurMusicSeconds()
	return math.max(0, math.min(1, (tonumber(t) or 0) / length))
end

return Def.ActorFrame{
	Name="SecretUnderlay",
	OnCommand=function(self)
		-- Only the arrows: the engine's judgment and combo go too.
		local screen = SCREENMAN:GetTopScreen()
		for _, player in ipairs(GAMESTATE:GetHumanPlayers()) do
			local af = screen and screen:GetChild("Player" .. ToEnumShortString(player))
			if af then
				for _, name in ipairs({ "Judgment", "Combo" }) do
					local child = af:GetChild(name)
					if child then child:visible(false) end
				end
			end
		end
		self.lyric = -1
		self:SetUpdateFunction(function(frame)
			local p = progress()
			local h = SCREEN_HEIGHT * p
			frame:GetChild("Red"):zoomto(SCREEN_WIDTH, h)
			frame:GetChild("Edge"):y(SCREEN_BOTTOM - h):visible(p > 0)
			local index = VOLT26.Secret.LyricIndexAt(GAMESTATE:GetCurMusicSeconds())
			if index ~= frame.lyric then
				frame.lyric = index
				local line = VOLT26.Secret.Lyrics()[index]
				local text = line and line.Text or ""
				local lyric = frame:GetChild("Lyric")
				lyric:stoptweening()
				if text == "" then
					lyric:linear(0.15):diffusealpha(0)
				else
					lyric:GetChild("Slot"):playcommand("CutoutSet", { text = text })
					lyric:diffusealpha(0):zoom(1.08):decelerate(0.12):diffusealpha(1):zoom(1)
				end
			end
		end)
	end,
	OffCommand=function(self) self:SetUpdateFunction(nil) end,

	Def.Quad{
		Name="Ground",
		InitCommand=function(self) self:FullScreen():diffuse(Color.Black) end,
	},
	Def.Quad{
		Name="Red",
		InitCommand=function(self)
			self:halign(0.5):valign(1):xy(SCREEN_CENTER_X, SCREEN_BOTTOM)
				:zoomto(SCREEN_WIDTH, 0):diffuse(RED)
		end,
	},
	-- A soft glow on the rising edge.
	Def.Quad{
		Name="Edge",
		InitCommand=function(self)
			self:halign(0.5):valign(1):xy(SCREEN_CENTER_X, SCREEN_BOTTOM)
				:zoomto(SCREEN_WIDTH, EDGE * scale):diffuse(RED)
				:diffusetopedge(color("#e4000100")):visible(false)
		end,
	},
	Def.ActorFrame{
		Name="Lyric",
		InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_HEIGHT * LYRIC_Y):diffusealpha(0) end,
		VOLT26.Cutout.CreateSlot{
			maxW = style.maxW, maxH = style.maxH, maxChars = style.maxChars,
			halign = 0.5, valign = 0.5, opts = style.opts,
		}..{ Name="Slot" },
	},
}
