#!/usr/bin/env python3
"""Bake the VOLT26 cutout lettering into static bitmap fonts.

The "ransom note" look of VOLT26.Cutout (Scripts/VOLT26_Cutout.lua) used to
be composed at runtime: every string was stamped letter by letter into a
render texture.  It is now baked here once.  Every character gets its own
face, size, tilt, baseline offset and (sometimes) an inverted box, chosen by a
generator seeded with the character itself, so a letter always looks the same
wherever it appears.

Each character is drawn into two fonts that share one layout:
  Cutout Back   the backing (white here, tinted black at runtime): the letter grown by an outline, plus a drop
                shadow (a boxed letter: its box, grown)
  Cutout Ink    the white letter (a boxed letter: a white box with the letter
                cut out in black)
A slot draws the same string with Back, then Ink, so every backing lies under
every letter and neighbouring backings merge, as the old renderer did.

"Cutout Large Back" / "Cutout Large Ink" carry the grade letters at a larger
em, for the big grades (same choices, sharper pixels).

Outputs (from the theme root):
  Fonts/Cutout/_cutout back [main] CxR.png, [p2] ..., _cutout back.ini
  Fonts/Cutout/_cutout ink ...
  Fonts/Cutout/_cutout large back ..., _cutout large ink ...
  Fonts/Cutout Back.redir, Cutout Ink.redir, Cutout Large Back.redir,
  Fonts/Cutout Large Ink.redir
No font name may start with another one's name: ITGmania finds a font by
prefix ("Cutout Back" would also match "Cutout Back Large").
  Scripts/VOLT26_CutoutMetrics.lua   per-glyph advance and drawn extents

Usage:
    python tools/cutout-fonts/generate.py --src <dir with the .ttf files>

The faces are the OFL fonts listed in FACES (Google Fonts); the licences are
next to this script.  Requires Pillow, fontTools, numpy and scipy.
"""
import argparse
import glob
import io
import math
import os
import random

import numpy as np
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

EM = 56            # em of the regular fonts, texture pixels (3 pages of 1024)
EM_LARGE = 160     # em of the large (grade) fonts
PAGE = 1024        # texture page size
SEED = 26          # change to re-roll every letter

# The look, as the runtime renderer had it (Cutout.Defaults).
CHAOS = 0.45
BOX_CHANCE = 0.28
SIZE_MIN, SIZE_MAX = 0.82, 1.22
LOWER_BOOST = 1.08
OUTLINE = 0.11     # of the em
SHADOW = (0.55, 0.7)  # of the outline
SPACE = 0.38       # of the em

# (face id, file glob, variation axes)
FACES = [
    ("tinos",     "Tinos-Bold*.ttf",                 {}),
    ("caprasimo", "Caprasimo-Regular*.ttf",          {}),
    ("spartan",   "LeagueSpartan*.ttf",              {"wght": 700}),
    ("besley",    "Besley[[]wght[]]*.ttf",           {"wght": 800}),
    ("jost",      "Jost[[]wght[]]*.ttf",             {"wght": 700}),
    ("archivo",   "Archivo[[]wdth,wght[]]*.ttf",     {"wght": 800, "wdth": 100}),
]

EXTENDED_A = "ĄąĆćČčĎďĘęĚěĞğİıŁłŃńŇňŐőœŘřŚśŞşŠšŤťŰűŮůŹźŻżŽž"
CHARSET = (
    [chr(c) for c in range(0x20, 0x7F)]
    + [chr(c) for c in range(0xC0, 0x100) if c not in (0xD7, 0xF7)]
    + list(EXTENDED_A) + ["Œ"]
)
# The grade letters (Cutout.GradeLetters), also in the large fonts.
LARGE_CHARSET = list(" SABCDFQ+-")


