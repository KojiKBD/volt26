# Cutout lettering

`VOLT26.Cutout` (`Scripts/VOLT26_Cutout.lua`) draws a runtime string in the
Persona 5 menu style: a different face per letter, mixed case, tilted letters,
white on one merged black backing, and some letters inverted inside a box.

## Where it is used

`BGAnimations/ScreenSystemLayer overlay.lua` mirrors the two credit texts
("PRESS START", the profile or GrooveStats name) and the centre footer
("EVENT MODE") into cutout slots on the screens listed in
`VOLT26.Cutout.Screens` (currently only `ScreenTitleMenu`). The plain texts still
decide what is shown and when; on those screens they are only made transparent.
Add a screen name to `VOLT26.Cutout.Screens` to extend it.

## Tuning

`VOLT26.Cutout.Defaults` holds the look; every key can be overridden per slot
through `CreateSlot{ opts = {...} }`:

| Key | Default | Meaning |
| --- | --- | --- |
| `base` | 22 | letter size in theme units (the credit slots use 22, the footer 26) |
| `chaos` | 0.45 | scales baseline jitter and per-letter rotation |
| `boxChance` | 0.28 | chance a letter is inverted inside a box |
| `upperChance` | 0.68 | chance a letter is upper case (the typed case is ignored) |
| `sizeMin`, `sizeMax` | 0.82, 1.22 | per-letter size range, as fractions of `base` |
| `lowerBoost` | 1.08 | extra size for lower-case letters |
| `outline` | 0.11 | backing thickness, as a fraction of `base` |
| `tiltDeg` | -5 | rotation of the whole block |
| `fg`, `bk` | white, black | face and backing colours |

Slot geometry (`maxW`, `maxH`, `halign`, `valign`, position) is set where the
slot is created; the lettering is scaled down to fit and never up.

## How it works

* `VOLT26.Cutout.Layout(text, opts)` is pure data: letters, faces, sizes and
  bounds. The generator is seeded with a hash of the string, so the same name
  always gets the same lettering. It cannot match the browser prototype letter
  for letter (Lua 5.1 has no bit operations, so the PRNG differs).
* `VOLT26.Cutout.CreateSlot(params)` renders a layout once into an
  `ActorFrameTexture` and shows it as a sprite drawn at display resolution.
  The backing is built by stamping the black letters around a circle (16
  directions plus centre, for the letter and for the drop shadow). The letters
  are laid out once per pass and stamped at every offset through
  `ActorProxy`s, so a string takes three texture frames (centre backing, ring
  backing, letters) the first time it appears and nothing afterwards. (It used
  to take one frame per stamp, 35 in all: about 0.6 s at 60 Hz, during which a
  new name was invisible.) Eight directions left serrated edges. The texture is
  redrawn only when the slot receives a different string.
* A string with a character no face has, or longer than `maxChars` (16), falls
  back to plain text.

## Slot options

Besides geometry, `CreateSlot` takes `held` (render without showing until a
`CutoutHold{held=false}` command) and `onReady(slot)` (called when a string has
finished rendering or fallen back to plain text). ScreenSelectProfile uses two
held slots per side and swaps them in `onReady`, so a name stays on screen
while the next one renders. Slots render only while they and all their
ancestors are visible and fully opaque, because a parent's alpha would be baked
into the texture.

## Texture cache and startup warm-up

`VOLT26.Cutout.Cache` (`Scripts/VOLT26_CutoutCache.lua`) keeps rendered
strings for the whole session, so a string that comes back (a pack name when
scrolling back, a profile name on the next screen) appears at once instead of
after three invisible frames.

* **Host.** `Cache.CreateHost()` is placed in `ScreenSystemLayer overlay.lua`,
  which outlasts every screen. It owns one stamper sized for 64 letters (so the
  six cutout faces stay loaded all session) and up to four 2048x1024 page
  textures (two in Performance mode), each created only when first needed
  (8 MB of video memory per page). Strings are packed into pages in shelves.
