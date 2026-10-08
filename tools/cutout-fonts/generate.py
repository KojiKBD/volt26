#!/usr/bin/env python3
"""Generate the VOLT26 cutout-lettering bitmap fonts and their Lua metrics.

ITGmania cannot rasterise TrueType at runtime, so every face used by the
cutout lettering (Scripts/VOLT26_Cutout.lua) is baked here into a single
StepMania font page plus an .ini, and the per-glyph metrics the layout needs
(advance and ink extents, in em units) are written to a generated Lua table.

Usage (from the theme root):
    python tools/cutout-fonts/generate.py --src <dir with the .ttf files>

Requires Pillow and fontTools.  Re-run after changing EM, CHARSET or FACES.
"""
import argparse
import io
import os
import unicodedata

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image, ImageDraw, ImageFont

# Rendered em size in texture pixels.  The largest em that still fits every
# glyph of a face on one 1024x1024 page (4 MB of VRAM per face); the lettering
# is drawn at roughly 50-70 px per letter on a 1080p display.
EM = int(os.environ.get("CUTOUT_EM", 48))
PAD = 2          # transparent gutter around each glyph cell
MAX_TEXTURE = 1024

# (face id, file, variation axes, licence file)
FACES = [
    ("tinos",     "Tinos-Bold.ttf",        {},                          "OFL"),
    ("caprasimo", "Caprasimo-Regular.ttf", {},                          "OFL"),
    ("spartan",   "LeagueSpartan-VF.ttf",  {"wght": 700},               "OFL"),
    ("besley",    "Besley-VF.ttf",         {"wght": 800},               "OFL"),
    ("jost",      "Jost-VF.ttf",           {"wght": 700},               "OFL"),
    ("archivo",   "Archivo-VF.ttf",        {"wght": 800, "wdth": 100},  "OFL"),
]

# Printable ASCII, the Latin-1 letters, and the Latin Extended-A letters most
# common in European player names.  Anything else falls back to plain text.
EXTENDED_A = "ĄąĆćČčĎďĘęĚěĞğİıŁłŃńŇňŐőœŘřŚśŞşŠšŤťŰűŮůŹźŻżŽž"
CHARSET = (
    [chr(c) for c in range(0x20, 0x7F)]
    # Æ and Œ are left out: in Besley they are wide enough to force a second
    # texture page for every face.  Their lower-case forms stay lower case.
    + [chr(c) for c in range(0xC0, 0x100) if c not in (0xC6, 0xD7, 0xF7)]
    + list(EXTENDED_A)
)


