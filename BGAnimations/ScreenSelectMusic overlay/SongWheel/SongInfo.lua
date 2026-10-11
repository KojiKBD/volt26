-- The selected song (or course): artwork on the left, title, artist, BPM and
-- length beside it.  This takes the place of Simply Love's banner and song
-- description, with the jacket preferred over the banner.
local p = ...
local K, S = p.K, p.S

local infoTop = 120
local artSize = 300
local artX, artY = 40 + artSize/2, infoTop + artSize/2
local textX = 40 + artSize + 32
local textWidth = 960 - textX
local artDelay = 0.10   -- the wheel must rest this long before artwork loads


local af = Def.ActorFrame{
	Name="SongInfo",
	RefreshCommand=function(self)
		local item = S.Item()
		local title, subtitle, artist = "", "", ""
		if item then
			if S.IsCourseMode() then
				title = item:GetDisplayFullTitle()
			else
				title = item:GetDisplayMainTitle()
				subtitle = item:GetDisplaySubTitle() or ""
				artist = item:GetDisplayArtist() or ""
			end
		end
		K.SetDisplay(self:GetChild("Title"), title, 46, textWidth)
		K.SetLabel(self:GetChild("Subtitle"), subtitle:upper(), 14, textWidth)
		K.SetDisplay(self:GetChild("Artist"), artist ~= "" and artist or K.Dash, 26, textWidth)
		K.SetDisplay(self:GetChild("Bpm"), S.BPMText(item), 30, 220)
		K.SetDisplay(self:GetChild("Length"), S.LengthText(item), 30, 220)
		self:GetChild("Placeholder"):visible(item == nil)

		-- Artwork waits for the wheel to settle.
		local path, cacheDir
		if item then
			if S.IsCourseMode() then path, cacheDir = K.CourseArt(item) else path, cacheDir = K.SongArt(item) end
		end
		-- The full image looks best at this size; the low-end path keeps to the
		-- small cached copy.
		if not VOLT26.Performance.IsEnabled() then cacheDir = nil end
		self.wantedArt, self.wantedCache = path, cacheDir
		self:GetChild("Initials"):settext(item and K.Initials(title) or "")
		if path ~= self.loadedArt then
			self:GetChild("Art"):visible(false)
			self:stoptweening():sleep(artDelay):queuecommand("LoadArt")
		end
	end,
	LoadArtCommand=function(self)
		local art = self:GetChild("Art")
		local path, cacheDir = self.wantedArt, self.wantedCache
		self.loadedArt = path
		if not path then art:visible(false); return end
		if K.LoadStill(art, path, cacheDir) then
			K.Cover(art, artSize, artSize)
			art:visible(true)
		else
			art:visible(false)
		end
	end,
}

af[#af+1] = K.Rule{ Name="ArtStroke", AlignX=0.5, AlignY=0.5, X=artX, Y=artY, Width=artSize+4, Height=artSize+4 }
af[#af+1] = K.Rule{ Name="ArtGround", AlignX=0.5, AlignY=0.5, X=artX, Y=artY, Width=artSize, Height=artSize, Tint=K.Panel2 }
af[#af+1] = K.Text{ Name="Initials", Role="Display", Px=110, Tint=K.Dim, Align=center, X=artX, Y=artY, Width=artSize-40 }
af[#af+1] = Def.Sprite{ Name="Art", InitCommand=function(self) self:xy(artX, artY):visible(false) end }

af[#af+1] = K.Text{ Name="Title", Role="Display", Px=46, Tint=K.Ink, X=textX, Y=infoTop+34 }
af[#af+1] = K.Text{ Name="Subtitle", Px=14, Tint=K.Mute, X=textX, Y=infoTop+76 }
af[#af+1] = K.Text{ Name="Placeholder", Px=14, Tint=K.Dim, X=textX, Y=infoTop+34, Text=K.String("NoSong") }

af[#af+1] = K.Text{ Px=11, Tint=K.Dim, X=textX, Y=infoTop+124, Text=K.String("Artist") }
af[#af+1] = K.Text{ Name="Artist", Role="Display", Px=26, Tint=K.Ink, X=textX, Y=infoTop+152 }

af[#af+1] = K.Text{ Px=11, Tint=K.Dim, X=textX, Y=infoTop+204, Text=K.String("Bpm") }
af[#af+1] = K.Text{ Name="Bpm", Role="Display", Px=30, Tint=K.Ink, X=textX, Y=infoTop+234 }
af[#af+1] = K.Text{ Px=11, Tint=K.Dim, X=textX+240, Y=infoTop+204, Text=K.String("Length") }
af[#af+1] = K.Text{ Name="Length", Role="Display", Px=30, Tint=K.Ink, X=textX+240, Y=infoTop+234 }

af[#af+1] = K.Rule{ Name="Divider", X=40, Y=infoTop+artSize+22, Width=920, Height=1 }

return af
