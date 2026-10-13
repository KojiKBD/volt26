#!/usr/bin/env python3
"""Build the P5 evaluation screen's art from the owner's Illustrator SVG.

The artwork is the Illustrator document exported as SVG (the same document as
the notes radar: tools/notes-radar/art/radar.svg).  It holds several screens;
the evaluation's first page is the artboard whose top-left corner is at
ARTBOARD below, drawn by the top-level items listed in BACKDROP / PANEL.

Outputs (paths relative to the theme root):

  Graphics/VOLT26/Wanted/backdrop.png   1920x1080, shared by both players:
      white ground, star pattern, curves, the black WANTED frame, "WANTED".
  Graphics/VOLT26/Wanted/panel_head.png player 1's top plates (name,
      level, scores) without text, cropped to HEAD_CROP.
  Graphics/VOLT26/Wanted/panel_body.png player 1's judgment ladder, holds
      box and graph frame without text, cropped to BODY_CROP.  The body stays
      when a player turns to another page; the head is on every page.
      Player 2 draws both mirrored.
  BGAnimations/ScreenEvaluationStage overlay/Wanted/Art.lua   generated
      anchors: the song window polygon and its triangulation, the song
      picture's box, the graph quad, every text's position/rotation/scale,
      and the name and grade boxes.  All in artboard pixels (1920x1080).

Text, the song picture, the name, the grade and the graph are drawn by the
screen, so they are hidden when the pictures are rendered.

Usage (from the theme root):
    python tools/evaluation/build_eval_art.py [--svg tools/notes-radar/art/radar.svg]

Requires Playwright with Chromium (it renders the SVG exactly as a browser
does) and lxml.  Fonts: install Tinos and Archivo where Chromium finds them
(fontconfig) and alias "Times New Roman" to Tinos, so "WANTED" renders in the
stand-in the screen's title uses.

If the artwork's structure changes, update ARTBOARD, the item indices and the
HIDE paths: items are the children of Layer_1, counted from 0 in document order
(defs and styles are not children of Layer_1).
"""
import argparse
import json
import math
import os
import re

from lxml import etree
from playwright.sync_api import sync_playwright

ARTBOARD = (87.2, 2804.0)          # top-left of the evaluation artboard
W, H = 1920, 1080

# Layer_1 children of the evaluation artboard.
ITEM_WHITE, ITEM_STARS, ITEM_BLACK_CURVE, ITEM_STRIP, ITEM_RED_CURVE = 428, 429, 430, 431, 432
ITEM_FRAME, ITEM_WANTED, ITEM_SONG, ITEM_WINDOW = 434, 435, 436, 437
ITEM_PLATES, ITEM_LADDER, ITEM_GRAPH, ITEM_MODS, ITEM_TITLE = 438, 439, 440, 441, 442

BACKDROP = [ITEM_WHITE, ITEM_STARS, ITEM_BLACK_CURVE, ITEM_STRIP, ITEM_RED_CURVE, ITEM_FRAME, ITEM_WANTED]
HEAD = [ITEM_PLATES]
BODY = [ITEM_LADDER, ITEM_GRAPH]
# Paths (child indices below a Layer_1 item) hidden in the panel picture.
PANEL_HIDE = [
    [ITEM_PLATES, 1],            # the name placeholder picture
    [ITEM_PLATES, 2, 0],         # "L" (outlined; drawn as text so that the
    [ITEM_PLATES, 2, 1],         # "V"  mirrored side still reads "LV")
    [ITEM_PLATES, 2, 2],         # level digits "1"
    [ITEM_PLATES, 2, 3],         # level digits "5"
    [ITEM_LADDER, 1],            # the grade placeholder picture
    [ITEM_GRAPH, 1, 1],          # placeholder density profile
    [ITEM_GRAPH, 1, 2],          # placeholder line
]
HEAD_CROP = (0, 0, 832, 400)     # x, y, w, h in artboard pixels
BODY_CROP = (0, 360, 832, 720)

SVG_NS = "{http://www.w3.org/2000/svg}"


