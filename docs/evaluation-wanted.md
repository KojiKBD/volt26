# Stage evaluation: the WANTED page

`ScreenEvaluationStage` (and `ScreenEvaluationNonstop`, which redirects to it)
opens on the owner's Persona-style "WANTED" page, drawn from the Illustrator
artwork.

## What draws what

| Part | Source |
| --- | --- |
| White ground, shaded star pattern, black curve, red top band, black frame, "WANTED" | `Graphics/VOLT26/Wanted/backdrop.png`, drawn by `BGAnimations/ScreenEvaluationStage background.lua`. Shared by both players. The band and the stars come from the owner's own Illustrator export (`bg_wanted.png`), since the SVG loses the band's picture and the stars' shading. The band is a fixed picture, not the song's. |
| Song background in the frame's spiky window | `overlay/Wanted/Picture.lua`, in the background layer. A textured `ActorMultiVertex` on the window polygon, turned -10.5° and covering the window at the picture's own aspect. The artwork's red overlay (#f11600, hard light, 70 %) is reproduced exactly: picture × (0.377, 0.421, 0.300) plus (0.623, 0, 0) added. Movie backgrounds fall back to the jacket or banner. Without any picture the window is the overlay on black. |
| Plates (name, level, scores) | `Graphics/VOLT26/Wanted/panel_head.png` |
| Judgment ladder, holds box | `Graphics/VOLT26/Wanted/panel_body.png` |
| Graph frame (shared by every page but QR; does not turn with the pages) | `Graphics/VOLT26/Wanted/panel_graph.png` |
| All text, the level, the scores, the counts | `overlay/Wanted/Side.lua` through `overlay/Wanted/Text.lua`, at the artwork's text anchors (position, rotation, horizontal scale). |
| Player name, letter grade | Cutout lettering (`VOLT26.Cutout`), styles `EvalName` and `EvalGrade` in `Scripts/VOLT26_CutoutStyles.lua`; warmed at startup. Star grades (Tier00-04) use the grade star picture. |
| Graph | `overlay/Wanted/Graph.lua` |
| Song title | `overlay/default.lua`, along the frame's bottom edge, centred on the artwork's title. A title longer than 1100 px scrolls as a marquee (two copies, clipped at the band's ends by z-buffer masks). |
| Song name plate | `overlay/Wanted/SongName.lua`: the owner's `songname.svg` rendered 1:1 to `Graphics/VOLT26/Wanted/songname.png`, under "WANTED" (centre 1013,156, placed from the owner's Illustrator screenshot), with the song's name (course: full title) in Helvetica Bold, black, about 2° along the plate's slope, squeezed past 440 px. One plate for one or two players, drawn over the sides. |
| Data | `VOLT26.EvaluationPage` (`Scripts/VOLT26_EvaluationPage.lua`): `GetCard(player)` and `GetGraph(player)`. No actors. |

All drawing is in artboard pixels (1920x1080) under one frame zoomed to the
screen height and centred. The cutout lettering is in theme units.

### Player 2

The page is the same for two players. Player 2's plates are player 1's
pictures flipped and placed in mirror. Player 2's text sits at the mirrored
anchors, turned the other way, still reads left to right, and ends where
player 1's starts. Player 2's graph frame is mirrored too, but the song still
runs left to right. Player 2's side covers part of the window and the title,
as agreed. A single player is always on the left, whichever side they
joined on.

### The graph

The graph is Simply Love's end-of-song graph, drawn in perspective in the
slanted frame. Each point (u along the song, v from the bottom) is placed by
bilinear interpolation between the frame's four corners. It shows:

- the chart's density per measure, as a profile with a gradient (dark at the
  bottom, bright at the peaks) and a light edge: red on player 1's side,
  always blue on player 2's;
- the on-time line, where the artwork has its white line;
- the judgment scatter plot, in the page's judgment colours, with misses as
  faint red lines across the graph;
- the life line, sampled from the engine's life record over the steps;
- for a fail, a red line at the point of failure and the time that was left.

A course shades every other song.

The frame runs off the bottom of the screen on the left, as drawn, so the low
part of the profile is cut there.

### Fonts

ITGmania cannot rasterise TrueType, so the faces are baked into bitmap fonts
by `tools/evaluation/build_fonts.py`. The fonts are in `Fonts/VOLT26 Eval/` (SIL OFL;
the licences are alongside):

| Font | Stand-in | For |
| --- | --- | --- |
| `VOLT26 Eval Title` | Tinos Bold, em 78 | Times New Roman Bold (title) |
| `VOLT26 Eval Label` | Archivo 500, em 48 | Helvetica Now Display Medium |
| `VOLT26 Eval Bold` | Archivo 700, em 48 | Helvetica Now Display Bold |
| `VOLT26 Eval Score` | Archivo Italic 900, em 96 | Helvetica Now Display Black Italic |

Tinos has the same metrics as Times New Roman. Times New Roman itself is not
redistributable. A title with characters the title face lacks (for example
CJK) is drawn in `Common Normal`. Archivo is wider than Helvetica Now Display,
so the level digits and the score lines are held to the artwork's widths.

## Pages

Each side turns through four pages with MenuLeft / MenuRight, wrapping round
(`VOLT26.EvaluationPage.Pages`). The plates (name, level, modifiers, scores)
stay on every page.

