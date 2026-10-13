"""Build the song select art from the owner's Illustrator mockup.

Input: tools/song-select/art/, written by the Illustrator scripts in this
folder (run them from File > Scripts > Other Script... with the mockup open
and its song select artboard active):

  export_song_select_art.jsx    item_NN.png + items.json, one PNG per
                                top-level item, clipped to the artboard
  export_song_select_parts.jsx  part_<item>_<child>.png + parts.json, the
                                children of the SELECT logo, of a plain and
                                the focused song row and of the info panel
  export_meter_digits.jsx       digits_boxed.png, digits_plain.png

Output:
  Graphics/VOLT26/SongSelect/*.png   the pieces, cropped
  BGAnimations/ScreenSelectMusic overlay/SongWheel/Art.lua
                                     where each piece sits (design pixels
                                     of the 1920x1080 artboard, centres)
                                     and the badge digits' advances

Usage: python tools/song-select/build_song_select_art.py [--art DIR] [--theme DIR]
Needs Pillow and numpy.  Item numbers follow the mockup's stacking order; if
the artboard gains or loses items, update PIECES below.
"""
import argparse
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

# name: (source files drawn bottom to top, half resolution?)
PIECES = {
    "Glow":         (["item_03.png"], True),   # the radial light on the red
    "Wedge":        (["item_04.png"], False),  # black left panel
    "DebrisA":      (["item_05.png"], False),  # white star shards, bottom left
    "DebrisB":      (["item_06.png"], False),
    "Slash":        (["item_07.png"], False),  # white slashes past the wedge
    "SlashThin":    (["item_08.png"], False),
    "ChipA":        (["item_09.png"], False),
    "ChipB":        (["item_10.png"], False),
    "Band":         (["item_11.png"], False),  # white band under SELECT
    "Line":         (["item_12.png"], False),
    "Bar":          (["item_13.png"], False),  # black bar behind SELECT
    "Select":       (["item_14.png"], False),
    "Star1":        (["item_23.png"], False),
    "Star2":        (["item_24.png"], False),
    "Star3":        (["item_25.png"], False),
    "Star4":        (["item_26.png"], False),
    "JacketFrame":  (["item_27.png"], False),
    "DiffBack":     (["item_28.png"], False),  # black square behind a badge
    "Panel":        (["part_34_08.png", "part_34_07.png"], False),
    "GraphFrameP1": (["part_34_05_00.png"], False),
    "GraphFrameP2": (["part_34_04_00.png"], False),
    "RowBands":     (["part_15_04.png"], False),
    "Rank":         (["part_15_03.png"], False),
    "FocusBands":   (["part_22_08.png", "part_22_07.png"], False),
    "FocusRank":    (["part_22_06.png"], False),
}
# White masks, tinted by the theme: the two halves of the square that marks a
# chosen difficulty (P1 left, P2 right; one player alone gets both halves).
MASKS = {"HalfP1": "item_32.png", "HalfP2": "item_33.png"}
# Static scene behind the focused row, for its difference-blend flags.
SCENE = ["item_02.png", "item_03.png", "item_04.png", "item_07.png", "item_08.png"]
FOCUS_UNDER = ["part_22_08.png", "part_22_07.png", "part_22_06.png"]
FOCUS_NORMAL = ["part_22_02.png"]            # red, normal blend
FOCUS_DIFFERENCE = ["part_22_01.png", "part_22_00.png"]

# Reference points measured on the artboard.
ROW_BANDS_ORIGIN = "part_15_04_00.png"  # black band of the row above the focus
FOCUS_ORIGIN = "part_22_07.png"         # red band of the focused row
ROW_BADGE = "part_15_02.png"
FOCUS_BADGE = "part_22_05.png"
ROW_GROUPS = {-1: "item_15.png", 1: "item_16.png", 2: "item_17.png", 3: "item_18.png",
              4: "item_19.png", 5: "item_21.png"}


def load(art, name):
    return Image.open(os.path.join(art, name)).convert("RGBA")


