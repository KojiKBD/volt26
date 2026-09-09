-- VOLT26 typography.
--
-- Two roles carry the interface: a condensed display face for names and numbers
-- and a letter-spaced uppercase face for the labels that describe them.  Both
-- are addressed in the design's own pixel sizes, and the zoom that reaches a
-- given size is derived from the face's metrics rather than guessed per screen.

VOLT26.Type = {
	Display = "Common Normal",
	Label = "VOLT26 Label",
}

-- Miso's ascent is 15 units of a 20-unit em; Wendy's cap height is 37 units of
-- a 53-unit em.
function VOLT26.Type.DisplayZoom(px) return px/20 end
function VOLT26.Type.LabelZoom(px) return px/53 end

local labelFace, displayFace

local function faces()
	if not labelFace then
		labelFace = THEME:GetPathF("", VOLT26.Type.Label)
		displayFace = THEME:GetPathF("", VOLT26.Type.Display)
	end
	return labelFace, displayFace
end

-- The label face carries Latin-1 and Cyrillic only, so a string outside that --
-- a CJK song title, a pack named in Greek -- is set in the display face
-- instead.  LoadFromFont reloads the face, so each actor remembers the one it
-- already carries rather than reloading on every refresh.
local function labelFaceCovers(text)
	return tostring(text or ""):find("[\128-\255]") == nil
end

-- Sets a label to `text` at the design's pixel size, optionally capping it to
-- `width` pixels, and returns the zoom it settled on.
function VOLT26.Type.SetLabel(actor, text, px, width)
	text = tostring(text or "")
	local label, display = faces()
	local face = labelFaceCovers(text) and label or display
	if actor.VOLT26Face ~= face then
		actor:LoadFromFont(face)
		actor.VOLT26Face = face
	end
	local zoom = face == label and VOLT26.Type.LabelZoom(px) or VOLT26.Type.DisplayZoom(px)
	actor:settext(text):zoom(zoom)
	if width then actor:maxwidth(width/zoom) end
	return zoom
end

function VOLT26.Type.SetDisplay(actor, text, px, width)
	local zoom = VOLT26.Type.DisplayZoom(px)
	actor:settext(tostring(text or "")):zoom(zoom)
	if width then actor:maxwidth(width/zoom) end
	return zoom
end
