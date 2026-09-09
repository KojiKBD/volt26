local H = ...

-- Everything the songwheel needs that a recycled wheel row cannot own: the
-- sticky pack heading, the counter beside it, and the fades that keep the list
-- from ending on a hard edge.  The rows themselves draw the rail and the
-- highlight, in Graphics/VOLT26/SongSelection/MusicWheelItemNative.lua.

local headingY = H.InnerTop + 18
local listTop = H.WheelListTop
-- How far a heading travels while the next one pushes it out.  Kept short
-- enough that the outgoing label has faded out inside the padding strip the
-- cover quad owns, so it never reaches the song header band above it.
local pushSpan = 24
local fadeDepth = 40
local countX = H.WheelX + H.WheelW - 4
local transparent = color("0,0,0,0")

-- WheelItemBase:GetType answers with the raw enum value rather than its name,
-- and every one of its readers raises if the row has not been filled in yet.
local function sectionName(item)
	if not item:IsLoaded() then return nil end
	local name = WheelItemDataType[item:GetType() + 1]
	if name ~= "WheelItemDataType_Section" and name ~= "WheelItemDataType_ParentSection" then
		return nil
	end
	local text = item:GetText()
	return text ~= "" and text or nil
end

-- MusicWheel hands out its row actors by pool index, and the pool is as large as
-- the NumWheelItems metric.  Probing once is cheaper than guessing, and the
-- answer cannot change while the screen is up.
local poolSize

local function wheelPoolSize(wheel)
	-- A zero is the wheel answering before it has built its rows, so it is not
	-- worth remembering.
	if poolSize and poolSize > 0 then return poolSize end
	poolSize = 0
	for index = 0, 63 do
		if not pcall(function() return wheel:GetWheelItem(index) end) then break end
		poolSize = index + 1
	end
	return poolSize
end

-- The heading above the list is the pack whose own row has already scrolled past
-- the top; the one below it is the pack about to take over.  Reading both from
-- the live rows is what lets the handover follow the scroll instead of snapping
-- when the selection changes pack.
local function stickyPacks(wheel)
	local current, currentY = nil, -math.huge
	local incoming, incomingY = nil, math.huge
	for index = 0, wheelPoolSize(wheel)-1 do
		local ok, text, y = pcall(function()
			local item = wheel:GetWheelItem(index)
			return sectionName(item), item:GetY() + H.WheelCenterY
		end)
		if ok and text then
			if y <= listTop then
				if y > currentY then current, currentY = text, y end
			elseif y < incomingY then
				incoming, incomingY = text, y
			end
		end
	end
	return current, incoming, incomingY
end

local af = Def.ActorFrame{
	Name="Songwheel",
	OnCommand=function(self)
		self.pollElapsed = 0
		self:SetUpdateFunction(function(frame, delta)
			frame.pollElapsed = frame.pollElapsed + (delta or 0)
			if frame.pollElapsed < 1/30 then return end
			frame.pollElapsed = 0
			frame:playcommand("Track")
		end)
	end,
	TrackCommand=function(self)
		local wheel = H.Wheel()
		if not wheel then return end

		local current, incoming, incomingY = stickyPacks(wheel)
		-- Before the first pack header scrolls past the top there is nothing to
		-- stick, so the open pack stands in for it.
		if not current then current = H.Pack() end

		local offset = 0
		if incoming and incomingY < listTop + pushSpan then
			offset = math.min(pushSpan, listTop + pushSpan - incomingY)
		end
		local progress = offset/pushSpan

		local heading = self:GetChild("Heading")
		local nextHeading = self:GetChild("NextHeading")
		if current ~= self.currentPack then
			self.currentPack = current
			H.SetLabel(heading, tostring(current):upper(), 26, 360)
		end
		if incoming ~= self.incomingPack then
			self.incomingPack = incoming
			H.SetLabel(nextHeading, tostring(incoming or ""):upper(), 26, 360)
		end

		heading:y(headingY - offset):diffusealpha(1 - progress)
		nextHeading:visible(incoming ~= nil)
			:y(headingY + pushSpan - offset):diffusealpha(progress)

		local index, total = H.PackPosition()
		local count = total > 0 and string.format("%02d / %02d", index, total) or ""
		if count ~= self.countText then
			self.countText = count
			H.SetLabel(self:GetChild("Count"), count, 14)
		end
	end,
}

-- Rows scrolling into the heading and out of the bottom of the column dissolve
-- into the ground rather than being cut off.
af[#af+1] = Def.Quad{
	Name="TopFade",
	InitCommand=function(self)
		self:align(0,0):xy(H.WheelX, H.InnerTop):zoomto(H.WheelW, (listTop-H.InnerTop)+fadeDepth)
			:diffuse(H.Bg):diffusebottomedge(transparent)
	end,
}
af[#af+1] = Def.Quad{
	Name="BottomFade",
	InitCommand=function(self)
		self:align(0,1):xy(H.WheelX, H.InnerBottom):zoomto(H.WheelW, fadeDepth+18)
			:diffuse(H.Bg):diffusetopedge(transparent)
	end,
}

af[#af+1] = H.LabelText{Name="Heading", Px=26, Tint=H.Ink, X=H.WheelItemX, Y=headingY}
af[#af+1] = H.LabelText{Name="NextHeading", Px=26, Tint=H.Ink, X=H.WheelItemX, Y=headingY}
af[#af+1] = H.LabelText{Name="Count", Px=14, Tint=H.Mute, Align=right, X=countX, Y=headingY}

-- Hard edge for the push: the content block's own top padding, which the
-- outgoing heading fades out inside.
af[#af+1] = Def.Quad{
	Name="TopCover",
	InitCommand=function(self)
		self:align(0,0):xy(H.WheelX, H.ContentTop)
			:zoomto(H.WheelW, H.InnerTop-H.ContentTop):diffuse(H.Bg)
	end,
}

return af
