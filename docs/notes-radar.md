# Notes radar (Song Select)

The notes radar in each player column of Song Select is the owner's
Illustrator star artwork, kept as drawn.

## What draws what

| Part | Source |
| --- | --- |
| Axis readings | `VOLT26.ChartRadar` (`Scripts/VOLT26_ChartRadar.lua`): five axes, clockwise from the top point — STREAM, XOVER, FOOTSWITCH, BRACKETS, SIDESWITCH. JACK is not on the star. |
| Dark star + glow | `Graphics/VOLT26/SongSelection/NotesRadar/backdrop.png`, rendered from the artwork. It is the owner's star exactly, not a regular one. |
| Axis names + icons | `Graphics/VOLT26/SongSelection/NotesRadar/labels.png`, rendered from the artwork. Without it the axes fall back to plain text labels and the star shrinks to leave room for them. |
| Orange star (the reading) | Drawn in `BGAnimations/ScreenSelectMusic overlay/VOLT26/PlayerColumn.lua`. Point *i* sits at `Scaled_i` × the dark star's own point *i*; each valley at the mean of its two points × the dark star's own valley (`VOLT26.ChartRadar.StarRadii(axes, 1)`). A chart full on every axis therefore fills the dark star exactly. Each point is two triangles, shaded on its anticlockwise side and lit on its clockwise side, with a dotted seam from the centre to the point, as in the artwork. |
| Star geometry | `BGAnimations/ScreenSelectMusic overlay/VOLT26/RadarArt.lua` (generated): the dark star's points and valleys and the pictures' reach, in radar radii. |

Both pictures are 1024 × 1024, centred on the orange star's centre in the
artwork, 300 px to one radar radius (the mean distance of the dark star's
points). A new chart's orange star grows from 82 % to full in 0.16 s.

## Rebuilding from Illustrator

1. Get the artwork as SVG in `tools/notes-radar/art/radar.svg`: either save
   the document there as SVG, or run `tools/notes-radar/export_radar_art.jsx`
   (File > Scripts > Other Script...), which copies the items into a scratch
   document, exports it and closes it without saving, leaving the open
   document alone.
2. Run `python tools/notes-radar/build_radar_art.py` (cairosvg, lxml, numpy,
   Pillow). It writes `backdrop.png`, `labels.png` and `RadarArt.lua`.

The script picks the radar's elements by their top-level position in the SVG
and holds the dark star's anchors and the orange star's centre as constants.
If the artwork's structure or the star changes, update `BACKDROP_ELEMENTS`,
`LABEL_ELEMENTS`, `CENTRE`, `TIPS` and `VALLEYS` there. `art/` holds the
whole document (~6 MB) and is not meant for the repository.

## Verification status

Lua 5.1 syntax checks of the changed files; a harness running the real
`ChartRadar` module and the real `starVertices`/`seamVertices` code with the
generated `RadarArt.lua` outside the engine (a full chart lands exactly on the
dark star's points and valleys; radius fit for versus 320×158 → 88 and solo
320×368 → 137); and an offline preview. Not yet verified in ITGmania:
rendering of the triangle/quad `ActorMultiVertex` modes, the two sprites, and
the grow tween.
