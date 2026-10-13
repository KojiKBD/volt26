#!/usr/bin/env python3
"""Build the song select's player cards from the owner's Illustrator SVG.

The cards are the two player cards on the right of the song select artboard
(the artboard whose top-left corner is at ARTBOARD): a white plate with the
player's name and "STEPS BY", "LV" and the meter, a black frame, the EX and
ITG bests, a box of chart counts, and a slanted density graph with the stream
breakdown.  Card 1 is drawn by Layer_1's top-level items CARD1, card 2 by the
children of the group CARD2, in the same order (ROLES).

Outputs (paths relative to the theme root):

  Graphics/VOLT26/SongSelect/card1.png, card2.png   each card without its
      text, name, level, or graph contents, cropped to the card.
  BGAnimations/ScreenSelectMusic overlay/SongWheel/CardsArt.lua   generated:
      each picture's place and every anchor (artboard pixels, 1920x1080).

Usage (from the theme root):
    python tools/song-select/build_cards_art.py [--svg tools/notes-radar/art/radar.svg]

Requires Playwright with Chromium.  If the artwork's structure changes,
update ARTBOARD, CARD1 and CARD2.
"""
import argparse
import math
import os
import re

import numpy as np
from PIL import Image
from playwright.sync_api import sync_playwright

ARTBOARD = (-35.18, 2425.94)
W, H = 1920, 1080

# The parts of a card, in document order.
ROLES = ["plate", "name", "level", "frame", "ex", "itg", "steps", "box", "stats", "graph", "breakdown"]
CARD1 = [[i] for i in range(402, 413)]
CARD2 = [[413, k] for k in range(11)]

# The player's name is centred on the upper white plate: the white of the
# card picture above the "STEPS BY" line (the SVG's placeholder picture has
# its lettering off-centre).  NAME_TURN is the lettering's turn.
NAME_TURN = -2


def plate_centre(img, x0, y0, below):
    """Centre of the white of a card picture (placed at x0, y0) above `below`."""
    a = np.asarray(img).astype(int)
    white = (a[..., 0] > 240) & (a[..., 1] > 240) & (a[..., 2] > 240) & (a[..., 3] > 240)
    ys, xs = np.nonzero(white)
    keep = ys + y0 < below
    return float(xs[keep].mean() + x0), float(ys[keep].mean() + y0)


# What the card pictures keep, and what they hide inside what they keep.
KEEP = ["plate", "frame", "ex", "itg", "box", "graph"]
HIDE = [("ex", [0]), ("itg", [0]), ("graph", [1, 1]), ("graph", [1, 2])]

SHOW_JS = """([keep, hide]) => {
  const L = document.getElementById('Layer_1');
  const node = p => { let e = L; for (const k of p) e = e.children[k]; return e; };
  const key = p => p.join('/');
  const kept = new Set(keep.map(key));
  const above = new Set();
  for (const p of keep) for (let n = 1; n < p.length; n++) above.add(key(p.slice(0, n)));
  const walk = (e, p) => {
    [...e.children].forEach((c, i) => {
      const q = p.concat([i]), k = key(q);
      if (kept.has(k)) { c.style.display = ''; }
      else if (above.has(k)) { c.style.display = ''; walk(c, q); }
      else { c.style.display = 'none'; }
    });
  };
  walk(L, []);
  for (const p of hide) node(p).style.display = 'none';
}"""

