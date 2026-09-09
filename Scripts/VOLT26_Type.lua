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

-- Each face declares its own em in font units, so both helpers take the design's
-- pixel size and land on it: Miso's ascent is 15 units of a 20-unit em,
-- Helvetica Bold's is 26 units of a 36-unit em.  An actor's face is fixed when
-- it is built: the engine does not expose LoadFromFont to Lua, and it
-- substitutes nothing for a glyph a font lacks.
--
-- The two roles split on resolution.  Helvetica is stored at its native size, so
-- it is crisp drawn small and soft drawn large; Miso declares a fifth of the
-- resolution it actually carries, so it survives being drawn large.  Labels are
-- always small and titles are always large, which is exactly that split.
--
-- The design's smallest labels assume a hinted vector face that stays legible at
-- nine pixels.  A bitmap face does not, so anything under the floor is lifted to
-- it -- but a bold grotesque needs less of a floor than a light condensed one
-- did, which buys back a step of hierarchy.
local labelFloor = 11

function VOLT26.Type.DisplayZoom(px) return px/20 end
function VOLT26.Type.LabelZoom(px) return math.max(px, labelFloor)/36 end

local function setText(actor, text, zoom, width)
	actor:settext(tostring(text or "")):zoom(zoom)
	if width then actor:maxwidth(width/zoom) end
	return zoom
end

-- Both take the design's pixel size, optionally cap the result to `width`
-- pixels, and return the zoom they settled on.
function VOLT26.Type.SetLabel(actor, text, px, width)
	return setText(actor, text, VOLT26.Type.LabelZoom(px), width)
end

function VOLT26.Type.SetDisplay(actor, text, px, width)
	return setText(actor, text, VOLT26.Type.DisplayZoom(px), width)
end
