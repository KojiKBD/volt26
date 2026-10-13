#!/usr/bin/env python3
"""Generate the bitmap fonts of the P5 evaluation screen.

ITGmania cannot rasterise TrueType at runtime, so each face is baked into one
StepMania font page plus an .ini under Fonts/VOLT26 Eval/, with a .redir per
font in Fonts/.  The stand-ins follow docs/cutout-lettering.md:

    Times New Roman Bold           -> Tinos Bold                 (title)
    Helvetica Now Display Medium   -> Archivo wght 500           (labels)
    Helvetica Now Display Bold     -> Archivo wght 700           (counts, mods)
    Helvetica Now Display Black It -> Archivo Italic wght 900    (scores, level)

Usage (from the theme root):
    python tools/evaluation/build_fonts.py --src <dir with the .ttf files>

Source files (google/fonts, OFL): Tinos-Bold.ttf, Archivo[wdth,wght].ttf,
Archivo-Italic[wdth,wght].ttf.  Requires Pillow and fontTools.
"""
import argparse
import io
import os

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image, ImageDraw, ImageFont

PAD = 2
EXTENDED_A = "ĄąĆćČčĎďĘęĚěĞğİıŁłŃńŇňŐőŒœŘřŚśŞşŠšŤťŰűŮůŹźŻżŽž"
TEXT = [chr(c) for c in range(0x20, 0x7F)] + [chr(c) for c in range(0xA1, 0x100)] + list("–—‘’“”…")
# The title face also gets the Latin Extended-A letters of European names.
TITLE = TEXT + list(EXTENDED_A)
SCORE = list(" 0123456789.,/%+-:·LVEXITGABCDFSQlvexitg")

# (font name, file, axes, em in texture pixels, charset, page width, page height)
# Every em is the largest whose page fits the given size (StepMania pads a page
# to powers of two, so 2048x1024 is 8 MB of video memory, 1024x1024 4 MB).
FONTS = [
    ("Title", "Tinos-Bold.ttf", {}, 78, TITLE, 2048, 1024),
    ("Label", "Archivo[wdth,wght].ttf", {"wght": 500, "wdth": 100}, 48, TEXT, 1024, 1024),
    ("Bold", "Archivo[wdth,wght].ttf", {"wght": 700, "wdth": 100}, 48, TEXT, 1024, 1024),
    ("Score", "Archivo-Italic[wdth,wght].ttf", {"wght": 900, "wdth": 100}, 96, SCORE, 1024, 512),
]


def instance(path, axes):
    font = TTFont(path)
    if axes and "fvar" in font:
        font = instancer.instantiateVariableFont(font, axes)
    buf = io.BytesIO()
    font.save(buf)
    buf.seek(0)
    return font, buf


def build(theme, src, name, filename, axes, em, charset, max_w, max_h):
    tt, buf = instance(os.path.join(src, filename), axes)
    cmap = tt.getBestCmap()
    pil = ImageFont.truetype(buf, em)
    chars = [ch for ch in charset if ch == " " or ord(ch) in cmap]
    glyphs = {ch: (pil.getlength(ch), pil.getbbox(ch, anchor="ls")) for ch in chars}
    ascent = max(-b[1] for _, b in glyphs.values())
    descent = max(b[3] for _, b in glyphs.values())
    # Italic glyphs overhang their advance; the cell holds the whole ink.
    width = max(max(adv, b[2]) - min(b[0], 0) for adv, b in glyphs.values())
    cell_w = int(width) + 2 * PAD + 2
    cell_w += cell_w % 2
    cell_h = int(ascent + descent) + 2 * PAD + 2
    columns = max_w // cell_w
    rows = -(-len(chars) // columns)
    tex_w, tex_h = cell_w * columns, cell_h * rows
    if tex_h > max_h:
        raise SystemExit("%s: em %d needs %dx%d, more than %dx%d" % (name, em, tex_w, tex_h, max_w, max_h))
    baseline = PAD + 1 + int(round(ascent))

    page = Image.new("RGBA", (tex_w, tex_h), (255, 255, 255, 0))
    draw = ImageDraw.Draw(page)
    lines, widths = [], []
    for i, ch in enumerate(chars):
        row, col = divmod(i, columns)
        if col == 0:
            lines.append("")
        lines[-1] += ch
        adv = int(round(glyphs[ch][0]))
        widths.append(adv)
        if ch != " ":
            # The advance box is centred in the cell; the frame's extra pixels
            # (half a cell each side) let overhanging ink draw.
            x = col * cell_w + (cell_w - adv) / 2
            draw.text((x, row * cell_h + baseline), ch, font=pil, anchor="ls", fill=(255, 255, 255, 255))

    folder = os.path.join(theme, "Fonts", "VOLT26 Eval")
    os.makedirs(folder, exist_ok=True)
    stem = "_eval %s" % name.lower()
    page.save(os.path.join(folder, "%s [main] %dx%d.png" % (stem, columns, rows)), optimize=True)
    cap = -pil.getbbox("H" if "H" in glyphs else "0", anchor="ls")[1]
    ini = ["[common]",
           "Baseline=%d" % baseline,
           "Top=%d" % (baseline - int(round(cap))),
           "LineSpacing=%d" % int(round(em * 1.2)),
           "DrawExtraPixelsLeft=%d" % (cell_w // 2),
           "DrawExtraPixelsRight=%d" % (cell_w // 2),
           "AdvanceExtraPixels=0",
           "",
           "[main]"]
    ini += ["Line %d=%s" % (i, line) for i, line in enumerate(lines)]
    ini += ["%d=%d" % (i, w) for i, w in enumerate(widths)]
    with open(os.path.join(folder, stem + ".ini"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(ini) + "\n")
    with open(os.path.join(theme, "Fonts", "VOLT26 Eval %s.redir" % name), "w", newline="\r\n") as f:
        f.write("VOLT26 Eval/%s" % stem)
    print("%-6s em %3d cell %3dx%3d page %4dx%4d %3d glyphs cap %.1f" % (name, em, cell_w, cell_h, tex_w, tex_h, len(chars), cap))
    return em, cap


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--theme", default=os.path.join(os.path.dirname(__file__), "..", ".."))
    args = ap.parse_args()
    for spec in FONTS:
        build(os.path.abspath(args.theme), args.src, *spec)


if __name__ == "__main__":
    main()
