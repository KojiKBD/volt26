# Hidden song ("Are you LOST?")

An Event Mode easter egg (`codex/lost-easter-egg`). On the song select, the
pad's left and right arrows pressed together five times in a row (at most 2 s
apart, no other button in between, either player; the first version asked
for all four arrows, which many keyboards cannot report at once) start a song
that is not on the
wheel, for every joined player. Gameplay starts at once, without the usual lead-in
naming the pack (`ScreenGameplay in` returns an empty frame for this song),
and "Are you LOST?" (LOST? in red, cutout lettering) covers the screen on
black while the music plays its first seconds; it clears at 3 s, before the
first arrow (about 4 s in). The song's title is LOST.

* **Behaviour:** `VOLT26.Secret` (`Scripts/VOLT26_Secret.lua`): installing the
  song, hiding its pack, counting the code (`Feed`), starting the chart
  (`Start`, the Challenge chart of the current style, else its first chart)
  and putting the previous song back when the song select returns
  (`RestoreSong`).
* **The song:** `Other/VOLT26 Secret/LosT` (from King Tournament 2026,
  `LosT (momo)`: the `.ssc` with `#SELECTABLE:NO;` and no pack banner or
  background, and its music). ITGmania loads songs only from its song
  folders, so on startup (`ScreenVOLT26Warmup` overlay ->
  `VOLT26.Secret.AfterWarmup`) the theme copies it to `Songs/VOLT26 Secret/LosT`
  with `FILEMAN:Copy` when it is missing or differs (size and hash), then
  reloads the songs once: `ScreenVOLT26SecretReload` (`OnlyLoadAdditions`) for
  a new song, `ScreenVOLT26SecretReloadAll` for a changed one. The reload is covered by LOADING in cutout lettering on black
  (`BGAnimations/ScreenSystemLayer loading.lua`, style `Loading`). Removing the
  theme leaves the folder in `Songs`; it is harmless (not selectable).
* **Hidden:** `VOLT26.MusicSelection.PrepareScreen` enables the engine's
  `HiddenSongs` preference during the song-select overlay InitCommand,
  before the wheel builds its data. ITGmania ignores `#SELECTABLE:NO`
  when this preference is false: the secret then appears as a pack in
  Group and Series/Collection sorts, even though the theme filters its
  contents out (the old preview displayed a heading with zero songs).
  This also hides other songs marked `#SELECTABLE:NO`; the secret code
  still finds and starts LOST directly through SONGMAN/GAMESTATE.
  PackPreview also rejects the secret pack before drawing its heading.
  The engine keeps unselectable songs off the wheel; the theme's
  own lists leave the `VOLT26 Secret` pack out (`VOLT26.PackSelection`
  pack list, sections, previews and series; song search; Sort Menu counts).
* **Stinger:** `BGAnimations/ScreenGameplay overlay/SecretStinger.lua` (an
  empty actor for any other song); the title picture
  `Graphics/VOLT26/Secret/lost_title.png` is baked by
  `tools/secret/build_lost_title.py` from the cutout fonts' letters at a 220 px
  em (`--src` as for `tools/cutout-fonts/generate.py`).

Verification: Lua syntax, and an offline run of the code counter (five quick
presses trigger; a long pause or another button starts over). Not yet run in
ITGmania: the copy into `Songs`, the reload screens, the stinger and the
return to the song select are untested.

## The song's own gameplay

For LOST the gameplay interface is not built (`ScreenGameplay
underlay/default.lua` hands over to `ScreenGameplay underlay/Secret.lua`);
only the arrows remain, over:

* **Blood** rising from the bottom as the music plays: ActorMultiVertex
  layers with a lumpy, swaying surface, a clotted texture drifting inside
  (`Graphics/VOLT26/Secret/blood.png`, `tools/secret/build_blood_texture.py`),
  a darker crust along the surface and a faint sheen; it churns in the
  breakdown and surges at each "break down".
* **Lyrics** (`ScreenGameplay overlay/SecretLyrics.lua`, in the middle of the
  screen over the arrows, the same with or without Reverse) from `LosT.lrc` (`VOLT26.Secret.Lyrics`, `LyricsOffset`; the file
  already follows the chart's cuts), one line at a time in a heavy condensed
  sans (`Fonts/Secret`, `tools/secret/build_lyrics_font.py`) with a light RGB
  split that jolts on each new line; the chorus and "break down" lines are
  bigger and red.
* **Effects** (`ScreenGameplay overlay/SecretFX.lua`), timed by
  `VOLT26.Secret.Timeline` from the lyrics and by the beat: Drunk/Tipsy in the
  first verse, red arrows on "Red crescent moons", zoom punches in the
  choruses, a hard breakdown (sway, tilt, Drunk/Tipsy/Beat, hits on each
  "break down", glitch bars), dimming arrows, one white flash on the last
  line, a fade to black; a vignette breathes on the beat. No strobes.

The engine's judgment, combo and its own lyrics display (which finds the
`.lrc` by itself) are hidden for this song.