def instance(path, axes):
    font = TTFont(path)
    if axes and "fvar" in font:
        font = instancer.instantiateVariableFont(font, axes)
    buf = io.BytesIO()
    font.save(buf)
    buf.seek(0)
    return font, buf


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
    ap.add_argument("--theme", default=os.path.join(os.path.dirname(__file__), "..", ".."))
    args = ap.parse_args()
    theme = os.path.abspath(args.theme)
    font_dir = os.path.join(theme, "Fonts", "Cutout")
    os.makedirs(font_dir, exist_ok=True)

    faces = []
    for face_id, filename, axes, _ in FACES:
        tt, buf = instance(os.path.join(args.src, filename), axes)
        cmap = tt.getBestCmap()
        pil = ImageFont.truetype(buf, EM)
        glyphs = {}
        for ch in CHARSET:
            if ch != " " and ord(ch) not in cmap:
                continue
            adv = pil.getlength(ch)
            box = pil.getbbox(ch, anchor="ls")  # x0, y0 (neg = above), x1, y1
            glyphs[ch] = (adv, box)
        faces.append((face_id, pil, glyphs))

    # One cell size shared by every face keeps the pages uniform.
    ascent = max(-b[1] for _, _, g in faces for _, b in g.values())
    descent = max(b[3] for _, _, g in faces for _, b in g.values())
    width = max(max(adv, b[2] - min(b[0], 0)) for _, _, g in faces for adv, b in g.values())
    cell_w = int(width) + 2 * PAD + 2
    cell_w += cell_w % 2
    cell_h = int(ascent + descent) + 2 * PAD + 2
    columns = MAX_TEXTURE // cell_w
    rows = -(-len(CHARSET) // columns)
    tex_w, tex_h = cell_w * columns, cell_h * rows
    if tex_h > MAX_TEXTURE:
        raise SystemExit("EM %d does not fit a %dpx page (%dx%d); lower EM" % (EM, MAX_TEXTURE, tex_w, tex_h))
    baseline = PAD + 1 + int(round(ascent))

    metrics = []
    for face_id, pil, glyphs in faces:
        page = Image.new("RGBA", (tex_w, tex_h), (255, 255, 255, 0))
        draw = ImageDraw.Draw(page)
        lines, widths = [], []
        for i, ch in enumerate(CHARSET):
            row, col = divmod(i, columns)
            if col == 0:
                lines.append("")
            # A face that lacks a glyph still occupies the frame (as a space)
            # so every page shares one layout; the metrics omit it, which is
            # how the Lua layout knows to pick another face for that letter.
            glyph = glyphs.get(ch)
            lines[-1] += ch if glyph else " "
            adv = int(round(glyph[0])) if glyph else int(round(glyphs[" "][0]))
            widths.append(adv)
            if glyph and ch != " ":
                x = col * cell_w + (cell_w - adv) / 2
                y = row * cell_h + baseline
                draw.text((x, y), ch, font=pil, anchor="ls", fill=(255, 255, 255, 255))
        cap = -pil.getbbox("H", anchor="ls")[1]
        name = "_cutout %s" % face_id
        png = "%s [main] %dx%d.png" % (name, columns, rows)
        page.save(os.path.join(font_dir, png), optimize=True)
        ini = ["[common]",
               "Baseline=%d" % baseline,
               "Top=%d" % (baseline - int(round(cap))),
               "LineSpacing=%d" % cell_h,
               "DrawExtraPixelsLeft=%d" % (cell_w // 2),
               "DrawExtraPixelsRight=%d" % (cell_w // 2),
               "AdvanceExtraPixels=0",
               "",
               "[main]"]
        ini += ["Line %d=%s" % (i, line) for i, line in enumerate(lines)]
        ini += ["%d=%d" % (i, w) for i, w in enumerate(widths)]
        with open(os.path.join(font_dir, name + ".ini"), "w", encoding="utf-8", newline="\r\n") as f:
            f.write("\n".join(ini) + "\n")
        with open(os.path.join(theme, "Fonts", "Cutout %s.redir" % face_id.capitalize()), "w", newline="\r\n") as f:
            f.write("Cutout/%s" % name)
        metrics.append((face_id, glyphs))

    # Generated Lua: advance and ink extents per glyph, in em units, plus the
    # case map for the covered letters (Lua's string.upper is ASCII-only).
    out = ["-- GENERATED by tools/cutout-fonts/generate.py. Do not edit by hand.",
           "-- Per-face glyph metrics in em units: {advance, ink above baseline, ink below baseline}.",
           "VOLT26.CutoutMetrics = {",
           "\tem = %d," % EM,
           "\tfaces = {"]
    for face_id, glyphs in metrics:
        out.append("\t\t{ id = %s, font = %s, glyphs = {" % (lua_string(face_id), lua_string("Cutout " + face_id.capitalize())))
        for ch, (adv, box) in glyphs.items():
            out.append("\t\t\t[%s] = {%.4f, %.4f, %.4f}," % (lua_string(ch), adv / EM, -box[1] / EM, box[3] / EM))
        out.append("\t\t} },")
    out.append("\t},")
    out.append("\tupper = {")
    for ch in CHARSET:
        u = ch.upper()
        if u != ch and len(u) == 1 and u in CHARSET:
            out.append("\t\t[%s] = %s," % (lua_string(ch), lua_string(u)))
    out.append("\t},")
    out.append("\tlower = {")
    for ch in CHARSET + ["\u00c6", "\u0152"]:
        l = ch.lower()
        if l != ch and len(l) == 1 and l in CHARSET:
            out.append("\t\t[%s] = %s," % (lua_string(ch), lua_string(l)))
    out.append("\t},")
    out.append("}")
    with open(os.path.join(theme, "Scripts", "VOLT26_CutoutMetrics.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("cell %dx%d, page %dx%d, %d glyphs, baseline %d" % (cell_w, cell_h, tex_w, tex_h, len(CHARSET), baseline))


if __name__ == "__main__":
    main()