def layer_items(root):
    layer = next(e for e in root.iter(SVG_NS + "g") if e.get("id") == "Layer_1")
    return [c for c in layer if isinstance(c.tag, str)]


def points(attr):
    v = [float(n) for n in re.split(r"[\s,]+", attr.strip())]
    return [(v[i] - ARTBOARD[0], v[i + 1] - ARTBOARD[1]) for i in range(0, len(v), 2)]


def area(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
               for i in range(len(poly))) / 2


def triangulate(poly):
    """Ear clipping; returns 1-based index triples (Lua)."""
    pts = poly[:-1] if poly[0] == poly[-1] else poly[:]
    idx = list(range(len(pts)))
    if area(pts) < 0:
        idx.reverse()

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    def inside(p, a, b, c):
        return cross(a, b, p) >= 0 and cross(b, c, p) >= 0 and cross(c, a, p) >= 0

    tris = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if cross(a, b, c) <= 0:
                continue
            if any(inside(pts[j], a, b, c) for j in idx if j not in (i0, i1, i2)):
                continue
            tris.append((i0 + 1, i1 + 1, i2 + 1))
            del idx[k]
            break
        else:
            raise SystemExit("window polygon could not be triangulated")
    tris.append(tuple(i + 1 for i in idx))
    return pts, tris


def transform_of(use):
    """translate(x y) rotate(r) scale(s) of an Illustrator <use>/<image>."""
    t = use.get("transform", "")
    tx, ty = map(float, re.search(r"translate\(([-\d.]+)[ ,]+([-\d.]+)\)", t).groups())
    r = re.search(r"rotate\(([-\d.]+)\)", t)
    s = re.search(r"scale\(([-\d.]+)\)", t)
    return tx - ARTBOARD[0], ty - ARTBOARD[1], float(r.group(1)) if r else 0.0, float(s.group(1)) if s else 1.0


def image_box(root, use):
    """Centre, size and rotation of a placed picture."""
    href = use.get("{http://www.w3.org/1999/xlink}href") or use.get("href")
    image = next(e for e in root.iter(SVG_NS + "image") if e.get("id") == href.lstrip("#"))
    w, h = float(image.get("width")), float(image.get("height"))
    x, y, rot, s = transform_of(use)
    c, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    hw, hh = w * s / 2, h * s / 2
    return {"cx": x + hw * c - hh * sn, "cy": y + hw * sn + hh * c, "w": w * s, "h": h * s, "rot": rot}


def cover_box(poly, rot, aspect):
    """The smallest box of the given aspect, turned by rot, covering poly."""
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    local = [(x * c + y * s, -x * s + y * c) for x, y in poly]
    x0, x1 = min(p[0] for p in local), max(p[0] for p in local)
    y0, y1 = min(p[1] for p in local), max(p[1] for p in local)
    w, h = x1 - x0, y1 - y0
    if w / h > aspect:
        h = w / aspect
    else:
        w = h * aspect
    lx, ly = (x0 + x1) / 2, (y0 + y1) / 2
    return {"cx": lx * c - ly * s, "cy": lx * s + ly * c, "w": w, "h": h, "rot": rot}


RENDER_JS = """([keep, hide]) => {
  const L = document.getElementById('Layer_1');
  [...L.children].forEach((c, i) => { c.style.display = keep.includes(i) ? '' : 'none'; });
  document.querySelectorAll('[data-hidden]').forEach(e => { e.style.display = ''; e.removeAttribute('data-hidden'); });
  for (const path of hide) {
    let e = L; for (const k of path) e = e.children[k];
    e.style.display = 'none'; e.setAttribute('data-hidden', '1');
  }
  // Text is drawn by the screen.
  for (const i of keep) L.children[i].querySelectorAll('text').forEach(t => {
    if (!t.hasAttribute('data-hidden')) { t.style.display = 'none'; t.setAttribute('data-hidden', '1'); }
  });
}"""

