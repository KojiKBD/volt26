-- The SortMenu's header and footer.
--
-- The header says where the player is and what is in force; the footer says
-- what the three buttons do and what the one in their hand would do right now.
-- Both are laid out from the screen edges inwards so a long title or a long
-- verb changes the text rather than the frame.

local L = ...

local Chrome = {}

local accentBarW = 7
local keyGap = 10
local itemGap = 34
local buttonH = 46
local buttonPadX = 28

-- The label face carries no arrow glyphs, and the design asks for shapes over
-- icon bitmaps anyway, so the scroll hint is drawn.
local arrowSpan = 6
local arrowHalf = 5
local arrowGap = 3

local function arrowVertices()
	local tint = {L.Accent[1], L.Accent[2], L.Accent[3], 1}
	local vertices = {}
	local function triangle(ax, ay, bx, by, cx, cy)
		vertices[#vertices+1] = {{ax,ay,0}, tint}
		vertices[#vertices+1] = {{bx,by,0}, tint}
		vertices[#vertices+1] = {{cx,cy,0}, tint}
	end
	local offset = arrowSpan/2 + arrowGap/2
	triangle(0, -offset-arrowSpan, -arrowHalf, -offset, arrowHalf, -offset)
	triangle(0, offset+arrowSpan, -arrowHalf, offset, arrowHalf, offset)
	return vertices
end

-- Key, caption: the caption is a string key resolved at refresh so a language
-- change does not need a rebuild.
local hints = {
	{Arrows=true,   Caption="SortMenuScroll"},
	{Key="SELECT",  Caption="SortMenuApply"},
	{Key="BACK",    Caption="SortMenuClose"},
}

function Chrome.Build()
	local af = Def.ActorFrame{Name="Chrome"}

	------------------------------------------------------------
	-- Header.

	af[#af+1] = Def.Quad{
		Name="HeaderWash",
		InitCommand=function(self)
			self:align(0,0):zoomto(L.W, L.HeaderH)
			L.WashX(self, L.Deep, L.Bg)
		end,
	}
	af[#af+1] = L.Rule{Name="HeaderRule", X=0, Y=L.HeaderH, Width=L.W, Height=1}
	af[#af+1] = Def.Quad{
		Name="AccentBar",
		InitCommand=function(self)
			self:align(0,0.5):xy(L.Pad, 78):zoomto(accentBarW, 62):diffuse(L.Accent)
		end,
	}
	af[#af+1] = L.LabelText{Name="Kicker", Px=13, X=L.Pad + accentBarW + 14, Y=54, Tint=L.Dim}
	af[#af+1] = L.DisplayText{Name="Title", Px=46, X=L.Pad + accentBarW + 12, Y=100, Tint=L.Ink, Width=900}
	af[#af+1] = L.LabelText{Name="ActiveLabel", Px=13, X=L.W - L.Pad, Y=54, Tint=L.Dim, Align=right}
	af[#af+1] = L.DisplayText{Name="ActiveValue", Px=30, X=L.W - L.Pad, Y=100, Tint=L.Accent, Align=right, Width=700}

	------------------------------------------------------------
	-- Footer.

	af[#af+1] = L.Rule{Name="FooterRule", X=0, Y=L.FooterTop, Width=L.W, Height=1}

	for index, hint in ipairs(hints) do
		af[#af+1] = Def.ActorMultiVertex{
			Name="Arrows"..index,
			InitCommand=function(self)
				local vertices = hint.Arrows and arrowVertices() or {}
				self:SetDrawState({Mode="DrawMode_Triangles"})
					:SetNumVertices(#vertices):SetVertices(vertices)
					:y(L.FooterMid):visible(false)
			end,
		}
		af[#af+1] = L.LabelText{Name="Key"..index, Px=13, Y=L.FooterMid, Tint=L.Accent}
		af[#af+1] = L.LabelText{Name="Caption"..index, Px=13, Y=L.FooterMid, Tint=L.Mute}
	end

	af[#af+1] = L.LabelText{Name="PageCount", Px=12, Y=L.FooterMid, Tint=L.Dim, Align=right}

	af[#af+1] = Def.Quad{
		Name="ButtonFill",
		InitCommand=function(self)
			self:align(1,0.5):xy(L.W - L.Pad, L.FooterMid):zoomto(240, buttonH):diffuse(L.Accent)
		end,
	}
	af[#af+1] = L.DisplayText{Name="ButtonLabel", Px=20, Y=L.FooterMid, Tint=L.Ink, Align=center}

	return af
end

-- state: {Title=..., Active=..., Action=<string key>, Enabled=bool,
--         Page=n, Pages=n}
function Chrome.Apply(af, state)
	if not af then return end

	L.SetLabel(af:GetChild("Kicker"), L.String("SortMenuMenu"), 13)
	L.SetDisplay(af:GetChild("Title"), L.Upper(state.Title or ""), 46, 900)
	L.SetLabel(af:GetChild("ActiveLabel"), L.String("SortMenuActiveSort"), 13)
	L.SetDisplay(af:GetChild("ActiveValue"), L.Upper(state.Active or L.Dash), 30, 700)

	-- Hints are laid out left to right, each one measured after it is written so
	-- a translated caption cannot overlap the next hint.
	local x = L.Pad
	for index, hint in ipairs(hints) do
		local arrows = af:GetChild("Arrows"..index)
		local key = af:GetChild("Key"..index)
		local caption = af:GetChild("Caption"..index)

		local width
		if hint.Arrows then
			arrows:visible(true):x(x + arrowHalf)
			key:visible(false)
			width = arrowHalf*2
		else
			arrows:visible(false)
			key:visible(true)
			L.SetLabel(key, hint.Key, 13)
			key:x(x)
			width = key:GetZoomedWidth()
		end

		L.SetLabel(caption, L.String(hint.Caption), 13)
		caption:x(x + width + keyGap)
		x = x + width + keyGap + caption:GetZoomedWidth() + itemGap
	end

	-- The right of the band is laid out from the screen edge inwards, so the
	-- action button keeps its place whatever the verb costs.
	local label = af:GetChild("ButtonLabel")
	local fill = af:GetChild("ButtonFill")
	local enabled = state.Enabled ~= false

	L.SetDisplay(label, L.Upper(L.String(state.Action or "SortMenuActivate")), 20, 420)
	local width = label:GetZoomedWidth() + buttonPadX*2
	local right = L.W - L.Pad
	fill:zoomto(width, buttonH):diffuse(enabled and L.Accent or L.Panel2)
	label:xy(right - width/2, L.FooterMid):diffuse(enabled and L.Ink or L.Dim)
	right = right - width - itemGap

	local page = af:GetChild("PageCount")
	if (state.Pages or 1) > 1 then
		page:visible(true):x(right)
		L.SetLabel(page, ("%s %d/%d"):format(L.String("SortMenuPage"), state.Page or 1, state.Pages), 12)
	else
		page:visible(false)
	end
end

return Chrome
