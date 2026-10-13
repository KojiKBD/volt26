-- The song's jacket in the mockup's white frame at the top right, and the
-- song's length stamped in cutout lettering over the frame's lower edge.
-- The length is a part of its own (p.Part == "Length"), loaded after the
-- player cards so the first card's plate does not cover it.
--
-- The jacket stays upright (jackets are never rotated, see
-- .agents/presentation.md); the frame around it carries the slant.  Under it,
-- Header.lua keeps the pack's own tile, which the pack step's jacket shrinks
-- into on the way in, so a song without artwork shows its pack.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local frame = P.Art.Pieces.JacketFrame

local SIZE = K.Badge.Size
local X, Y = K.Badge.X, K.Badge.Y
local ART_DELAY = 0.10   -- the wheel must rest this long before artwork loads
-- The length tag: over the frame's lower right corner, tilted against it,
-- clear of the first card's plate below.
local LENGTH = { X = frame.X + frame.W / 2 - 18, Y = frame.Y + frame.H / 2 - 30 }

if p.Part == "Length" then
	return Def.ActorFrame{
		Name="JacketLength",
		RefreshCommand=function(self)
			local item = S.Item()
			local length = item and S.LengthText(item) or ""
			if length == K.Dash then length = "" end
			self:GetChild("Length"):visible(length ~= "")
			P.SetCutout(self:GetChild("Length"), length)
		end,
		P.CutoutSlot{ Name="Length", Id="Length", X=LENGTH.X, Y=LENGTH.Y, Scale=K.Scale },
	}
end

local af = Def.ActorFrame{
	Name="Jacket",
	RefreshCommand=function(self)
		local item = S.Item()
		local path, cacheDir
		if item then
			if S.IsCourseMode() then path, cacheDir = K.CourseArt(item) else path, cacheDir = K.SongArt(item) end
		end
		-- The full image looks best at this size, so the small cached copy
		-- is not used.
		cacheDir = nil
		self.wantedArt, self.wantedCache = path, cacheDir
		if path ~= self.loadedArt then
			self:GetChild("Art"):visible(false)
			self:stoptweening():sleep(ART_DELAY):queuecommand("LoadArt")
		end
	end,
	LoadArtCommand=function(self)
		local art = self:GetChild("Art")
		local path, cacheDir = self.wantedArt, self.wantedCache
		self.loadedArt = path
		if not path then art:visible(false); return end
		if K.LoadStill(art, path, cacheDir) then
			K.Cover(art, SIZE, SIZE)
			-- The new jacket lands: in from slightly larger, upright (jackets
			-- are never turned).
			local zoom = art:GetZoomX()
			art:visible(true):stoptweening():zoom(zoom * 1.18):diffusealpha(0)
				:decelerate(0.18):zoom(zoom):diffusealpha(1)
		else
			art:visible(false)
		end
	end,
}

af[#af+1] = Def.Sprite{ Name="Art", InitCommand=function(self) self:xy(X, Y):visible(false) end }

return af