* **Slots.** `CreateSlot` asks the cache first (`Cache.Acquire`). A cached
  string is shown at once as a cropped region of its page; a new one is
  rendered by the host in three frames (one pass per frame, a slot's request
  ahead of the warm-up queue). The slot renders on its own only when the cache
  cannot take the string (no host, over 64 letters, larger than a page, every
  page in use). Strings the faces cannot draw still fall back to plain text.
* **Keys.** An entry is keyed by the string, the merged options
  (`Cutout.Signature`, numbers rounded to 3 decimals) and the drawn zoom, so a
  slot never shows a texture drawn for another size or look.
* **Reclaiming.** Slots touch the entry they show every frame. When every page
  is full, the least recently used page whose entries have all been untouched
  for 0.5 s (and none still rendering) is cleared and reused.
* **Display resets.** A change of video mode can recreate the rendering
  context and wipe render targets. The host checks the display size and the
  `Windowed`, `FullscreenIsBorderlessWindow`, `DisplayColorDepth` and `Vsync`
  preferences every second; on a change it drops every entry and the slots ask
  again.
* **Warm-up.** `ScreenVOLT26Warmup` calls `Cache.WarmStartup()`, which queues
  the strings known before any screen asks: the credit line (EVENT MODE, FREE
  PLAY, PRESS START), every local profile's name (profile screen, song wheel
  cards and footer, plus GUEST and P1/P2), then pack names nearest first around
  the packs the local profiles last played and the one the carousel opens on,
  in both the pack screen's and the song wheel's size. It fills only free page
  space and never evicts. The warm-up screen waits for it at most 3 s (a second
  thin progress bar); the rest keeps rendering in the background, one pass a
  frame. `Cache.Stats()` reports pages, entries and the queue.
* **Kept strings.** `Cache.Warm` items may carry `keep = true`: such an entry
  is never reclaimed (its page is never reset) and is queued again right after
  a display reset. The song wheel's grade letters use it: the fifteen lettered
  grades (`VOLT26.Cutout.GradeLetters`: S+ .. D, Q, F; always upper case) in
  three colours -- white for one player (`SongGrade`), red and blue for two
  (`SongGradeP1`, `SongGradeP2`, letters and boxes in the player's colour) --
  are drawn once at startup and stay for the whole session (45 small entries).
  The star grades are not lettered; `SongWheel/Grade.lua` draws them with the
  grade star picture.
* **Shared geometry.** For a warmed string to be found, the warm-up must draw
  it exactly as its screen does, so those slots take their size from
  `VOLT26.Cutout.StyleDesign` / `Cutout.Style(name)` in
  `Scripts/VOLT26_CutoutStyles.lua` (`ProfileName`, `PackName`, `SongPack`,
  `SongCardName`, `SongFooterName`, `SongGrade`, `SongGradeP1`, `SongGradeP2`, `CreditPlayer`, `CreditCentre`). Change
  those sizes there, not in the screens.

Verified outside the engine only: Lua 5.1 syntax and a harness that runs the
real slot and cache code against a mocked actor tree (warm-up, hits, misses,
held slots, eviction while scrolling, display reset, fallbacks, Performance
mode). Not yet checked in ITGmania: the page textures' regions on screen
(crop and alignment), the CopySrc region clear inside a shared page, and the
frame cost of background warm-up on the title screen on slow hardware.

## Faces

`Fonts/Cutout` holds six bitmap fonts generated by
`tools/cutout-fonts/generate.py` from SIL OFL typefaces (see
`Fonts/Cutout/README.md` and the `OFL-*.txt` licences). Each face is a single
1020x1022 page (about 4 MB of video memory) covering printable ASCII, the
Latin-1 letters and common Latin Extended-A letters; Æ and Œ are drawn lower
case. `Scripts/VOLT26_CutoutMetrics.lua` is generated alongside and must be
regenerated with the pages.

## Verification status

Static checks (Lua syntax with `luac 5.1`, the layout run outside the engine,
an offline preview from the generated font pages), plus a first owner run in
ITGmania on the title screen: lettering renders; the 8-direction backing was
serrated and was raised to 16 directions (not yet re-tested in the engine). Points to check in the engine: the baseline of the letters
(BitmapText bottom alignment), the `ActorFrameTexture` preserve/clear passes,
edge quality of the backing, and the slot positions on 16:9 and 16:10.
