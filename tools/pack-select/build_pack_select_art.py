"""Crop and name the pack selection art for the theme.

Input: tools/pack-select/art/ as written by export_pack_select_art.jsx
(item_NN.png at 1920x1080 with the item's opacity baked in, items.json).
Output: Graphics/VOLT26/PackSelect/*.png, plus layout.txt listing the centre
of every placed piece in 1920x1080 design pixels (the figures used by
BGAnimations/ScreenVOLT26SelectPack overlay/Scene.lua).

Item ids refer to the mockup's top-level items, back to front:
  00 red ground, 02 dark vignette     -> bg.png (flattened, half size)
  01 VOLT26 RE:Spark logo (50%)       -> logo.png
  03 zig-zag stripes                  -> stripes.png
  10 black splash + white window + 4 stars -> splash.png, window filled black
  11 "CHOOSE YOUR PACK" lettering     -> title.png
  04 sparkle (all four-point sparkles share its shape) -> sparkle.png
  08 outlined star (06/07/09 share its shape)          -> star.png
  16 "pack name" placeholder text     -> not exported (the theme draws the name)

Usage: python build_pack_select_art.py [art_dir] [theme_root]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ART = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "art")
ROOT = sys.argv[2] if len(sys.argv) > 2 else os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "Graphics", "VOLT26", "PackSelect")
PAD = 2


def item(n):
    return Image.open(os.path.join(ART, "item_%02d.png" % n)).convert("RGBA")


def crop(im):
    l, t, r, b = im.getbbox()
    l, t = max(0, l - PAD), max(0, t - PAD)
    r, b = min(im.width, r + PAD), min(im.height, b + PAD)
    return im.crop((l, t, r, b)), ((l + r) / 2.0, (t + b) / 2.0)


def centre(n):
    return crop(item(n))[1]


def main():
    os.makedirs(OUT, exist_ok=True)
    layout = []

    bg = item(0)
    bg.alpha_composite(item(2))
    bg.convert("RGB").resize((960, 540), Image.LANCZOS).save(os.path.join(OUT, "bg.png"), optimize=True)

    for n, name in ((1, "logo"), (3, "stripes"), (11, "title"), (4, "sparkle"), (8, "star")):
        im, c = crop(item(n))
        im.save(os.path.join(OUT, name + ".png"), optimize=True)
        layout.append("%-8s centre %7.1f %7.1f  size %d x %d" % (name, c[0], c[1], im.width, im.height))

    # The splash: the white window becomes part of the black ground, so the
    # pack jacket (drawn square and only slightly turned) never shows white
    # corners around it.
    splash = item(10)
    seed = (950, 520)
    window = splash.copy()
    ImageDraw.floodfill(window, seed, (255, 0, 255, 255), thresh=60)
    # The window's anti-aliased edge is not reached by the fill; growing the
    # filled area by a few pixels takes it too (the window sits well inside
    # the black, away from the red outline).
    mask = Image.new("L", splash.size, 0)
    mpx, wpx = mask.load(), window.load()
    xs, ys = [], []
    for y in range(splash.height):
        for x in range(splash.width):
            if wpx[x, y] == (255, 0, 255, 255):
                mpx[x, y] = 255
                xs.append(x)
                ys.append(y)
    mask = mask.filter(ImageFilter.MaxFilter(7))
    splash.paste((0, 0, 0, 255), (0, 0), mask)
    im, c = crop(splash)
    im.save(os.path.join(OUT, "splash.png"), optimize=True)
    layout.append("%-8s centre %7.1f %7.1f  size %d x %d" % ("splash", c[0], c[1], im.width, im.height))
    layout.append("window   bounds %d %d %d %d" % (min(xs), min(ys), max(xs), max(ys)))

    for n in (4, 5, 12, 13, 14, 15):
        layout.append("sparkle%02d centre %7.1f %7.1f" % ((n,) + centre(n)))
    for n in (6, 7, 8, 9):
        im, c = crop(item(n))
        layout.append("star%02d   centre %7.1f %7.1f  size %d" % (n, c[0], c[1], im.width))

    with open(os.path.join(ART, "layout.txt"), "w") as f:
        f.write("\n".join(layout) + "\n")
    print("\n".join(layout))


if __name__ == "__main__":
    main()
