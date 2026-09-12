-- The SortMenu's context panel.
--
-- Whatever the cursor is on, this column answers the same two questions: what
-- choosing it would produce, and what the player has selected right now.  The
-- top band is either a list preview -- the packs a sort would group into, the
-- options a category holds -- or, when there is no list to show, a short
-- details block.  The bottom band never changes shape, so the current
-- selection stays in one place as the cursor moves.

local L = ...

local Panel = {}

local cardNameWidth = L.PanelW - L.PanelInset*2 - 110

function Panel.Build()
	local af = Def.ActorFrame{Name="ContextPanel"}

	af[#af+1] = L.LabelText{Name="Heading", Px=13, X=L.PanelX, Y=L.ContentTop + 12, Tint=L.Dim}

	for index = 1, L.MaxCards do
		local y = L.PreviewTop + (index-1)*(L.CardH + L.CardGap)
		local card = Def.ActorFrame{
			Name = "Card"..index,
			InitCommand=function(self) self:xy(L.PanelX, y) end,
		}
		card[#card+1] = Def.Quad{
			Name="Fill",
			InitCommand=function(self)
				self:align(0,0):zoomto(L.PanelW, L.CardH):diffuse(L.Panel)
			end,
		}
		card[#card+1] = Def.Quad{
			Name="Edge",
			InitCommand=function(self)
				self:align(0,0):zoomto(3, L.CardH):diffuse(L.Line)
			end,
		}
		card[#card+1] = L.DisplayText{
			Name="Name", Px=20, X=L.PanelInset, Y=L.CardH/2, Tint=L.Mute, Width=cardNameWidth,
		}
		card[#card+1] = L.LabelText{
			Name="Value", Px=13, X=L.PanelW - L.PanelInset, Y=L.CardH/2, Tint=L.Dim, Align=right, Width=100,
		}
		af[#af+1] = card
	end

	for index = 1, L.MaxDetails do
		local y = L.PreviewTop + (index-1)*L.DetailPitch
		local detail = Def.ActorFrame{
			Name = "Detail"..index,
			InitCommand=function(self) self:xy(L.PanelX, y) end,
		}
		detail[#detail+1] = L.LabelText{Name="Label", Px=12, X=0, Y=10, Tint=L.Dim, Width=L.PanelW}
		detail[#detail+1] = L.DisplayText{Name="Value", Px=20, X=0, Y=44, Tint=L.Mute, Width=L.PanelW}
		detail[#detail+1] = L.Rule{
			Name="Rule", X=0, Y=L.DetailPitch-12, Width=L.PanelW, Height=1, Alpha=0.5,
		}
		af[#af+1] = detail
	end

	af[#af+1] = L.Rule{Name="SelectionRule", X=L.PanelX, Y=L.SelectionTop, Width=L.PanelW, Height=1}
	af[#af+1] = L.LabelText{Name="SelectionHeading", Px=13, X=L.PanelX, Y=L.SelectionTop + 30, Tint=L.Dim}
	af[#af+1] = L.DisplayText{Name="SelectionTitle", Px=26, X=L.PanelX, Y=L.SelectionTop + 74, Tint=L.Ink, Width=L.PanelW}
	af[#af+1] = L.DisplayText{Name="SelectionNote", Px=15, X=L.PanelX, Y=L.SelectionTop + 106, Tint=L.Dim, Width=L.PanelW}

	return af
end

-- What the wheel is sitting on, named the way the header behind this overlay
-- names it: the chart's level in brackets, then the title.
local function currentSelection()
	if GAMESTATE:IsCourseMode() then
		local course = GAMESTATE:GetCurrentCourse()
		if course then return course:GetDisplayFullTitle() end
		return nil
	end

	local song = GAMESTATE:GetCurrentSong()
	if not song then return nil end

	local title = song:GetDisplayFullTitle()
	local player = GAMESTATE:GetMasterPlayerNumber() or PLAYER_1
	local chart = GAMESTATE:GetCurrentSteps(player)
	if not chart and player ~= PLAYER_1 then chart = GAMESTATE:GetCurrentSteps(PLAYER_1) end
	local meter = chart and tonumber(chart:GetMeter()) or nil
	if meter then
		return ("[%02d] %s"):format(meter, title)
	end
	return title
end

function Panel.Apply(af, descriptor)
	if not af then return end

	local preview = descriptor and descriptor.Preview or nil
	local details = (not preview) and descriptor and descriptor.Details or nil

	local heading = af:GetChild("Heading")
	if preview then
		local text = L.String(preview.Heading or "SortMenuPreview")
		if preview.Total and preview.Total > #preview.Items then
			text = text .. "  " .. L.Dot .. "  " .. ("%d/%d"):format(#preview.Items, preview.Total)
		end
		L.SetLabel(heading, text, 13, L.PanelW)
	elseif details then
		L.SetLabel(heading, L.String("SortMenuDetails"), 13, L.PanelW)
	else
		L.SetLabel(heading, "", 13, L.PanelW)
	end

	for index = 1, L.MaxCards do
		local card = af:GetChild("Card"..index)
		local item = preview and preview.Items[index] or nil
		card:visible(item ~= nil)
		if item then
			local name = card:GetChild("Name")
			local value = card:GetChild("Value")
			L.SetDisplay(name, L.Upper(item.Name or ""), 20, cardNameWidth)
			L.SetLabel(value, item.Value ~= nil and tostring(item.Value) or "", 13, 100)
			if item.Active then
				card:GetChild("Fill"):diffuse(L.Panel2)
				card:GetChild("Edge"):diffuse(L.Accent)
				name:diffuse(L.Ink)
				value:diffuse(L.Accent)
			else
				card:GetChild("Fill"):diffuse(L.Panel)
				card:GetChild("Edge"):diffuse(L.Line)
				name:diffuse(L.Mute)
				value:diffuse(L.Dim)
			end
		end
	end

	for index = 1, L.MaxDetails do
		local detail = af:GetChild("Detail"..index)
		local entry = details and details[index] or nil
		detail:visible(entry ~= nil)
		if entry then
			L.SetLabel(detail:GetChild("Label"), entry.Label or "", 12, L.PanelW)
			L.SetDisplay(detail:GetChild("Value"), entry.Value or L.Dash, 20, L.PanelW)
		end
	end

	L.SetLabel(af:GetChild("SelectionHeading"), L.String("SortMenuCurrent"), 13, L.PanelW)

	local selection = currentSelection()
	L.SetDisplay(af:GetChild("SelectionTitle"),
		selection and L.Upper(selection) or L.String("SortMenuNoSelection"), 26, L.PanelW)
	af:GetChild("SelectionTitle"):diffuse(selection and L.Ink or L.Dim)

	local note = descriptor and descriptor.SelectionNote or "SortMenuKeepSelection"
	L.SetDisplay(af:GetChild("SelectionNote"), L.String(note), 15, L.PanelW)
end

return Panel