| Page | Body | Content |
| --- | --- | --- |
| `wanted` | `panel_body.png` | Judgment ladder, holds/mines/rolls, grade (above). |
| `notes` | `panel_notes.png` (the NOTES artboard's container) | `Wanted/Notes.lua`: Simply Love's per-column pane. The player's noteskin arrows (`_modules/NoteSkinPreview.lua`) head the columns; the seven judgments are rows in their colours, each column's counts in the row's colour. The 10/15 ms Fantastic is split per column only with the FA+ window and pane on (that is when gameplay records it); otherwise its row shows a dash. |
| `timing` | `panel_notes.png` | `Wanted/Timing.lua`: Simply Love's offset pane. An offset histogram (early left, late right, bars in their windows' colours, windows' edges marked), early / late / miss counts, mean, standard deviation and largest error. |
| `qr` | `panel_qr.png` (the QR artboard's boxes and bolt) | `Wanted/Qr.lua`: Simply Love's GrooveStats QR code (`Pane7/GrooveStatsURL.lua`), white on black as drawn. A play GrooveStats would not take shows why; an automatic submission replaces the code with "already submitted". GS BEST is the chart's GrooveStats leaderboard, from the `VOLT26GrooveStatsLeaderboard` message that `Shared/AutoSubmitScore.lua` now sends. MACHINE BEST is the machine's best scores, with this play highlighted. |

The graph is drawn on every page except `qr`. The NOTES and Qr titles are the owner's own pictures (`label_notes.png`, `label_qr.png`, cropped from `tools/evaluation/labels/`, which the artwork links from outside the SVG), placed where the artwork has them and never flipped for player 2. TIMING, which the artwork lacks, is cutout lettering (style `EvalLabel`) where NOTES has its title.

Input: `BGAnimations/ScreenEvaluation common/PageInputHandler.lua`, loaded
instead of `InputHandler.lua` when the common evaluation is loaded with
`{WantedPage=true}`.

- With two players, each controller turns its own side.
- With one player, the page is always on the left, and either controller
  turns it.
- Every change is broadcast as `VOLT26EvaluationPage {Side, Page, Count}`.

The inherited Simply Love panes stay loaded, because the GrooveStats
submission writes into them, but they are never shown.

`VOLT26EvaluationSequenceFinished` is still broadcast, 0.4 s after the page
opens, for the modules that waited for the old result sequence (for example
the five-star cat).

The judgment rows beside the holds box are held short of its left edge
(`rows[i].width` in `Art.lua`, measured on the box's outline). The credit
line's player names (ScreenSystemLayer) are not shown on this screen; the
plates name the players.

## Rebuilding from Illustrator

The SVG export loses the raster images (its linked files come out
misnumbered) and the star pattern's shading. So the band and the stars are
also exported from Illustrator as a PNG at 1:1, any crop, holding only those
two: `tools/notes-radar/art/bg_wanted.png`. The build registers it against the
SVG's shapes automatically (99.9 % of pixels agree) and takes the band and the
stars from it.
`tools/evaluation/export_eval_art.jsx` can export the artboard from a document
that holds it, but the owner's export is what the build uses.

The plates, the anchors and the geometry still come from the SVG:

1. Export the Illustrator document as SVG to `tools/notes-radar/art/radar.svg`.
   This is the same document and export as the notes radar.
2. Run `python tools/evaluation/build_eval_art.py`. It needs Playwright with
   Chromium and lxml, plus the Tinos and Archivo fonts installed where
   Chromium finds them, with "Times New Roman" aliased to Tinos for "WANTED".
   With `--illustrator tools/notes-radar/art/bg_wanted.png` (the default), it
   writes the three pictures and the generated
   `overlay/Wanted/Art.lua`: the window polygon and its triangles, the graph
   quad, every text anchor, and the name and grade boxes.
3. To regenerate the fonts, run
   `python tools/evaluation/build_fonts.py --src <dir with Tinos-Bold.ttf, Archivo[wdth,wght].ttf, Archivo-Italic[wdth,wght].ttf>`.

The document holds several screens. The evaluation is the artboard at
(87.2, 2804), drawn by Layer_1's top-level items 428-442. If the artwork's
structure changes, update the constants at the top of `build_eval_art.py`.

`tools/evaluation/preview/preview.py` runs the real screen Lua under a mocked
engine (lupa) and renders the result. Its options include one or two players,
a fail, page 1, a long title and 854x480. This is how the layout was checked
outside the engine.

## Verification status

- Lua 5.1 syntax of every changed file.
- The offline preview of 1P and 2P, pass and fail, page 0 and page 1, at
  1920x1080 and 854x480, with and without a song picture. It renders the real
  Side/Graph/Text/Window/overlay code; the cutout lettering is stubbed as plain
  text.

Not yet run in ITGmania. Still to check in the engine:

- the bitmap fonts' baselines;
- `PlayerStageStats:GetLifeRecord` and the life line's alignment;
- the textured window on real backgrounds;
- the pane fitting on pages 1..n;
- cutout name and grade placement;
- course mode;
- the FA+ and Casual modes;
- Performance mode memory: the backdrop is a 2048x2048 texture after padding,
  plus the 2048x1024 title page.
