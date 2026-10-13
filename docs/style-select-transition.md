# Style selection SVG transition

Implemented on `codex/style-select-path-reveal` (2026-10-09).

`Graphics/VOLT26/line.svg` is the owner's editable source for the red zigzag.
`BGAnimations/ScreenSelectStyle underlay/LineTransition.lua` reproduces its
13-point polygon as six ribbon segments, using the original `#FF000D` fill.
The mesh scales uniformly to span the screen height and at least 125% of its
width, avoiding raster assets and runtime SVG dependencies.

The shared `LineTransition` actor stays centered behind all style foregrounds while
the ribbon forms along its zigzag, rather than moving the completed shape across
the screen. Paired edge points define cross-sections at each bend. Reveal distance
advances along the midpoint path; a partial segment interpolates both edges to
produce the growing tip. Left navigation reverses the path.

On `codex/style-line-behind-art`, the ribbon uses draw order -1 within the
underlay, above the separate screen background and below all choices. Since the
single/versus face textures include an opaque red field, `Foreground.lua` draws
only their foreground using textured rectangle geometry from
`ForegroundGeometry.lua`. The generator `tools/style-select/build-foreground-mesh.py`
reads the original PNGs without editing them and excludes the exact flat
`#E40001` background. Double's character already lives in `front_double.png`.
Labels, arrows, and character sprites remain above the ribbon. Geometry is built
once, not on each animation frame, and UVs account for texture padding.

Drawing takes 0.48 seconds on choice changes or 0.28 seconds on confirmation,
followed by a 0.04-second hold and 0.10-second fade. It runs only when the enabled
choice actually changes, and again on confirmation, including timer confirmation.
Rapid input replaces the previous reveal. The 0.42-second confirmation effect
finishes during the existing 0.45-second screen exit. Updates are removed when
the effect finishes. Single, Versus, Double, and optional Solo share it.

Behavior remains owned by `ScreenSelectStyle underlay/default.lua`: available
choices, credit deductions, joining/unjoining, and destination routes are retained.
The transition adds presentation commands without postponing style selection.

Verification: Lua 5.1 compilation passed for both modified Lua components.
In each direction, 101 reveal samples grew monotonically from zero to the exact
SVG polygon area. Actor-contract checks confirmed rapid-input reset, stationary
geometry, overlay hiding, update cleanup, and confirmation completion within the
existing exit duration. In-engine visual review is
pending. No upstream Simply Love synchronization was performed.