MEASURE_JS = """(parts) => {
  const L = document.getElementById('Layer_1'), root = document.documentElement;
  const node = p => { let e = L; for (const k of p) e = e.children[k]; return e; };
  const inv = root.getCTM().inverse();
  const ctm = e => inv.multiply(e.getCTM());
  const out = {};
  const textOf = e => {
    const t = e.tagName === 'text' ? e : e.querySelector('text');
    const m = ctm(t);
    const leaves = [...t.querySelectorAll('tspan')].filter(x => !x.querySelector('tspan'));
    return { m: [m.a, m.b, m.c, m.d, m.e, m.f], width: t.getBBox().width,
      spans: (leaves.length ? leaves : [t]).map(s => ({ text: s.textContent,
        x: +(s.getAttribute('x') || 0), y: +(s.getAttribute('y') || 0),
        size: parseFloat(getComputedStyle(s).fontSize) })) };
  };
  // A placed picture: centre, size and turn.
  const picture = e => {
    const b = e.getBBox(), m = ctm(e);
    const pt = (x, y) => [m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f];
    return { centre: pt(b.x + b.width / 2, b.y + b.height / 2),
      w: b.width * Math.hypot(m.a, m.b), h: b.height * Math.hypot(m.c, m.d),
      rot: Math.atan2(m.b, m.a) * 180 / Math.PI };
  };
  // Corners of a polygon, in document coordinates.
  const corners = e => { const m = ctm(e);
    return [...e.points].map(p => [m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f]); };
  // A rule (line) under a score.
  const rule = e => { const m = ctm(e), a = [+e.getAttribute('x1'), +e.getAttribute('y1')],
      b = [+e.getAttribute('x2'), +e.getAttribute('y2')];
    const P = q => [m.a * q[0] + m.c * q[1] + m.e, m.b * q[0] + m.d * q[1] + m.f];
    const A = P(a), B = P(b); return Math.hypot(B[0] - A[0], B[1] - A[1]); };
  out.name = picture(node(parts.name));
  out.level = [...node(parts.level).children].map(c => { const r = c.getBoundingClientRect();
    return [r.x, r.y, r.width, r.height]; });
  out.ex = textOf(node(parts.ex)); out.exRule = rule(node(parts.ex).children[1]);
  out.itg = textOf(node(parts.itg)); out.itgRule = rule(node(parts.itg).children[1]);
  out.steps = textOf(node(parts.steps));
  out.stats = textOf(node(parts.stats));
  out.breakdown = textOf(node(parts.breakdown));
  out.graph = corners(node(parts.graph).children[1].children[0]);
  return out;
}"""


def placement(m):
    a, b, c, d, e, f = m
    sx = math.hypot(a, b)
    return {"x": e - ARTBOARD[0], "y": f - ARTBOARD[1], "rot": math.degrees(math.atan2(b, a)),
            "sx": sx, "sy": (a * d - b * c) / sx}


def lua(value, indent=0):
    pad = "\t" * indent
    if isinstance(value, dict):
        return "{\n" + "\n".join("%s\t%s = %s," % (pad, k, lua(v, indent + 1)) for k, v in value.items()) + "\n" + pad + "}"
    if isinstance(value, (list, tuple)):
        if all(isinstance(v, (int, float)) for v in value):
            return "{" + ", ".join(lua(v) for v in value) + "}"
        return "{\n" + "\n".join("%s\t%s," % (pad, lua(v, indent + 1)) for v in value) + "\n" + pad + "}"
    if isinstance(value, float):
        return ("%.2f" % value).rstrip("0").rstrip(".")
    if isinstance(value, str):
        return '"' + value + '"'
    return str(value)


