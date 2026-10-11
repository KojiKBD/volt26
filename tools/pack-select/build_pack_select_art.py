"""Crop and name the pack selection art for the theme.

Input: tools/pack-select/art/ as written by export_pack_select_art.jsx
(item_NN.png at 1920x1080 with the item's opacity baked in, items.json).
Output: Graphics/VOLT26/PackSelect/*.png, plus art/layout.txt listing the
centre of every placed piece in 1920x1080 design pixels (the figures used by
BGAnimations/ScreenVOLT26SelectPack overlay/Scene.lua).

The export numbers items back to front, so the numbers change whenever the
mockup gains or loses an item.  Pieces are recognised from items.json by type
and size instead:
  full-bleed items (cover the artboard)  -> bg.png, flattened, half size
  group wider than 1200 px               -> stripes.png
  group 800-1100 px wide                 -> splash.png (black frame, white
                                            window, the four stars on it)
  raster item                            -> title.png
  path 60-90 px                          -> sparkle.png (all share a shape)
  group 30-90 px                         -> star.png (the largest; smaller
                                            ones are the same star scaled)
  text frames                            -> ignored (the theme draws the name)
Anything else is reported and left out.

Usage: python build_pack_select_art.py [art_dir] [theme_root]
"""
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ART = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "art")
ROOT = sys.argv[2] if len(sys.argv) > 2 else os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "Graphics", "VOLT26", "PackSelect")
W, H = 1920, 1080
PAD = 2


def load(entry):
    return Image.open(os.path.join(ART, "item_%s.png" % entry["id"])).convert("RGBA")


def crop(im):
    l, t, r, b = im.getbbox()
    l, t = max(0, l - PAD), max(0, t - PAD)
    r, b = min(im.width, r + PAD), min(im.height, b + PAD)
    return im.crop((l, t, r, b)), ((l + r) / 2.0, (t + b) / 2.0)


def classify(entry):
    l, t, r, b = entry["bounds"]
    w = r - l
    kind = entry["type"]
    if kind == "TextFrame":
        return "ignore"
    if l <= 0 and t <= 0 and r >= W and b >= H:
        return "bg"
    if kind == "RasterItem":
        return "title"
    if kind == "GroupItem" and w > 1200:
        return "stripes"
    if kind == "GroupItem" and 800 <= w <= 1100:
        return "splash"
    if kind == "PathItem" and 60 <= w <= 90:
        return "sparkle"
    if kind == "GroupItem" and 30 <= w <= 90:
        return "star"
    return "unknown"


def main():
    with open(os.path.join(ART, "items.json"), encoding="utf-8") as f:
        items = json.load(f)
    groups = {}
    for entry in items:
        groups.setdefault(classify(entry), []).append(entry)
    for entry in groups.get("unknown", []):
        print("left out: item %s (%s, bounds %s)" % (entry["id"], entry["type"], entry["bounds"]))
    for need in ("bg", "stripes", "splash", "title", "sparkle", "star"):
        if not groups.get(need):
            sys.exit("no %s item found in items.json" % need)

    os.makedirs(OUT, exist_ok=True)
    layout = []

    bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for entry in groups["bg"]:
        bg.alpha_composite(load(entry))
    bg.convert("RGB").resize((W // 2, H // 2), Image.LANCZOS).save(os.path.join(OUT, "bg.png"), optimize=True)
    layout.append("bg       items %s" % " ".join(e["id"] for e in groups["bg"]))

    def single(kind, entry):
        im, c = crop(load(entry))
        im.save(os.path.join(OUT, kind + ".png"), optimize=True)
        layout.append("%-8s centre %7.1f %7.1f  size %d x %d" % (kind, c[0], c[1], im.width, im.height))
        return im

    single("stripes", groups["stripes"][0])
    single("title", groups["title"][0])
    splash = single("splash", max(groups["splash"], key=lambda e: e["bounds"][2] - e["bounds"][0]))
    del splash

    # The splash's white window frames the focused jacket; its bounds are
    # measured for the layout.
    window = load(groups["splash"][0])
    ImageDraw.floodfill(window, (950, 520), (255, 0, 255, 255), thresh=60)
    wpx = window.load()
    xs, ys = [], []
    for y in range(H):
        for x in range(W):
            if wpx[x, y] == (255, 0, 255, 255):
                xs.append(x)
                ys.append(y)
    layout.append("window   bounds %d %d %d %d" % (min(xs), min(ys), max(xs), max(ys)))

    single("sparkle", groups["sparkle"][0])
    for entry in groups["sparkle"]:
        layout.append("sparkle  at %7.1f %7.1f" % crop(load(entry))[1])

    big = max(groups["star"], key=lambda e: e["bounds"][2] - e["bounds"][0])
    star = single("star", big)
    for entry in groups["star"]:
        im, c = crop(load(entry))
        layout.append("star     at %7.1f %7.1f  zoom %.2f" % (c[0], c[1], im.width / float(star.width)))

    with open(os.path.join(ART, "layout.txt"), "w") as f:
        f.write("\n".join(layout) + "\n")
    print("\n".join(layout))


if __name__ == "__main__":
    main()