TEXT_JS = """(items) => {
  const L = document.getElementById('Layer_1');
  const root = document.documentElement;
  const out = {};
  for (const [name, i] of Object.entries(items)) {
    const el = L.children[i];
    const texts = el.tagName === 'text' ? [el] : [...el.querySelectorAll('text')];
    out[name] = texts.map(t => {
      const m = root.getCTM().inverse().multiply(t.getCTM());
      const leaves = [...t.querySelectorAll('tspan')].filter(x => !x.querySelector('tspan'));
      return { m: [m.a, m.b, m.c, m.d, m.e, m.f],
        spans: (leaves.length ? leaves : [t]).map(s => { const cs = getComputedStyle(s);
          return { text: s.textContent, x: +(s.getAttribute('x') || 0), y: +(s.getAttribute('y') || 0),
                   fill: cs.fill, size: parseFloat(cs.fontSize) }; }) };
    });
  }
  return out;
}"""


def placement(m):
    a, b, c, d, e, f = m
    sx = math.hypot(a, b)
    return {"x": e - ARTBOARD[0], "y": f - ARTBOARD[1], "rot": math.degrees(math.atan2(b, a)),
            "sx": sx, "sy": (a * d - b * c) / sx}


def rule(items, which):
    """Length of the rule under the EX (1) or ITG (2) score."""
    line = items[ITEM_PLATES][3][which][1]
    return abs(float(line.get("x2")) - float(line.get("x1")))


