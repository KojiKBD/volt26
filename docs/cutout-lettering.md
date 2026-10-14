# Cutout lettering

`VOLT26.Cutout` (`Scripts/VOLT26_Cutout.lua`) draws a runtime string in the
Persona 5 menu style: a different face per letter, tilted letters of mixed
sizes, white on one merged black backing, and some letters inverted inside a
box.

Since 2026-10-15 (`codex/static-cutout-font`) the look is **baked into bitmap
fonts**. Every character was given its face, size, tilt, baseline offset and
box once, offline, so a letter always looks the same wherever it appears (it
used to be chosen per string, seeded with the string). In exchange nothing is
rendered at runtime: no render textures, no texture cache, no startup
warm-up, and a string shows on the frame it is set.

## Where it is used

The credit line (`BGAnimations/ScreenSystemLayer overlay.lua`, on the screens
in `VOLT26.Cutout.Screens` and the ones it always applies to), profile names
(ScreenSelectProfile), pack names and section tiles (ScreenVOLT26SelectPack),
the song wheel's pack, player names, length and grade (ScreenSelectMusic,
`SongWheel/P5.lua`), the WANTED page's name, grade and page titles, the
end-of-session titles, the Free Play / Pay join prompt and the menu timer.
Slot sizes live in `VOLT26.Cutout.StyleDesign` (`Scripts/VOLT26_CutoutStyles.lua`).

## How it works

* **Fonts.** `Fonts/Cutout Back` (the backings: each letter grown by the
  outline plus a drop shadow; a boxed letter's box grown) and `Fonts/Cutout
  Ink` (the white letters; a boxed letter is a white box with the letter cut
  out in black) share one layout. A slot draws the same string with Back, then
  Ink, so every backing lies under every letter and neighbouring backings
  merge. Each glyph's cell holds its whole drawing; the ini draws the full
  cell (`DrawExtraPixelsLeft/Right` = half a cell), and the advance is the
  letter's own spacing.
* **Large fonts.** `Cutout Back Large` / `Cutout Ink Large` carry the grade
  letters (S A B C D F Q + -) at a 160 px em with the same looks; a slot uses
  them when its letters would be drawn more than 1.3 times the regular 56 px em
  on the display and the string only has those characters.
* **Layout.** `VOLT26.Cutout.Layout(text, opts)` is pure data from the baked
  metrics (`Scripts/VOLT26_CutoutMetrics.lua`): the drawn string (case
  applied), its advance width and its bounds with the block's tilt. Callers use
  it to know how wide a string will be (profile wings, song wheel badges).
* **Slot.** `VOLT26.Cutout.CreateSlot(params)` is two BitmapTexts in a tilted
  frame, scaled down (never up) to fit `maxW` x `maxH` and aligned by
  `halign` / `valign` on the drawn bounds. A string with a character the fonts
  do not have, or longer than `maxChars`, falls back to plain text
  (`fallbackFont`).

## Options

| Key | Default | Meaning |
| --- | --- | --- |
| `base` | 22 | letter size (em) in theme units |
| `upperChance` | 0.5 | 1: every letter upper case (grades), 0: lower case, otherwise the case as typed |
| `tiltDeg` | -5 | rotation of the whole block |
| `fg`, `bk` | white, black | letter and backing colours (BitmapText diffuse; a box takes `fg`) |

The per-letter look (faces, size range, box chance, tilts, outline) is set in
`tools/cutout-fonts/generate.py` and needs the fonts regenerated; `SEED` there
re-rolls every letter.

`CreateSlot` also takes `held` (set a string without showing it until
`CutoutHold{held=false}`) and `onReady(slot)` (called on the update after a
string is set). Commands: `CutoutSet{text=...}`, `CutoutHold{held=...}`.

## Regenerating

```
python tools/cutout-fonts/generate.py --src <dir with the .ttf files>
```

The six SIL OFL faces (Tinos Bold, Caprasimo, League Spartan, Besley, Jost,
Archivo; see `Fonts/Cutout/README.md` and the `OFL-*.txt` licences) come from
the google/fonts repository (`ofl/<family>/`). Requires Pillow, fontTools,
numpy and scipy. It writes the pages and inis in `Fonts/Cutout`, the four
`.redir` files and `Scripts/VOLT26_CutoutMetrics.lua`.

Video memory: the regular fonts are three pages of about 1020x928 each per
layer, the large ones one 940x416 page per layer, about 28 MB in all once
padded to powers of two (the six old per-face pages were 24 MB, plus the
render caches).

## Leftovers from the runtime renderer

Some screens still carry workarounds that were only needed while strings were
rendered into textures; they are harmless and can be simplified later:
ScreenSelectProfile's two alternating name slots, and the song wheel's slots
living in the background (`P.CutoutHost`) and shown through ActorProxies,
which existed because a slot only rendered while every ancestor was opaque and
still.

## Verification status

Offline only: Lua syntax, `Layout` run against the generated metrics, and a
preview that composes the font pages as ITGmania's BitmapText does (cells
centred on the advance, whole cell drawn) at the slot sizes of
`CutoutStyles.lua`. Not yet checked in ITGmania: the baseline of the letters
(BitmapText bottom alignment, as the old renderer assumed), the multi-page
fonts loading, and every screen that shows cutout lettering.