def load_faces(src):
    faces = []
    for face_id, pattern, axes in FACES:
        matches = sorted(glob.glob(os.path.join(src, pattern)))
        if not matches:
            raise SystemExit("missing face %s (%s) in %s" % (face_id, pattern, src))
        tt = TTFont(matches[0])
        if axes and "fvar" in tt:
            tt = instancer.instantiateVariableFont(tt, axes)
        buf = io.BytesIO()
        tt.save(buf)
        faces.append({"id": face_id, "data": buf.getvalue(), "cmap": set(tt.getBestCmap())})
    return faces


def is_lower(ch):
    u = ch.upper()
    return u != ch and len(u) == 1


def choices(ch, faces):
    """The fixed look of one character."""
    seed = SEED * 1000003 + ord(ch)
    R = random.Random(seed)
    usable = [f for f in faces if ord(ch) in f["cmap"]]
    if not usable:
        return None
    face = usable[int(R.random() * len(usable))]
    return {
        "face": face,
        "size": (SIZE_MIN + R.random() * (SIZE_MAX - SIZE_MIN)) * (LOWER_BOOST if is_lower(ch) else 1),
        "box": R.random() < BOX_CHANCE,
        "dy": (R.random() - 0.5) * 0.32 * CHAOS,
        "rot": math.degrees((R.random() - 0.5) * 0.5 * CHAOS),
    }


_font_cache = {}


def pil_font(face, px):
    key = (face["id"], px)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(io.BytesIO(face["data"]), px)
    return _font_cache[key]


def render(ch, look, em):
    """Back and ink images of one character, and where its origin is.

    The origin is the start of the character's advance on the baseline.
    Returns (back, ink, origin_x, origin_y, advance) with images in RGBA."""
    if ch == " " or look is None:
        return None, None, 0, 0, SPACE * em
    px = max(4, int(round(look["size"] * em)))
    font = pil_font(look["face"], px)
    w = font.getlength(ch)
    x0, y0, x1, y1 = font.getbbox(ch, anchor="ls")
    asc, desc = -y0, y1
    box = look["box"]
    pad = px * 0.07 if box else 0
    advance = w + 2 * pad + em * (0.05 if box else -0.015)
    outline = em * OUTLINE
    shadow = (outline * SHADOW[0], outline * SHADOW[1])

    S = int(em * 4)
    cx, cy = S / 2, S / 2               # letter centre on its baseline
    base_y = cy + look["dy"] * em

    letter = Image.new("L", (S, S), 0)
    ImageDraw.Draw(letter).text((cx - w / 2, base_y), ch, font=font, anchor="ls", fill=255)

    def rect(grow):
        return (cx - w / 2 - pad - grow, base_y - asc - pad - grow,
                cx + w / 2 + pad + grow, base_y + desc + pad + grow)

    # Backing: the letter grown by the outline (a boxed letter: its box grown
    # by 0.8 outline), at the letter and at the drop-shadow offset.
    if box:
        shape = Image.new("L", (S, S), 0)
        ImageDraw.Draw(shape).rectangle(rect(outline * 0.8), fill=255)
        grown = np.asarray(shape, dtype=np.float32) / 255
    else:
        a = np.asarray(letter, dtype=np.float32) / 255
        dist = ndimage.distance_transform_edt(a < 0.5)
        grown = np.clip(outline - dist + 0.5, 0, 1)
        grown = np.maximum(grown, a)
    shifted = ndimage.shift(grown, (shadow[1], shadow[0]), order=1, mode="constant")
    backing = np.maximum(grown, shifted)
    # White, so the runtime can tint it (diffuse) to the backing colour.
    back = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    back.putalpha(Image.fromarray((backing * 255).astype(np.uint8)))

    ink = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if box:
        plate = Image.new("L", (S, S), 0)
        ImageDraw.Draw(plate).rectangle(rect(0), fill=255)
        white = Image.new("RGBA", (S, S), (255, 255, 255, 255))
        ink.paste(white, mask=plate)
        black = Image.new("RGBA", (S, S), (0, 0, 0, 255))
        ink.paste(black, mask=letter)
    else:
        white = Image.new("RGBA", (S, S), (255, 255, 255, 255))
        ink.paste(white, mask=letter)

    # The letter turns about its centre on the baseline (rotationz: clockwise
    # for positive angles, so PIL's counter-clockwise rotate takes -rot).
    back = back.rotate(-look["rot"], resample=Image.BICUBIC, center=(cx, cy))
    ink = ink.rotate(-look["rot"], resample=Image.BICUBIC, center=(cx, cy))

    # The advance starts pad before the letter's left edge.
    origin_x = cx - w / 2 - pad
    return back, ink, origin_x, cy, advance


