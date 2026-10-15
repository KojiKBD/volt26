#!/usr/bin/env python3
"""Bake the "Are you LOST?" title of ScreenVOLT26Lost (the hidden song's
stinger) in the cutout lettering, at a high em, as one picture.

The letters are the cutout fonts' own looks (tools/cutout-fonts/generate.py:
the same faces, sizes, boxes and tilts per character), laid out as
VOLT26.Cutout lays out a string, with every backing under every letter.
"Are you" is white and "LOST?" red; the block's tilt is baked in, so the
sprite is never rotated at runtime (.agents/presentation.md).

Usage:
    python tools/secret/build_lost_title.py --src <dir with the .ttf files>
Writes Graphics/VOLT26/Secret/lost_title.png.
"""
import argparse
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "cutout-fonts"))
import generate as G  # noqa: E402

EM = 220
TILT = -4                      # degrees, as Cutout's tiltDeg (rotationz)
PARTS = [("Are you ", (255, 255, 255)), ("LOST?", (228, 0, 1))]
BACK = (0, 0, 0)


def tint(img, rgb):
    out = Image.new("RGBA", img.size, rgb + (0,))
    r, g, b, a = img.split()
    # Ink is white (and black inside boxes): keep its darkness, take the tint.
    lum = r
    px = Image.merge("RGBA", (
        lum.point(lambda v: v * rgb[0] // 255),
        lum.point(lambda v: v * rgb[1] // 255),
        lum.point(lambda v: v * rgb[2] // 255),
        a))
    out.alpha_composite(px)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--theme", default=os.path.join(HERE, "..", ".."))
    args = ap.parse_args()
    faces = G.load_faces(args.src)

    glyphs, pen = [], 0.0
    for text, colour in PARTS:
        for ch in text:
            look = G.choices(ch, faces) if ch != " " else None
            back, ink, ox, oy, adv = G.render(ch, look, EM)
            adv = int(round(adv))
            if back is not None:
                glyphs.append((pen, back, ink, ox, oy, colour))
            pen += adv

    S = int(EM * 4)
    W, H = int(pen + S), S
    base_y = H // 2
    backs = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    inks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for x, back, ink, ox, oy, colour in glyphs:
        at = (int(round(S / 2 + x - ox)), int(round(base_y - oy)))
        backs.alpha_composite(tint(back, BACK), at)
        inks.alpha_composite(tint(ink, colour), at)
    img = backs
    img.alpha_composite(inks)
    img = img.rotate(-TILT, resample=Image.BICUBIC, expand=True)
    img = img.crop(img.getbbox())
    out_dir = os.path.join(os.path.abspath(args.theme), "Graphics", "VOLT26", "Secret")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "lost_title.png")
    img.save(path, optimize=True)
    print(path, img.size)


if __name__ == "__main__":
    main()
