# VOLT26 3D menu handoff

## All four animated banners (2026-09-12, Codex follow-up)

On `codex/title-3d-remaining-banners`, the Play movie-sprite approach now also
covers Edit (`Banner_continue`), Options (`Banner_options`), and Exit
(`Banner_extras`). The three new AVI files are built from the owner's 90-frame
JPG sequences with `tools/build-title-banner-movies.py`. Camera tuning is unchanged.
All three new surfaces were visually checked in ITGmania at 1920x1080; Options
uses rotationx(-90) to read upright from above. Engine logs confirm repeated
three-second loops for all four movies, with no Lua errors. Manual navigation
and action activation remain for owner review. See `docs/title-3d-prototype.md`
for conversion details. The older sections below describe previous iterations.

## Rebuilt model, generic camera (2026-09-12, latest)

The owner supplied a new `persona_city_travel_menu.obj` with the banners moved. The
city itself is unchanged in extent (Blender Y -26 to 100.125), 72,456 triangles,
80 objects (the eight `Banner_Support_*` objects are gone), same six materials, same
four model parts. Re-imported over `Graphics/VOLT26/TitleTravelCity/` and the
`gameplay` palette slot repainted to P5_INK again.

The banners are no longer four facade signs facing across the street, so the old
pose maths (deriving yaw from the sign of the banner's X) no longer applies:

| Banner | Blender x, y, z | Outward normal | Note |
|---|---|---|---|
| play | -6.615, 0.000, 6.800 | +X | facade, unchanged from the previous model |
| continue | 10.953, 19.342, 13.896 | -Y | faces back down the street, 13.9 m up |
| options | -0.012, 48.000, 0.405 | +Z | lies flat on the road surface |
| extras | 6.615, 72.000, 21.157 | -X | facade, 21.2 m up |

Poses are now derived generically. The eye is placed at
`banner + normal*standOff + tangent*side*streetOffset`, so with standOff 10 and
streetOffset 6 every stop keeps the same 31 degrees off a frontal view that the
owner approved on the Play shot, whichever way the banner is turned. The normal is
the full 3D one, so the banner on the road stands the eye 10 m above the tarmac and
is read looking down at 59 degrees, stepped 6 m back along the street; an earlier
attempt that approached it horizontally showed it edge on and the owner rejected it.
Yaw is `-atan2(dx, dy)`, calibrated against the previously verified Play pose.
Resulting stops: play yaw 59.0 pitch 0.5 at 11.7 m, continue yaw -31.0 pitch -18.0
at 12.3 m, options yaw 0 pitch +59.0 at 11.7 m, extras yaw -59.0 pitch -35.0 at
14.2 m. Each banner carries its own tangent, so a stop can be swung round to a
diagonal without touching the maths.

Pitch is new as a pose axis rather than just idle sway, because parking the eye at
the banner height would now put it on the tarmac or 21 m in the air. For a banner on
a facade the eye follows only 45 percent of the way from a 7 m nominal height,
clamped to 4-13 m, and pitch closes the rest; a banner on the road takes its height
from the stand off above it instead. The owner screenshot of the road banner
confirmed `pitchSign = 1` is correct for this engine.

The camera rig was restructured for this. The eye offset now has its own frame
(`CameraEye`), with pitch and then yaw nested inside it, so both rotate around the
eye rather than orbiting the screen plane, and the room is yawed before it is
pitched. Putting both rotations on one actor would have left that order to the
engine's internal rotation sequence.

## Follow-up pass (2026-09-12, earlier)

Owner reported three defects on the reviewed build: distant geometry popping in as
the camera travels, a completely static settled camera, and a missing animated
texture on the Play banner. The first two are addressed in `Prototype3D.lua`; the
third is an asset pipeline gap and is still open.

Far-plane clipping (the pop-in). `RageDisplay::LoadMenuPerspective` builds
`GetFrustumMatrix(..., 1, eyeDistance + 1000)` and places the eye at world
`z = eyeDistance`, so the far plane always lands on world `z = -1000` regardless of
FOV. At 35 units per meter only about 28 meters of street survived; the city is
about 126 meters deep, so the rest clipped and re-entered as the camera advanced.
This was never caused by the four-way model split. The fix scales the whole camera
rig by `worldScale = 1000 / (sceneDepth * modelUnits)` with `sceneDepth = 130`,
giving 7.69 effective units per meter and 130 meters of reach. The image is
unchanged: a true perspective camera projects `size * eyeDistance / depth`, which
does not depend on world scale. The previous `SCREEN_HEIGHT/480` rig zoom was
visually neutral for the same reason and was replaced, not stacked. If `zoom`
turns out not to scale child Z on some driver, the fallback is re-running the
importer at a smaller unit factor and matching `modelUnits` in the Lua.

Idle camera motion. Two incommensurate sines per axis drive a handheld sway added
on top of the interpolated pose, so it never fights a transition: eye offsets of
0.14 m lateral, 0.10 m vertical and 0.30 m along the view, plus 0.5 degrees yaw,
0.4 degrees pitch and 0.7 degrees roll. A new `CameraPitch` frame sits inside
`CameraRig` so pitch rotates around the eye rather than the screen plane.

Play banner texture. The MTL `gameplay` material has no map, the importer rejects
any `map_*` line, and the converter writes palette-only UVs, so no texture can
survive the mesh path. `Banner_play` is a single quad, engine bounds X -6.615,
Y 5.475 to 8.125, Z -3.64 to 3.64, with a full 0-1 UV square, so the animation is
carried by a separate actor pinned to those bounds inside `Room`, lifted 0.05 m
toward the street and depth-tested so it does not draw through the facade from the
other stops. `Def.Model` flips Y and a Sprite does not, so the actor uses the
negated centre height; `playBanner.mirrored` flips it horizontally if the lettering
reads backwards.

Source frames are the owner's `Graphics/VOLT26/City_bg/gameplay/gmban_000NN.jpg`,
90 frames of 1408x512 at 30 fps, a 3 second loop. A sprite sheet was rejected: at
that frame count it needs a 12672x4608 texture, and fitting the engine's 2048 limit
would drop each frame to roughly 224x81 for a banner that covers about 940 screen
pixels. The frames are encoded instead to
`Graphics/VOLT26/TitleTravelCity/banner_play.avi`, MPEG-4 Part 2 in AVI, 1408x512,
30 fps, 2.9 MB, which ITGmania decodes as a looping movie texture. Rebuild with
`ffmpeg -framerate 30 -i gmban_%05d.jpg -c:v mpeg4 -vtag DX50 -q:v 2 -pix_fmt
yuv420p banner_play.avi`. The source JPG folder is untouched.

Palette caveat. The `gameplay` slot of `Graphics/VOLT26/TitleTravelCity/palette.png`
is hand-repainted from white (231,231,231) to the P5_INK value (13,13,18). The quad
sits a couple of centimeters behind the sprite, so at an angle its edge shows past
the sprite no matter how the sprite is sized, and white read as a bright sliver
against the black frame. `usemtl gameplay` appears exactly once in the OBJ, on
`Banner_play`, so nothing else is affected. Re-running `tools/import-title-obj.py`
regenerates the palette from the MTL and restores the white: repaint the sixth 8x8
block (x 40 to 47, materials are sorted so `gameplay` lands last) or change `Kd`
for that material first.

Owner screenshot at the Play stop confirmed three things: the movie texture loads
and is visible on the banner, the far end of the street renders without clipping,
and the sprite reads mirrored. `playBanner.mirrored` is therefore set true, which
negates the zoomto width. The video was also confirmed with `ffprobe` (mpeg4,
1408x512, 30/1, 90 frames) and the Lua static-checked with `luac -p`.

Still unverified: that the loop actually plays rather than holding one frame, the
idle sway, the opening flight with the new world scale, pop-in during travel
between stops, and the other three banner positions.

## Current work (2026-09-12)

Owner request: wider, more oblique settled camera views; an opening flight toward
the first banner; preserve full-screen 16:9, solid red background, and no added
prototype text or letterbox panels. Implemented; startup/intro timing and the
wider oblique rendering have been verified in ITGmania. Owner aesthetic approval
and the extended interaction checks below remain pending.

Conversation is Italian; repository documentation and code are English.
Project rules are in `AGENTS.md` and its four `.agents/` modules.
Current branch: `codex/title-3d-prototype`. Changes are uncommitted, with several
untracked files; nothing has been merged into main. Owner approval is still needed
before any merge. Existing `Graphics/VOLT26/City_bg/` content was supplied separately
and must be preserved.

## Entry points and assets

- `BGAnimations/ScreenTitleMenu underlay/default.lua`: after the normal core session
  reset, `USE_3D_PROTOTYPE = true` returns the 3D actor. Setting it false restores the
  old underlay. Use `THEME:GetPathB` and avoid a relative LoadActor tail call.
- `BGAnimations/ScreenTitleMenu underlay/Prototype3D.lua`: camera, movement, red
  background, four model actors. This is the main file to adjust.
- `Graphics/ScreenTitleMenu scroll.lua`: native focus broadcasts `VOLT26_Hover`
  with zero-based `idx`; `-999` is a transient LoseFocus event and must be ignored.
- `metrics.ini`: native routes remain Dance Mode, Edit Mode, Options, Exit. Blender
  names Continue/Extras are visual anchor names, not new menu routes.
- `Graphics/VOLT26/TitleTravelCity/`: active converted scene and preserved original
  `persona_city_travel_menu.obj` / `.mtl`.
- `tools/import-title-obj.py`: importer, triangulation, palette and model splitting.
  Rebuild with Python + Pillow: `tools/import-title-obj.py <source.obj>
  --asset-name TitleTravelCity`.
- Previous city assets (`TitleCity`), the unused `Prototype3D-1.lua` copy, and
  `tools/generate-title-room.py` were removed with owner approval on 2026-09-13.
- `docs/title-3d-prototype.md`: chronological technical notes; older values there
  describe earlier iterations. This file and the active Lua describe current work.

## Model facts and limitations

Source: `C:/Users/stefa/OneDrive/Desktop/persona_city_travel_menu.obj` plus sibling
MTL. Original source files have not been edited. 88 objects, 72,552 triangles, six
materials. The model is much denser than the first city (2,652 triangles).

The initial large combined model crashed on first render. Four separate `Def.Model`
actors, each loading one file (`city.txt`, `city-1.txt` through `city-3.txt`), resolved
the crash. Splitting only into meshes inside one file was insufficient. Each part
has at most 60,000 vertices to avoid 16-bit geometry index/offset limits.

The importer currently converts diffuse colors to a shared 64x8 sRGB palette.
It does not import animated textures, source UV mapping, lights, shaders, or cameras.
The `gameplay` material has no image path in the supplied MTL, so the Play banner
is white. Other banners are solid red. Image sequence assets were discussed but
have not been connected; do not report animated textures as implemented.

The prototype bypasses the old title underlay's audio/AFK presentation. Native
selection and routes remain intact. Existing engine status/credit overlays such
as GrooveStats, Press Start, and Event Mode are not prototype labels.

## Coordinates and projection

Owner-supplied Blender nulls (X, Y, Z, rotation Z degrees):

| Banner | X | Y | Z | Rotation |
|---|---:|---:|---:|---:|
| Play | -6.72 | 0 | 6.8 | 90 |
| Continue | 6.72 | 24 | 10.5 | -90 |
| Options | -6.22 | 48 | 8.3 | 90 |
| Exit | 6.72 | 72 | 13 | -90 |

These nulls mark centers on the facade, not safe camera-eye positions. The camera
must stand out toward the street. OBJ/model conversion is Blender `(X,Y,Z)` to
`(X,Z,-Y)`, at 35 theme units per meter. The Model renderer itself flips Y.
The room actor uses inverse camera translation; a parent applies camera yaw.
A separate parent applies screen-plane roll.

Critical: ITGmania menu FOV is **horizontal**. Perspective eye distance must be
`SCREEN_WIDTH / (2*tan(fov/2))`, not SCREEN_HEIGHT. The old height calculation caused
incorrect targeting and facade occlusion at 90-degree rotations.

## Verification / next-agent status

Current settings in the main camera Lua:

- `standOff = 10` meters toward the street; `streetOffset = 6` meters before each
  banner along the street. Eye-to-target distance is about 11.66 meters, wider
  than the previous 7.2-meter front-on views.
- Settled yaw is calculated as `atan(10/6)` with alternating signs: approximately
  +59/-59 degrees, or 31 degrees away from a frontal view of the facade.
- Settled roll alternates -3/+3 degrees. Navigation adds a temporary 7-degree bank
  and interpolates from the current pose when interrupted. Travel duration: 1.1 s.
- Opening pose: street center X=0, Blender Y=-25 m, height=9.5 m, yaw=10 degrees,
  roll=-6 degrees. Opening duration: 2.8 s, toward Play; extra travel bank 3 degrees.
- `_G.Volt26CityIntroPlayed` guards the opening once per Lua runtime. Returning to
  the title does not replay it. A fresh game launch resets this flag. A theme reload
  that retains Lua globals may retain the flag too.
- If `_G.Volt26InitHandoff` is true, opening motion waits 0.9 s for the existing
  ScreenInit overlay. Changing to another menu choice interrupts the opening and
  uses a normal 1.1-second transition; Start is still handled by the native screen.
- Red background remains `#FF0000`; no prototype text or letterbox quads returned.

Verified on the latest direct-title startup: log records intro start at 00:01.702
and completion at 00:04.502 (exactly 2.8 seconds), with no Lua errors or missing
assets. A settled oblique banner view with visibly wider surrounding buildings,
red background, and full-screen coverage was inspected at 1920x1080. `git diff
--check` passed. The game was left open for owner review.

Not yet verified end-to-end: normal ScreenInit handoff timing, all four final
framing positions, return-to-title intro suppression, input interruptions during
the opening, rapid navigation, Start during motion, other aspect ratios, sustained
performance. Those are explicit validation limits, not known failures.

Engine: `D:/SimplyLoveVanilla/Program/ITGmania.exe`. Launch from its install root with
`--theme=VOLT26` and `--metric=Common::InitialScreen=\"ScreenTitleMenu\"` for a direct
title smoke test. Normal startup also uses ScreenInit's final handoff overlay.
Logs: `C:/Users/stefa/AppData/Roaming/ITGmania/Logs/log.txt`.
Crash report: `D:/SimplyLoveVanilla/crashinfo.txt`; compare timestamps before blaming
a stale report. Crash-time buffered log lines may only be present in crashinfo.
Sandboxed launches can hang; working launches used the normal escalation review.
Do not kill unknown gameplay sessions. Only restart a known title/test instance.
Computer Use via `@oai/sky` can inspect the game, but synthetic directional presses
have been unreliable and user input may interrupt automation. Do not claim all
routes, rapid input, or performance tested just because startup succeeded.