def build(charset, faces, em, theme, name_back, name_ink, redir_back, redir_ink):
    glyphs = []
    for ch in charset:
        look = choices(ch, faces) if ch != " " else None
        if ch != " " and look is None:
            continue
        back, ink, ox, oy, adv = render(ch, look, em)
        g = {"ch": ch, "adv": int(round(adv)), "look": look}
        if back is not None:
            bbox = back.getbbox()
            ib = ink.getbbox()
            if ib:
                bbox = (min(bbox[0], ib[0]), min(bbox[1], ib[1]), max(bbox[2], ib[2]), max(bbox[3], ib[3]))
            # Extents relative to the origin (advance start, baseline).
            g.update(back=back.crop(bbox), ink=ink.crop(bbox),
                     left=bbox[0] - ox, top=bbox[1] - oy, right=bbox[2] - ox, bottom=bbox[3] - oy)
        glyphs.append(g)

    # One cell for every glyph: centred on the advance's middle and the
    # baseline, so it must hold the farthest extent on each side.
    half_w = max(max(abs(g.get("left", 0) - g["adv"] / 2), abs(g.get("right", 0) - g["adv"] / 2)) for g in glyphs)
    up = max(-g.get("top", 0) for g in glyphs)
    down = max(g.get("bottom", 0) for g in glyphs)
    cell_w = int(math.ceil(half_w)) * 2 + 4
    cell_h = int(math.ceil(up + down)) + 4
    baseline = int(math.ceil(up)) + 2
    columns = PAGE // cell_w
    rows = PAGE // cell_h
    per_page = columns * rows
    pages = [glyphs[i:i + per_page] for i in range(0, len(glyphs), per_page)]
    page_names = ["main"] + ["p%d" % (i + 2) for i in range(len(pages) - 1)]

    font_dir = os.path.join(theme, "Fonts", "Cutout")
    os.makedirs(font_dir, exist_ok=True)
    cap_glyph = next((g for g in glyphs if g["ch"] == "H"), None)
    cap = em * 0.7
    if cap_glyph and cap_glyph["look"]:
        f = pil_font(cap_glyph["look"]["face"], em)
        cap = -f.getbbox("H", anchor="ls")[1]

    for layer, name in (("back", name_back), ("ink", name_ink)):
        ini = ["[common]",
               "Baseline=%d" % baseline,
               "Top=%d" % (baseline - int(round(cap))),
               "LineSpacing=%d" % cell_h,
               # The whole cell is drawn: a letter's backing and tilt reach
               # past its advance.
               "DrawExtraPixelsLeft=%d" % (cell_w // 2),
               "DrawExtraPixelsRight=%d" % (cell_w // 2),
               "AdvanceExtraPixels=0",
               ""]
        for pname, page_glyphs in zip(page_names, pages):
            # The last page only has as many rows as it needs.
            used_rows = -(-len(page_glyphs) // columns)
            img = Image.new("RGBA", (columns * cell_w, used_rows * cell_h), (0, 0, 0, 0))
            lines = []
            ini.append("[%s]" % pname)
            for i, g in enumerate(page_glyphs):
                r, c = divmod(i, columns)
                if c == 0:
                    lines.append("")
                lines[-1] += g["ch"]
                if layer in g:
                    # The advance is centred in the cell; the origin sits at
                    # its start, on the baseline.
                    ox = c * cell_w + cell_w / 2 - g["adv"] / 2
                    oy = r * cell_h + baseline
                    img.alpha_composite(g[layer], (int(round(ox + g["left"])), int(round(oy + g["top"]))))
            png = "%s [%s] %dx%d.png" % (name, pname, columns, used_rows)
            img.save(os.path.join(font_dir, png), optimize=True)
            ini += ["Line %d=%s" % (i, line) for i, line in enumerate(lines)]
            ini += ["%d=%d" % (i, g["adv"]) for i, g in enumerate(page_glyphs)]
            ini.append("")
        with open(os.path.join(font_dir, name + ".ini"), "w", encoding="utf-8", newline="\r\n") as f:
            f.write("\n".join(ini))
    for redir, name in ((redir_back, name_back), (redir_ink, name_ink)):
        with open(os.path.join(theme, "Fonts", redir + ".redir"), "w", newline="\r\n") as f:
            f.write("Cutout/%s" % name)
    print("%s: em %d, cell %dx%d, %d glyphs on %d page(s) of %dx%d cells"
          % (name_ink, em, cell_w, cell_h, len(glyphs), len(pages), columns, rows))
    return glyphs


def lua_string(s):
    out = []
    for b in s.encode("utf-8"):
        ch = chr(b)
        if ch in '\\"':
            out.append("\\" + ch)
        elif 32 <= b < 127:
            out.append(ch)
        else:
            out.append("\\%d" % b)
    return '"' + "".join(out) + '"'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="directory with the source .ttf files")
    ap.add_argument("--theme", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    args = ap.parse_args()
    theme = os.path.abspath(args.theme)
    faces = load_faces(args.src)

    regular = build(CHARSET, faces, EM, theme, "_cutout back", "_cutout ink", "Cutout Back", "Cutout Ink")
    build(LARGE_CHARSET, faces, EM_LARGE, theme,
          "_cutout large back", "_cutout large ink", "Cutout Large Back", "Cutout Large Ink")

    covered = [g["ch"] for g in regular]
    out = ["-- GENERATED by tools/cutout-fonts/generate.py. Do not edit by hand.",
           "-- The baked cutout fonts (Fonts/Cutout Back, Cutout Ink, Cutout Large Back",
           "-- and Cutout Large Ink).  Per glyph, in em units of the regular fonts:",
           "--   {advance, left, top, right, bottom}",
           "-- left/right/top/bottom are the drawn extents (backing and tilt included)",
           "-- relative to the start of the advance on the baseline (top < 0).",
           "VOLT26.CutoutMetrics = {",
           "\tem = %d," % EM,
           "\temLarge = %d," % EM_LARGE,
           "\tfont = { back = \"Cutout Back\", ink = \"Cutout Ink\" },",
           "\tfontLarge = { back = \"Cutout Large Back\", ink = \"Cutout Large Ink\" },",
           "\tglyphs = {"]
    for g in regular:
        if "left" in g:
            out.append("\t\t[%s] = {%.4f, %.4f, %.4f, %.4f, %.4f}," % (
                lua_string(g["ch"]), g["adv"] / EM, g["left"] / EM, g["top"] / EM, g["right"] / EM, g["bottom"] / EM))
        else:
            out.append("\t\t[%s] = {%.4f, 0, 0, 0, 0}," % (lua_string(g["ch"]), g["adv"] / EM))
    out.append("\t},")
    out.append("\t-- Characters the large fonts carry.")
    out.append("\tlarge = {")
    for ch in LARGE_CHARSET:
        out.append("\t\t[%s] = true," % lua_string(ch))
    out.append("\t},")
    # Case maps for the covered letters (Lua's string.upper is ASCII-only).
    out.append("\tupper = {")
    for ch in covered:
        u = ch.upper()
        if u != ch and len(u) == 1 and u in covered:
            out.append("\t\t[%s] = %s," % (lua_string(ch), lua_string(u)))
    out.append("\t},")
    out.append("\tlower = {")
    for ch in covered:
        l = ch.lower()
        if l != ch and len(l) == 1 and l in covered:
            out.append("\t\t[%s] = %s," % (lua_string(ch), lua_string(l)))
    out.append("\t},")
    out.append("}")
    with open(os.path.join(theme, "Scripts", "VOLT26_CutoutMetrics.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
