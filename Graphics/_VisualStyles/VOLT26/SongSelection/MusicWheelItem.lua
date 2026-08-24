local requested_kind = ...
--[=[
-- Legacy raster-backed wheel presentation retained as a reference.
-- VOLT26-only text drawn inside the engine's real MusicWheelItem.
-- Navigation and recycling remain owned by MusicWheel; this actor only replaces
-- the visible label so long titles can marquee without changing wheel motion.

local kind = ... or "Song"
local font = "P5hatty"
local max_chars = 24
local pack_idle = color("#720b12")
local pack_focus = color("#e20d18")

local function text_color(focused)
	if kind == "Section" then return Color.White end
	return focused and Color.White or color("#a5a5a5")
end

local function is_focused(self)
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	local selected_type = wheel and wheel:GetSelectedType() or nil
	if self._volt26_song then
		return selected_type == "WheelItemDataType_Song" and GAMESTATE:GetCurrentSong() == self._volt26_song
	end
	if self._volt26_course then
		return selected_type == "WheelItemDataType_Course" and GAMESTATE:GetCurrentCourse() == self._volt26_course
	end
	if self._volt26_section then
		return (selected_type == "WheelItemDataType_Section" or selected_type == "WheelItemDataType_ParentSection")
			and wheel:GetSelectedSection() == self._volt26_section
	end
	return false
end

local function title_for(params)
	if params.Song then return params.Song:GetDisplayFullTitle() end
	if params.Course then return params.Course:GetDisplayFullTitle() end
	if params.Label and params.Label ~= "" then return params.Label end
	return params.Text or ""
end

local function clipped(text)
	local length = text:utf8len()
	if length <= max_chars then return text end
	return text:utf8sub(1, max_chars - 3) .. "..."
end

local function section_count(text)
	if kind ~= "Section" or not text or text == "" then return "" end
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(text) end)
	return ok and songs and #songs > 0 and tostring(#songs) or ""
end

local function marquee_text(self)
	local text = self._volt26_full_text or ""
	local length = self._volt26_text_length or 0
	if not self._volt26_has_focus or length <= max_chars then
		return clipped(text)
	end

	local loop = text .. "   " .. text
	local first = self._volt26_marquee_position or 1
	return loop:utf8sub(first, first + max_chars - 1)
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:x(kind == "Song" and 40 or 30):visible(false)
		self._volt26_marquee_elapsed = -0.65
		self:SetUpdateFunction(function(frame, delta)
			-- MusicWheel recycles NormalPart actors without reliably sending SetCommand
			-- to every now-inactive part.  Enforce this guard every frame so a VOLT
			-- label can never remain visible after changing visual styles.
			if ThemePrefs.Get("VisualStyle") ~= "VOLT26" then
				frame:visible(false)
				return
			end
			local focused = is_focused(frame)
			local hover = frame:GetChild("Hover")
			if hover then
				hover:visible(focused and kind ~= "Section")
					:diffuse(Color.White):diffusealpha(focused and kind ~= "Section" and 1 or 0)
			end
			local pack_bar = frame:GetChild("PackBar")
			if pack_bar then pack_bar:diffuse(focused and pack_focus or pack_idle) end
			if focused ~= frame._volt26_has_focus then
				frame._volt26_has_focus = focused
				frame._volt26_marquee_position = 1
				frame._volt26_marquee_elapsed = -0.65
				frame:GetChild("Label"):settext(marquee_text(frame))
					:diffuse(text_color(focused))
				local count = frame:GetChild("Count")
				if count then count:diffuse(text_color(focused)) end
			end
			if not focused or (frame._volt26_text_length or 0) <= max_chars then return end
			frame._volt26_marquee_elapsed = frame._volt26_marquee_elapsed + delta
			if frame._volt26_marquee_elapsed < 0.11 then return end
			frame._volt26_marquee_elapsed = frame._volt26_marquee_elapsed - 0.11
			frame._volt26_marquee_position = (frame._volt26_marquee_position or 1) + 1
			if frame._volt26_marquee_position > frame._volt26_text_length + 3 then
				frame._volt26_marquee_position = 1
			end
			frame:GetChild("Label"):settext(marquee_text(frame))
		end)
	end,
	SetCommand=function(self, params)
		local matches_kind = (kind == "Song" and params.Song ~= nil)
			or (kind == "Course" and params.Course ~= nil)
			or (kind == "Section" and params.Song == nil and params.Course == nil
				and (params.Type == "SectionExpanded" or params.Type == "SectionCollapsed"
					or params.Type == "ParentExpanded" or params.Type == "ParentCollapsed"))
		self:visible(ThemePrefs.Get("VisualStyle") == "VOLT26" and matches_kind)
		if not matches_kind then return end

		local text = title_for(params)
		self._volt26_song = params.Song
		self._volt26_course = params.Course
		self._volt26_section = (params.Song == nil and params.Course == nil) and params.Text or nil
		self._volt26_full_text = text
		self._volt26_text_length = text:utf8len()
		self._volt26_has_focus = is_focused(self)
		self._volt26_marquee_position = 1
		self._volt26_marquee_elapsed = -0.65
		local hover = self:GetChild("Hover")
		if hover then
			hover:visible(self._volt26_has_focus and kind ~= "Section")
				:diffuse(Color.White)
				:diffusealpha(self._volt26_has_focus and kind ~= "Section" and 1 or 0)
		end

		local is_child = params.ParentSection and params.ParentSection ~= ""
		self:x((kind == "Song" and 40 or 30) + (is_child and 12 or 0))
		local label = self:GetChild("Label")
		label
			:settext(marquee_text(self))
			:diffuse(text_color(self._volt26_has_focus))
		local count = self:GetChild("Count")
		if count then
			count:settext(section_count(text))
				:x(label:GetZoomedWidth() + 10)
				:diffuse(text_color(self._volt26_has_focus))
		end
		if kind == "Section" then
			local count_width = count and count:GetText() ~= "" and count:GetZoomedWidth() or 0
			local bar_width = label:GetZoomedWidth() + count_width + (count_width > 0 and 34 or 20)
			self:GetChild("PackBar"):visible(true):zoomto(bar_width, 38)
				:diffuse(self._volt26_has_focus and pack_focus or pack_idle)
		end
	end,

	Def.Quad{
		Name="PackBar",
		InitCommand=function(self)
			self:horizalign(left):x(-12):skewx(-0.18):visible(false)
		end,
	},

	Def.Sprite{
		Name="Hover",
		Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/SongSelection/Hover_PS.png"),
		InitCommand=function(self)
			self:horizalign(left):x(-32)
				:setsize(_screen.w*0.39, math.max(34, _screen.h/15-5))
				:diffuse(Color.White):diffusealpha(0):visible(false)
		end,
	},

	Def.BitmapText{
		Name="Label",
		Font=font,
		InitCommand=function(self)
			self:horizalign(left):zoom(kind == "Song" and 0.13 or 0.12)
				:strokecolor(color("#00000000"))
		end,
	},

	Def.BitmapText{
		Name="Count",
		Font=font,
		InitCommand=function(self)
			self:horizalign(left):zoom(0.095):strokecolor(color("#00000000"))
		end,
	}
}

return af
]=]

return LoadActor(THEME:GetPathG("", "_VisualStyles/VOLT26/SongSelection/MusicWheelItemNative.lua"), requested_kind)