def stack(art, names):
    out = None
    for name in names:
        im = load(art, name)
        out = im if out is None else Image.alpha_composite(out, im)
    return out


def save_piece(im, out_dir, name, half=False):
    box = im.getbbox()
    crop = im.crop(box)
    if half:
        crop = crop.resize((max(1, crop.width // 2), max(1, crop.height // 2)), Image.LANCZOS)
    crop.save(os.path.join(out_dir, name + ".png"), optimize=True)
    l, t, r, b = box
    return {"File": name + ".png", "X": (l + r) / 2, "Y": (t + b) / 2, "W": r - l, "H": b - t,
            "Zoom": 2 if half else 1}


def to_float(im):
    return np.asarray(im, dtype=np.float32) / 255.0


def over(dst, src):
    """src over dst, straight alpha, float arrays."""
    sa = src[..., 3:4]
    da = dst[..., 3:4]
    oa = sa + da * (1 - sa)
    rgb = (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
    return np.concatenate([rgb, oa], axis=-1)


def focus_front(art):
    """The focused row's flags, blended against the static scene and the
    row's own bands, kept only where the flags are."""
    scene = to_float(stack(art, SCENE + FOCUS_UNDER))
    result = scene.copy()
    mask = np.zeros(scene.shape[:2], dtype=np.float32)
    for name in FOCUS_NORMAL:
        src = to_float(load(art, name))
        result = over(result, src)
        mask = np.maximum(mask, src[..., 3])
    for name in FOCUS_DIFFERENCE:
        src = to_float(load(art, name))
        a = src[..., 3:4]
        diff = np.abs(result[..., :3] - src[..., :3])
        result[..., :3] = result[..., :3] * (1 - a) + diff * a
        mask = np.maximum(mask, src[..., 3])
    result[..., 3] = mask
    return Image.fromarray((np.clip(result, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def white_mask(im):
    a = np.asarray(im)[..., 3]
    out = np.zeros(a.shape + (4,), dtype=np.uint8)
    out[..., :3] = 255
    out[..., 3] = a
    return Image.fromarray(out, "RGBA")


def ink_layers(strip, cell_w, cell_h):
    """Splits a strip of black-and-white digits into its black ink (every
    covered pixel) and its white ink (the light part), both as white masks,
    so the theme can give each ink its own colour."""
    rgba = np.asarray(strip, dtype=np.float32) / 255.0
    alpha = rgba[..., 3]
    light = rgba[..., :3].mean(axis=-1)
    def mask(a):
        out = np.zeros(rgba.shape, dtype=np.uint8)
        out[..., :3] = 255
        out[..., 3] = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
        return Image.fromarray(out, "RGBA")
    black = mask(alpha)
    white = mask(alpha * light)
    # Horizontal extent of each cell's ink, for spacing the digits.
    extents = []
    for d in range(strip.width // cell_w):
        cols = np.where(alpha[:, d * cell_w:(d + 1) * cell_w].max(axis=0) > 0.05)[0]
        extents.append((int(cols[0]), int(cols[-1]) + 1) if len(cols) else (0, cell_w))
    return black, white, extents


def bbox(art, name):
    return load(art, name).getbbox()


def lua_value(v, indent=""):
    if isinstance(v, dict):
        inner = indent + "\t"
        items = []
        for k in v:
            key = k if isinstance(k, str) and k.isidentifier() else "[%s]" % lua_value(k)
            items.append("%s%s = %s," % (inner, key, lua_value(v[k], inner)))
        return "{\n" + "\n".join(items) + "\n" + indent + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x, indent) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return ("%.2f" % v).rstrip("0").rstrip(".")
    if isinstance(v, int):
        return str(v)
    return '"%s"' % v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--art", default=os.path.join(HERE, "art"))
    ap.add_argument("--theme", default=os.path.abspath(os.path.join(HERE, "..", "..")))
    args = ap.parse_args()
    art = args.art
    out_dir = os.path.join(args.theme, "Graphics", "VOLT26", "SongSelect")
    os.makedirs(out_dir, exist_ok=True)

    pieces = {}
    for name, (files, half) in PIECES.items():
        pieces[name] = save_piece(stack(art, files), out_dir, name, half)
    for name, file in MASKS.items():
        pieces[name] = save_piece(white_mask(load(art, file)), out_dir, name)
    pieces["FocusFront"] = save_piece(focus_front(art), out_dir, "FocusFront")

    digits = {}
    for kind in ("boxed", "plain"):
        strip = load(art, "digits_%s.png" % kind)
        cell_w, cell_h = strip.width // 10, strip.height
        black, white, extents = ink_layers(strip, cell_w, cell_h)
        black.save(os.path.join(out_dir, "Digits %s black 10x1.png" % kind), optimize=True)
        white.save(os.path.join(out_dir, "Digits %s white 10x1.png" % kind), optimize=True)
        digits[kind.capitalize()] = {"CellW": cell_w, "CellH": cell_h,
                                     "Ink": [list(e) for e in extents]}

    # Row geometry: everything relative to the top-left of the row's black
    # band (plain rows) or red band (the focused row), which is the row's
    # anchor in the theme.
    l, t, _, _ = bbox(art, ROW_BANDS_ORIGIN)
    anchor = (l, t)
    groups = {k: bbox(art, f) for k, f in ROW_GROUPS.items()}
    # A row's anchor sits at the same place inside its group in every row.
    g1 = groups[-1]
    off = (anchor[0] - g1[0], anchor[1] - g1[1])
    anchors = {k: (g[0] + off[0], g[1] + off[1]) for k, g in groups.items()}
    fl, ft, _, _ = bbox(art, FOCUS_ORIGIN)
    rb = bbox(art, ROW_BADGE)
    fb = bbox(art, FOCUS_BADGE)

    def rel(piece, origin):
        p = pieces[piece]
        return {"X": p["X"] - origin[0], "Y": p["Y"] - origin[1]}

    row = {
        "Anchors": {k: list(v) for k, v in sorted(anchors.items())},
        "Bands": rel("RowBands", anchor),
        "Rank": rel("Rank", anchor),
        "Badge": {"X": (rb[0] + rb[2]) / 2 - anchor[0], "Y": (rb[1] + rb[3]) / 2 - anchor[1],
                  "W": rb[2] - rb[0], "H": rb[3] - rb[1]},
    }
    focus = {
        "Anchor": [fl, ft],
        "Bands": rel("FocusBands", (fl, ft)),
        "Rank": rel("FocusRank", (fl, ft)),
        "Front": rel("FocusFront", (fl, ft)),
        "Badge": {"X": (fb[0] + fb[2]) / 2 - fl, "Y": (fb[1] + fb[3]) / 2 - ft,
                  "W": fb[2] - fb[0], "H": fb[3] - fb[1]},
    }

    lua = os.path.join(args.theme, "BGAnimations", "ScreenSelectMusic overlay", "SongWheel", "Art.lua")
    with open(lua, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Generated by tools/song-select/build_song_select_art.py from the owner's\n")
        f.write("-- Illustrator mockup.  Do not edit by hand: change the artwork and rebuild.\n")
        f.write("--\n-- Pieces: Graphics/VOLT26/SongSelect/<File>, centred on X, Y in the\n")
        f.write("-- 1920x1080 design space (W x H on screen; Zoom 2 for a half-size file).\n")
        f.write("-- Row and Focus figures are relative to a row's anchor, the top-left corner\n")
        f.write("-- of its upper band.  Digits: the meter badge strips, ten cells each, with\n")
        f.write("-- every cell's inked columns.\n")
        f.write("return " + lua_value({"Pieces": pieces, "Row": row, "Focus": focus, "Digits": digits}) + "\n")
    print("wrote", len(pieces), "pieces to", out_dir)
    print(open(lua, encoding="utf-8").read()[:3000])


if __name__ == "__main__":
    main()
