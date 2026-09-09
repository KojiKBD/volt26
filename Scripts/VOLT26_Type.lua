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

-- The label face is the display face's pages with a wider advance, so both
-- share one metric: an ascent of 15 units in a 20-unit em.  An actor's face is
-- fixed when it is built -- the engine does not expose LoadFromFont to Lua, and
-- it substitutes nothing for a glyph a font lacks -- which is exactly why the
-- two faces are built from the same pages: any string one can set, the other
-- can too.
function VOLT26.Type.DisplayZoom(px) return px/20 end
function VOLT26.Type.LabelZoom(px) return px/20 end

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
