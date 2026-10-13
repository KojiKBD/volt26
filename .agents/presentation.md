# Presentation Rules

- The credit line (the player names in the bottom corners and the centre text such as EVENT MODE, credits or free play, drawn by `BGAnimations/ScreenSystemLayer overlay.lua`) always uses the VOLT26 cutout lettering (`VOLT26.Cutout`), on every screen that shows it. Never draw it in a plain font, and do not add per-screen exceptions that switch it back to plain text.
- Do not rotate pack jackets or other photographic sprites; rotated sprites alias badly at their edges and corners in the engine. Keep slanted shapes as textures with anti-aliased edges rather than skewed or rotated quads.
