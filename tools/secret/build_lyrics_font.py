#!/usr/bin/env python3
"""Bake the hidden song's lyrics font (VOLT26.Secret, ScreenGameplay
underlay/Secret.lua): Archivo at its narrowest and heaviest (wdth 62,
wght 900), the condensed sans of the owner's chosen "Post Human" look.

Two bitmap fonts share one layout, as the cutout fonts do:
  Secret Lyrics Fill   the white letters (tinted at runtime: white, and the
                       red and cyan copies of the RGB split)
  Secret Lyrics Edge   the letters grown by an outline (tinted black)

Usage:
    python tools/secret/build_lyrics_font.py --src <dir with Archivo[wdth,wght].ttf>
Writes Fonts/Secret/_secret lyrics fill|edge [main] CxR.png + .ini and the
two .redir files.  Archivo is under the SIL OFL 1.1 (Fonts/Cutout/OFL-archivo.txt).
"""
import argparse, glob, io, math, os
import numpy as np
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

EM = 112          # font pixel size
OUTLINE = 7       # outline, pixels
PAGE = 1024
CHARSET = [chr(c) for c in range(0x20, 0x7F)] + list("ÀÈÉÌÒÙàèéìòù’‘“”–—…")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--theme", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    a = ap.parse_args()
    path = sorted(glob.glob(os.path.join(a.src, "Archivo[[]wdth,wght[]]*.ttf")))[0]
    tt = instancer.instantiateVariableFont(TTFont(path), {"wght": 900, "wdth": 62})
    buf = io.BytesIO(); tt.save(buf)
    cmap = set(tt.getBestCmap())
    font = ImageFont.truetype(io.BytesIO(buf.getvalue()), EM)
    chars = [c for c in CHARSET if ord(c) in cmap]

    asc, desc = font.getmetrics()
    pad = OUTLINE + 3
    cell_h = asc + desc + 2 * pad
    advs = {c: int(round(font.getlength(c))) for c in chars}
    cell_w = max(advs.values()) + 2 * pad + 8
    cols, rows = PAGE // cell_w, PAGE // cell_h
    per = cols * rows
    pages = [chars[i:i + per] for i in range(0, len(chars), per)]
    names = ["main"] + ["p%d" % (i + 2) for i in range(len(pages) - 1)]
    baseline = pad + asc
    cap = -font.getbbox("H", anchor="ls")[1]

    out = os.path.join(os.path.abspath(a.theme), "Fonts", "Secret")
    os.makedirs(out, exist_ok=True)
    for layer in ("fill", "edge"):
        name = "_secret lyrics %s" % layer
        ini = ["[common]", "Baseline=%d" % baseline, "Top=%d" % (baseline - cap),
               "LineSpacing=%d" % cell_h, "DrawExtraPixelsLeft=%d" % (cell_w // 2),
               "DrawExtraPixelsRight=%d" % (cell_w // 2), "AdvanceExtraPixels=0", ""]
        for pname, pchars in zip(names, pages):
            used = -(-len(pchars) // cols)
            mask = Image.new("L", (cols * cell_w, used * cell_h), 0)
            d = ImageDraw.Draw(mask)
            lines = []
            for i, c in enumerate(pchars):
                r, k = divmod(i, cols)
                if k == 0: lines.append("")
                lines[-1] += c
                # The advance is centred in the cell, on the baseline.
                x = k * cell_w + cell_w / 2 - advs[c] / 2
                d.text((x, r * cell_h + baseline), c, font=font, anchor="ls", fill=255)
            if layer == "edge":
                m = np.asarray(mask, dtype=np.float32) / 255
                dist = ndimage.distance_transform_edt(m < 0.5)
                grown = np.clip(OUTLINE - dist + 0.5, 0, 1)
                mask = Image.fromarray((np.maximum(grown, m) * 255).astype(np.uint8))
            img = Image.new("RGBA", mask.size, (255, 255, 255, 0))
            img.putalpha(mask)
            img.save(os.path.join(out, "%s [%s] %dx%d.png" % (name, pname, cols, used)), optimize=True)
            ini.append("[%s]" % pname)
            ini += ["Line %d=%s" % (i, l) for i, l in enumerate(lines)]
            ini += ["%d=%d" % (i, advs[c]) for i, c in enumerate(pchars)]
            ini.append("")
        with open(os.path.join(out, name + ".ini"), "w", encoding="utf-8", newline="\r\n") as f:
            f.write("\n".join(ini))
        with open(os.path.join(os.path.abspath(a.theme), "Fonts", "Secret Lyrics %s.redir" % layer.capitalize()), "w", newline="\r\n") as f:
            f.write("Secret/%s" % name)
    print("cell %dx%d, %d chars, %d page(s) of %dx%d, cap %d" % (cell_w, cell_h, len(chars), len(pages), cols, rows, cap))


if __name__ == "__main__":
    main()
