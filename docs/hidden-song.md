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
* **Hidden:** the engine keeps unselectable songs off the wheel; the theme's
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
