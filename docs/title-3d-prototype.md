# Title room prototype

## Animated Edit, Options and Exit banners (2026-09-12)

Branch: `codex/title-3d-remaining-banners`. The active `Prototype3D.lua` now
attaches four looping movie sprites to the imported banner surfaces. Edit maps to
`Banner_continue`, Options to `Banner_options`, and Exit to `Banner_extras`.
Centers and dimensions come from the current OBJ/import-info bounds. Each sprite
is offset 0.02 meters along the surface normal, with 1% overscan and depth testing.
Play retains its verified horizontal mirror and placement. Options uses an X
rotation of -90 degrees so its lettering reads upright from the road camera.
Camera behavior and native menu routes are unchanged.

The owner's `City_bg/edit`, `City_bg/opt`, and `City_bg/exit` JPG sequences are
encoded to `TitleTravelCity/banner_edit.avi`, `banner_options.avi`, and
`banner_exit.avi`: MPEG-4 Part 2 / DX50, yuv420p, 1408x512, 90 frames at 30 fps.
Rebuild with `python tools/build-title-banner-movies.py --ffmpeg <ffmpeg-path>`;
`--include-play` also rebuilds Play. Source images and source models are preserved.

Verification: Lua 5.1 syntax passed. ITGmania loaded all four movie textures and
logged repeated loops at approximately three-second intervals without Lua errors.
Individual menu stops were inspected at 1920x1080 using command-line DefaultChoice
overrides because synthetic navigation was not received. Edit and Exit lettering
and surface alignment were verified; Options was rechecked successfully after
reversing its X rotation.
Manual navigation, action activation, and sustained performance remain for owner
review. No merge into main has been performed.

Current handoff and final tuning values are in the repository-root `3d_menu.md`.
The latest iteration uses wider oblique views and a once-per-runtime opening
flight. The notes below retain the history of earlier prototypes and camera values.

## Current test: travel city

### Full-screen presentation and owner-provided camera anchors

The title now contains only the city and a solid `#FF0000` background; all prototype
headers, labels, control hints, counters, and opaque top/bottom panels are removed.
The 3D viewport uses the full screen at the configured aspect ratio, verified at
1920x1080. Existing engine status/credit overlays are independent of these removed
prototype elements.

Camera anchors transcribed from the owner's Blender screenshot (X,Y,Z,yaw):
Play `(-6.72,0,6.8,90)`, Continue `(6.72,24,10.5,-90)`, Options
`(-6.22,48,8.3,90)`, Exit `(6.72,72,13,-90)`. They mark the banner centers,
not an eye position inside the facade. The eye stands 7.2 meters toward the street
from each anchor, enough to frame the widest 8.19-meter banner at horizontal FOV 65.
Blender `(X,Y,Z)` maps to the engine model `(X,Z,-Y)`.

Travel takes 1.1 seconds with smootherstep interpolation, alternating frontal
90/-90-degree views, and up to 7 degrees of temporary roll, returning level at
arrival. Rapid selection changes start from the current translation, yaw, and roll.
Corrected the projection eye distance to use screen **width**, as the engine's
menu FOV is horizontal. The previous height-based calculation was inaccurate.

Verification: final camera code loads without Lua errors. In-engine observations
confirmed a banked transition over solid red, a level frontal Play banner,
and full viewport coverage without prototype panels or labels. The standoff was
then widened from 6 to 7.2 meters to keep the widest banner inside the viewport.
Full route and rapid-input review remains with the owner.

The active asset is now `Graphics/VOLT26/TitleTravelCity/`, imported from the
user-provided `persona_city_travel_menu.obj` and sibling MTL. Both source files
are preserved by name. Reproduce with `tools/import-title-obj.py <obj-path>
--asset-name TitleTravelCity`.

This export contains 88 objects and 72,552 triangles, spanning a long street.
The converter writes four separate model files with at most 60,000 vertices
each. An initial combined model crashed at the first title render; using separate
Model actors avoids the combined 16-bit geometry-offset limit. The four parts
share one 64x8 material-color palette. No polygons were removed.