def lua(value, indent=0):
    pad = "\t" * indent
    if isinstance(value, dict):
        items = ["%s\t%s = %s," % (pad, k, lua(v, indent + 1)) for k, v in value.items()]
        return "{\n" + "\n".join(items) + "\n" + pad + "}"
    if isinstance(value, (list, tuple)):
        if all(isinstance(v, (int, float)) for v in value):
            return "{" + ", ".join(lua(v) for v in value) + "}"
        return "{\n" + "\n".join("%s\t%s," % (pad, lua(v, indent + 1)) for v in value) + "\n" + pad + "}"
    if isinstance(value, float):
        return ("%.2f" % value).rstrip("0").rstrip(".")
    if isinstance(value, str):
        return '"' + value.replace('"', '\\"') + '"'
    return str(value)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--svg", default="tools/notes-radar/art/radar.svg")
    ap.add_argument("--theme", default=os.path.join(os.path.dirname(__file__), "..", ".."))
    args = ap.parse_args()
    theme = os.path.abspath(args.theme)
    svg_path = os.path.abspath(args.svg)

    root = etree.parse(svg_path, etree.XMLParser(huge_tree=True)).getroot()
    items = layer_items(root)

    window = points(items[ITEM_WINDOW].get("points"))
    window_pts, window_tris = triangulate(window)
    graph_poly = points(items[ITEM_GRAPH][1][0].get("points"))
    song_use = items[ITEM_SONG][0]
    _, _, song_rot, _ = transform_of(song_use)
    name_box = image_box(root, items[ITEM_PLATES][1])
    grade_box = image_box(root, items[ITEM_LADDER][1])

    # The level digits are outlined: their ink boxes are measured below.
    source = open(svg_path, encoding="utf-8").read()
    out_dir = os.path.join(theme, "Graphics", "VOLT26", "Wanted")
    os.makedirs(out_dir, exist_ok=True)
    work = os.path.join(os.path.dirname(svg_path), "_eval_render.svg")
    vb = 'viewBox="%g %g %d %d" width="%d" height="%d"' % (ARTBOARD[0], ARTBOARD[1], W, H, W, H)
    open(work, "w", encoding="utf-8").write(re.sub(r'viewBox="[^"]*"', vb, source, count=1))
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(args=["--allow-file-access-from-files"])
            page = browser.new_page(viewport={"width": W, "height": H})
            page.goto("file://" + work)
            page.wait_for_timeout(500)
            # Measure while everything is shown (hidden text has no geometry).
            texts = page.evaluate(TEXT_JS, {"plates": ITEM_PLATES, "ladder": ITEM_LADDER,
                                             "mods": ITEM_MODS, "title": ITEM_TITLE})
            digits = page.evaluate("""(i) => {
                const g = document.getElementById('Layer_1').children[i].children[2];
                return [...g.children].map(e => { const r = e.getBoundingClientRect();
                    return [r.x, r.y, r.width, r.height]; }); }""", ITEM_PLATES)
            page.evaluate(RENDER_JS, [BACKDROP, []])
            page.wait_for_timeout(100)
            page.screenshot(path=os.path.join(out_dir, "backdrop.png"))
            for name, keep, crop in (("panel_head", HEAD, HEAD_CROP), ("panel_body", BODY, BODY_CROP)):
                page.evaluate(RENDER_JS, [keep, PANEL_HIDE])
                page.wait_for_timeout(100)
                x, y, w, h = crop
                page.screenshot(path=os.path.join(out_dir, name + ".png"), omit_background=True,
                                clip={"x": x, "y": y, "width": w, "height": h})
            browser.close()
    finally:
        os.remove(work)

    plates, ladder = texts["plates"], texts["ladder"]
    rows = [dict(placement(t["m"]), size=t["spans"][0]["size"]) for t in ladder[:7]]
    extra = ladder[7]
    ell, vee, one, five = digits
    level_rot = math.degrees(math.atan2((five[1] + five[3]) - (one[1] + one[3]), five[0] - one[0]))
    art = {
        "window": {"points": [list(p) for p in window_pts], "triangles": [list(t) for t in window_tris]},
        "song": cover_box(window_pts, song_rot, 16 / 9),
        "graph": {"topLeft": list(graph_poly[1]), "topRight": list(graph_poly[2]),
                  "bottomRight": list(graph_poly[3]), "bottomLeft": list(graph_poly[0])},
        "head": dict(zip("xywh", HEAD_CROP)),
        "body": dict(zip("xywh", BODY_CROP)),
        # The scatter plot's on-time line in the artwork (its height on the graph).
        "zeroLine": 0.5,
        "name": name_box,
        "grade": grade_box,
        # Baseline-left of the level number, its ink height and its slope.
        # The level digits' advance is held to the artwork's (two digits
        # span the "15" there).
        # "LV": its left edge, baseline, cap height and width; the digits
        # follow at `gap` (both along the slope).
        "level": {"x": ell[0], "y": ell[1] + ell[3], "rot": level_rot,
                  "lvCap": ell[3], "lvWidth": vee[0] + vee[2] - ell[0],
                  "gap": math.hypot(one[0] - (vee[0] + vee[2]), (one[1] + one[3]) - (vee[1] + vee[3])),
                  "cap": max(one[3], five[3]), "digit": (five[0] + five[2] - one[0]) / 2},
        # A score line is fitted to the length of the rule under it.
        "ex": dict(placement(plates[0]["m"]), size=plates[0]["spans"][1]["size"], width=rule(items, 1)),
        "itg": dict(placement(plates[1]["m"]), size=plates[1]["spans"][1]["size"], width=rule(items, 2)),
        "rows": rows,
        "extra": dict(placement(extra["m"]), size=extra["spans"][0]["size"],
                      lineGap=extra["spans"][2]["y"] - extra["spans"][0]["y"]),
        "mods": dict(placement(texts["mods"][0]["m"]), size=texts["mods"][0]["spans"][0]["size"],
                     lineGap=texts["mods"][0]["spans"][1]["y"]),
        "title": dict(placement(texts["title"][0]["m"]), size=texts["title"][0]["spans"][0]["size"]),
    }
    lua_path = os.path.join(theme, "BGAnimations", "ScreenEvaluationStage overlay", "Wanted", "Art.lua")
    os.makedirs(os.path.dirname(lua_path), exist_ok=True)
    with open(lua_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/evaluation/build_eval_art.py from the owner's artwork.\n")
        f.write("-- Do not edit by hand.  Artboard pixels (1920x1080); angles in degrees.\n")
        f.write("return " + lua(art) + "\n")
    print("window %d points, %d triangles; backdrop.png, panel_head.png, panel_body.png, Art.lua written" % (len(window_pts), len(window_tris)))
    print(json.dumps({k: art[k] for k in ("song", "name", "grade", "level", "ex", "title")}, indent=1))


if __name__ == "__main__":
    main()