def quad(points):
    """A four-cornered graph frame: topLeft, topRight, bottomRight, bottomLeft."""
    pts = [(x - ARTBOARD[0], y - ARTBOARD[1]) for x, y in points]
    cx = sum(p[0] for p in pts) / len(pts)
    left = sorted([p for p in pts if p[0] < cx], key=lambda p: p[1])
    right = sorted([p for p in pts if p[0] >= cx], key=lambda p: p[1])
    return {"topLeft": list(left[0]), "bottomLeft": list(left[-1]),
            "topRight": list(right[0]), "bottomRight": list(right[-1])}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--svg", default="tools/notes-radar/art/radar.svg")
    ap.add_argument("--theme", default=os.path.join(os.path.dirname(__file__), "..", ".."))
    args = ap.parse_args()
    theme = os.path.abspath(args.theme)
    svg_path = os.path.abspath(args.svg)
    out_dir = os.path.join(theme, "Graphics", "VOLT26", "SongSelect")
    os.makedirs(out_dir, exist_ok=True)

    source = open(svg_path, encoding="utf-8").read()
    work = os.path.join(os.path.dirname(svg_path), "_cards_render.svg")
    vb = 'viewBox="%g %g %d %d" width="%d" height="%d"' % (ARTBOARD[0], ARTBOARD[1], W, H, W, H)
    open(work, "w", encoding="utf-8").write(re.sub(r'viewBox="[^"]*"', vb, source, count=1))
    cards = []
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(args=["--allow-file-access-from-files"])
            page = browser.new_page(viewport={"width": W, "height": H})
            page.goto("file://" + work)
            page.wait_for_timeout(500)
            for number, parts in ((1, CARD1), (2, CARD2)):
                named = dict(zip(ROLES, parts))
                # Measure with everything shown (hidden parts have no geometry).
                page.reload()
                page.wait_for_timeout(400)
                m = page.evaluate(MEASURE_JS, named)
                keep = [named[r] for r in KEEP]
                hide = [named[r] + sub for r, sub in HIDE]
                page.evaluate(SHOW_JS, [keep, hide])
                page.wait_for_timeout(100)
                shot = os.path.join(out_dir, "_card.png")
                page.screenshot(path=shot, omit_background=True)
                img = Image.open(shot).convert("RGBA")
                os.remove(shot)
                x0, y0, x1, y1 = img.getbbox()
                x0, y0, x1, y1 = max(0, x0 - 2), max(0, y0 - 2), min(W, x1 + 2), min(H, y1 + 2)
                img.crop((x0, y0, x1, y1)).save(os.path.join(out_dir, "card%d.png" % number), optimize=True)

                ell, vee, one, five = m["level"]
                level_rot = math.degrees(math.atan2((five[1] + five[3]) - (one[1] + one[3]), five[0] - one[0]))
                stats = m["stats"]
                spans = stats["spans"]
                breakdown = m["breakdown"]
                bp = placement(breakdown["m"])
                r = math.radians(bp["rot"])
                half = breakdown["width"] * bp["sx"] / 2
                card = {
                    "picture": "card%d" % number,
                    "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0,
                    "name": dict(zip(("cx", "cy"), plate_centre(img.crop((x0, y0, x1, y1)), x0, y0,
                                                               placement(m["steps"]["m"])["y"] - 28)), rot=NAME_TURN),
                    "level": {"x": ell[0], "y": ell[1] + ell[3], "rot": level_rot,
                              "lvCap": ell[3], "lvWidth": vee[0] + vee[2] - ell[0],
                              "gap": math.hypot(one[0] - (vee[0] + vee[2]), (one[1] + one[3]) - (vee[1] + vee[3])),
                              "cap": max(one[3], five[3]), "digit": (five[0] + five[2] - one[0]) / 2},
                    "ex": dict(placement(m["ex"]["m"]), size=m["ex"]["spans"][1]["size"],
                               small=m["ex"]["spans"][0]["size"], tail=m["ex"]["spans"][-1]["size"], width=m["exRule"]),
                    "itg": dict(placement(m["itg"]["m"]), size=m["itg"]["spans"][1]["size"],
                                small=m["itg"]["spans"][0]["size"], tail=m["itg"]["spans"][-1]["size"], width=m["itgRule"]),
                    "steps": dict(placement(m["steps"]["m"]), size=m["steps"]["spans"][0]["size"]),
                    "stats": dict(placement(stats["m"]), size=spans[0]["size"],
                                  lineGap=spans[2]["y"] - spans[0]["y"]),
                    # Centred where the artwork centres its breakdown.
                    "breakdown": {"x": bp["x"] + half * math.cos(r), "y": bp["y"] + half * math.sin(r),
                                  "rot": bp["rot"], "sx": bp["sx"], "size": breakdown["spans"][0]["size"]},
                    "graph": quad(m["graph"]),
                }
                cards.append(card)
            browser.close()
    finally:
        os.remove(work)

    lua_path = os.path.join(theme, "BGAnimations", "ScreenSelectMusic overlay", "SongWheel", "CardsArt.lua")
    os.makedirs(os.path.dirname(lua_path), exist_ok=True)
    with open(lua_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/song-select/build_cards_art.py from the owner's artwork.\n")
        f.write("-- Do not edit by hand.  Artboard pixels (1920x1080); angles in degrees.\n")
        f.write("return " + lua({"cards": cards}) + "\n")
    print("card1.png, card2.png, CardsArt.lua written")


if __name__ == "__main__":
    main()