Camera poses now translate down the street and yaw toward alternating banner
locations, with 1.2-second transitions. The rig rotates the translated world
around the perspective eye. Native menu routes are unchanged.

Verification (2026-09-12): split geometry loaded and rendered successfully in
ITGmania; no Lua errors or missing assets appeared in the final startup log.
The initial Play banner framing was visually checked at 1920x1080 after correcting
yaw direction. Full navigation, transition interruption, and sustained performance
remain for live review. The `gameplay` material has only a diffuse color in the
supplied MTL, with no image-sequence path: its banner is currently white.

## Previous test: imported city

Historical notes: the unused `TitleCity` assets, `Prototype3D-1.lua` copy, and
procedural `tools/generate-title-room.py` generator were removed with owner
approval on 2026-09-13. The active `TitleTravelCity` assets, `Prototype3D.lua`,
OBJ importer, and movie builder are retained. Paths in the previous-test sections
below document earlier iterations and may no longer exist.

The active scene now uses the user-provided `test.obj` and sibling `test.mtl`.
Original files are copied unchanged into `Graphics/VOLT26/TitleCity/`; the user's
source files are not modified. `tools/import-title-obj.py` converts the OBJ to
`city.txt`, triangulating polygons with ear clipping, and converts the five MTL
diffuse colors from linear values to an sRGB palette (`palette.png`, 64x8).
This converter targets untextured, opaque, Y-up Blender OBJ geometry. It does not
transfer Blender lights, shaders, cameras, animation, or texture maps.

The imported city contains 227 objects and 2,652 triangles. It is scaled at 35
theme units per source meter. Four translation poses reference the Play,
Continue, Options, and Extras banner locations. The actual title actions remain
Dance Mode, Edit Mode, Options, and Exit; these source object names do not change
the menu routes. Banner surfaces are plain colors in the supplied assets.

Verification: ITGmania loaded the converted model and 64x8 palette without Lua
errors or missing assets. The initial view was visually inspected at 1920x1080.
Directional navigation and interrupted transitions still need hands-on review;
automated input was interrupted by user activity. The original generated room
assets below remain available for comparison.

## Original room test

Branch: `codex/title-3d-prototype`.

An original low-poly arcade room with four stations: dance cabinet, editor desk,
service console, and exit portal. Geometry and a 256x256 atlas are generated by
`tools/generate-title-room.py` (Python with Pillow). No downloaded assets are used.

The title underlay currently enables the prototype through `USE_3D_PROTOTYPE`.
Set that local flag to `false` to restore the original underlay. Restart the game
or reload the theme after changing it. This is a temporary visual test: the usual
title artwork, custom audio, and AFK presentation are bypassed. Native title
selection and action routes remain in charge, including Start and Exit.

Use the normal menu directional controls to move between four camera positions.
The 0.65-second smoothstep transition starts at the current position when interrupted.
Camera motion is currently a sideways dolly implemented as inverse world translation;
there are no imported Blender camera curves or free-roaming controls yet.

`Graphics/VOLT26/TitleRoom/room.txt` is the engine's MilkShape ASCII asset.
`room.obj`, `room.mtl`, and `atlas.png` form the Blender import set: import the OBJ
as Z-up / -Y-forward, keeping all three files together. Units are meters in the OBJ.
Use Material Preview to view the atlas. This is an OBJ asset, not a saved `.blend`.

Verification (2026-09-12): generated 720 triangles / 1,440 face-local vertices;
ITGmania loaded the prototype and atlas without Lua errors or missing-file dialogs
after correcting theme-relative asset paths. The initial Dance Mode view was
visually inspected in the engine at 1920x1080. Header and control-hint positions
were then adjusted to avoid the existing status overlays. Final spacing, actual
directional navigation, interruption timing, other aspect ratios, and hardware
performance remain for live review. The local P1 dance bindings are S/D/H/J;
use the user's configured menu controls rather than assuming arrow-key bindings.
