"""Offline harness for the WANTED evaluation page.

Runs the real screen Lua (background.lua, overlay/default.lua and what they
load) under lupa with mocked engine APIs, then renders the resulting actor
tree with PIL/numpy.  Not the engine: checks layout, data flow and Lua errors.

usage: python tools/evaluation/preview/preview.py . OUT.png [--players 1|2] [--fail] [--page N] [--title T] [--w 1920 --h 1080]
"""
import argparse, math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw
from lupa import lua51

ap = argparse.ArgumentParser()
ap.add_argument("theme"); ap.add_argument("out")
ap.add_argument("--players", type=int, default=1)
ap.add_argument("--fail", action="store_true")
ap.add_argument("--page", type=int, default=0)
ap.add_argument("--title", default="Titolo Canzone")
ap.add_argument("--bg", default="")
ap.add_argument("--w", type=int, default=1920); ap.add_argument("--h", type=int, default=1080)
ap.add_argument("--extra", default="")  # extra theme dirs for fallback lookups
args = ap.parse_args()
THEME = os.path.abspath(args.theme)
EXTRA = [os.path.abspath(p) for p in args.extra.split(":") if p]

def find(rel):
    for root in [THEME] + EXTRA:
        p = os.path.join(root, rel)
        if os.path.exists(p): return p
    return os.path.join(THEME, rel)

# ---------------------------------------------------------------- fonts
FONTS = {}
def load_font(name):
    if name in FONTS: return FONTS[name]
    redir = find("Fonts/%s.redir" % name)
    if not os.path.exists(redir):
        FONTS[name] = None; return None
    target = open(redir).read().strip()
    folder, stem = os.path.split(target)
    d = os.path.dirname(find("Fonts/" + target + ".ini"))
    ini = open(os.path.join(d, stem + ".ini"), encoding="utf-8").read().splitlines()
    common, lines, widths = {}, {}, {}
    for l in ini:
        m = re.match(r"Line (\d+)=(.*)$", l)
        if m: lines[int(m.group(1))] = m.group(2); continue
        m = re.match(r"(\d+)=(\d+)$", l)
        if m: widths[int(m.group(1))] = int(m.group(2)); continue
        m = re.match(r"(\w+)=(-?\d+)$", l)
        if m: common[m.group(1)] = int(m.group(2))
    png = [f for f in os.listdir(d) if f.startswith(stem + " [main]")][0]
    cols, rows = map(int, re.search(r"(\d+)x(\d+)\.png", png).groups())
    page = Image.open(os.path.join(d, png)).convert("RGBA")
    cw, ch = page.width // cols, page.height // rows
    glyphs = {}
    i = 0
    for r in range(rows):
        for c, chh in enumerate(lines.get(r, "")):
            glyphs.setdefault(chh, (r, c, widths.get(i, cw)))
            i += 1
    f = dict(page=page, cw=cw, ch=ch, glyphs=glyphs, base=common["Baseline"], top=common["Top"],
             spacing=common.get("LineSpacing", ch))
    FONTS[name] = f
    return f

def text_width(name, text):
    f = load_font(name)
    if not f: return len(text) * 10.0
    return float(sum(f["glyphs"].get(c, (0, 0, f["cw"] // 2))[2] for c in text))

def font_height(name):
    f = load_font(name)
    return float(f["base"] - f["top"]) if f else 20.0

def font_spacing(name):
    f = load_font(name)
    return float(f["spacing"]) if f else 24.0

def img_size(path):
    try:
        im = Image.open(path); return im.width, im.height
    except Exception:
        return 64, 64

L = lua51.LuaRuntime(unpack_returned_tuples=True)
g = L.globals()
g.py_text_width = text_width
g.py_font_height = font_height
g.py_font_spacing = font_spacing
g.py_img_size = lambda p: L.table(*img_size(p))
g.py_exists = lambda p: os.path.exists(p)
g.py_find = find
g.SCREEN_WIDTH = args.w; g.SCREEN_HEIGHT = args.h
g.HARNESS_PLAYERS = args.players; g.HARNESS_FAIL = args.fail
g.HARNESS_TITLE = args.title; g.HARNESS_BG = args.bg; g.THEME_DIR = THEME

L.execute(open(os.path.join(os.path.dirname(__file__), "mock.lua"), encoding="utf-8").read())

# ---------------------------------------------------------------- run
for script in ("Scripts/VOLT26_EvaluationPage.lua",):
    L.eval("function(p) return RunScript(p) end")(find(script))
bg = L.eval("function(p) return BuildScreenLayer(p) end")(find("BGAnimations/ScreenEvaluationStage background.lua"))
ov = L.eval("function(p) return BuildScreenLayer(p) end")(find("BGAnimations/ScreenEvaluationStage overlay/default.lua"))
L.eval("function(p) Broadcast('VOLT26EvaluationPage', {Side=PLAYER_1, Page=p}); Broadcast('VOLT26EvaluationPage', {Side=PLAYER_2, Page=p}) end")(args.page)
print("broadcasts:", list(L.eval("BroadcastLog").values()))

# ---------------------------------------------------------------- render
W, H = args.w, args.h
canvas = np.zeros((H, W, 3), dtype=np.float32)

def mat(a):
    x, y, r, zx, zy = a.px, a.py, math.radians(a.prot), a.zx, a.zy
    c, s = math.cos(r), math.sin(r)
    return np.array([[c * zx, -s * zy, x], [s * zx, c * zy, y], [0, 0, 1]], dtype=np.float64)

TEX = {}
def texture(path):
    if path not in TEX:
        try: TEX[path] = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255
        except Exception: TEX[path] = None
    return TEX[path]

def raster_tri(P, C, UV, tex, add):
    # P: 3x2 screen, C: 3x4 colours, UV: 3x2 or None
    x0, y0 = np.floor(P.min(0)).astype(int); x1, y1 = np.ceil(P.max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, W - 1), min(y1, H - 1)
    if x1 < x0 or y1 < y0: return
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = P
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9: return
    l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
    l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
    l3 = 1 - l1 - l2
    m = (l1 >= -1e-6) & (l2 >= -1e-6) & (l3 >= -1e-6)
    if not m.any(): return
    col = l1[..., None] * C[0] + l2[..., None] * C[1] + l3[..., None] * C[2]
    if tex is not None and UV is not None:
        u = l1 * UV[0, 0] + l2 * UV[1, 0] + l3 * UV[2, 0]
        v = l1 * UV[0, 1] + l2 * UV[1, 1] + l3 * UV[2, 1]
        th, tw = tex.shape[:2]
        # uv are in texture-size units (image padded to powers of two)
        tx = np.clip((u * pot(tw)).astype(int), 0, tw - 1); ty = np.clip((v * pot(th)).astype(int), 0, th - 1)
        col = col * tex[ty, tx]
    region = canvas[y0:y1 + 1, x0:x1 + 1]
    a = col[..., 3:4] * m[..., None]
    if add: region += col[..., :3] * a
    else: region[:] = region * (1 - a) + col[..., :3] * a
    np.clip(region, 0, 1, out=region)

def pot(n):
    p = 1
    while p < n: p *= 2
    return p

def blit(img, M, tint=(1, 1, 1, 1), add=False):
    """img RGBA float array; M maps image pixel coords to screen."""
    h, w = img.shape[:2]
    corners = np.array([[0, 0, 1], [w, 0, 1], [w, h, 1], [0, h, 1]], dtype=np.float64) @ M.T
    x0, y0 = np.floor(corners[:, :2].min(0)).astype(int); x1, y1 = np.ceil(corners[:, :2].max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, W - 1), min(y1, H - 1)
    if x1 < x0 or y1 < y0: return
    Minv = np.linalg.inv(M)
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    sx = Minv[0, 0] * xs + Minv[0, 1] * ys + Minv[0, 2]
    sy = Minv[1, 0] * xs + Minv[1, 1] * ys + Minv[1, 2]
    m = (sx >= 0) & (sy >= 0) & (sx < w) & (sy < h)
    if not m.any(): return
    # bilinear-ish: nearest is fine for a preview
    ix = np.clip(sx.astype(int), 0, w - 1); iy = np.clip(sy.astype(int), 0, h - 1)
    col = img[iy, ix] * np.array(tint, dtype=np.float32)
    a = col[..., 3:4] * m[..., None]
    region = canvas[y0:y1 + 1, x0:x1 + 1]
    if add: region += col[..., :3] * a
    else: region[:] = region * (1 - a) + col[..., :3] * a
    np.clip(region, 0, 1, out=region)

def color_of(t):
    return np.array([t[1], t[2], t[3], t[4] if t[4] is not None else 1], dtype=np.float32)

def draw_text(a, M):
    f = load_font(a.font)
    text = a.txt or ""
    if not f or not text: return
    tint = color_of(a.col)
    attrs = [(int(at[1]), int(at[2]), color_of(at[3])) for at in (a.attrs.values() if a.attrs else [])]
    lines = list(L.eval("function(a) return WrappedLines(a) end")(a).values())
    hgt = font_height(a.font); sp = font_spacing(a.font)
    total_h = hgt + (len(lines) - 1) * sp
    widths = [text_width(a.font, ln) for ln in lines]
    wmax = max(widths) if widths else 0
    idx = 0
    for li, ln in enumerate(lines):
        pen = -wmax * a.ha + (wmax - widths[li]) * a.ha
        base_y = -total_h * a.va + hgt + li * sp
        for chh in ln:
            gl = f["glyphs"].get(chh)
            c = tint
            for start, length, col in attrs:
                if start <= idx < start + length: c = col
            idx += 1
            if not gl:
                pen += f["cw"] / 2; continue
            r, cidx, adv = gl
            cell = f["page"].crop((cidx * f["cw"], r * f["ch"], (cidx + 1) * f["cw"], (r + 1) * f["ch"]))
            arr = np.asarray(cell, dtype=np.float32) / 255
            left = pen - (f["cw"] - adv) / 2
            top = base_y - f["base"]
            T = np.array([[1, 0, left], [0, 1, top], [0, 0, 1]])
            blit(arr, M @ T, c)
            pen += adv
        idx += 1  # newline

def draw(a, Mp):
    if not a.shown: return
    M = Mp @ mat(a)
    cls = a.cls
    if cls == "Sprite" and a.texture:
        tex = texture(a.texture)
        if tex is not None:
            w, h = tex.shape[1], tex.shape[0]
            sw, sh = (a.w or w), (a.h or h)
            S = np.array([[sw / w, 0, -sw * a.ha], [0, sh / h, -sh * a.va], [0, 0, 1]])
            blit(tex, M @ S, color_of(a.col), a.blendmode == "add")
    elif cls == "Quad":
        w, h = a.w or 1, a.h or 1
        pts = np.array([[-w * a.ha, -h * a.va, 1], [w * (1 - a.ha), -h * a.va, 1], [w * (1 - a.ha), h * (1 - a.va), 1], [-w * a.ha, h * (1 - a.va), 1]]) @ M.T
        C = np.array([color_of(a.col)] * 3)
        raster_tri(pts[[0, 1, 2], :2], C, None, None, False); raster_tri(pts[[0, 2, 3], :2], C, None, None, False)
    elif cls == "ActorMultiVertex" and a.verts:
        verts = list(a.verts.values())
        P = np.array([[v[1][1], v[1][2], 1] for v in verts], dtype=np.float64) @ M.T
        C = np.array([color_of(v[2]) for v in verts])
        UV = np.array([[v[3][1], v[3][2]] if v[3] is not None else [0, 0] for v in verts])
        tex = texture(a.amvtexture) if a.amvtexture else None
        add = a.blendmode == "add"
        mode = a.mode or "DrawMode_Quads"
        tris = []
        n = len(verts)
        if mode == "DrawMode_Triangles": tris = [(i, i + 1, i + 2) for i in range(0, n - 2, 3)]
        elif mode == "DrawMode_Quads":
            for i in range(0, n - 3, 4): tris += [(i, i + 1, i + 2), (i, i + 2, i + 3)]
        elif mode == "DrawMode_QuadStrip":
            for i in range(0, n - 3, 2): tris += [(i, i + 1, i + 3), (i, i + 3, i + 2)]
        elif mode == "DrawMode_LineStrip":
            im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
            lw = max(1, int(round((a.lw or 1) * abs(np.linalg.det(M[:2, :2])) ** 0.5)))
            for i in range(n - 1):
                c = tuple(int(255 * x) for x in C[i])
                d.line([tuple(P[i, :2]), tuple(P[i + 1, :2])], fill=c, width=lw)
            arr = np.asarray(im, dtype=np.float32) / 255
            al = arr[..., 3:4]
            canvas[:] = canvas * (1 - al) + arr[..., :3] * al
        for t in tris:
            raster_tri(P[list(t), :2], C[list(t)], UV[list(t)], tex, add)
    elif cls == "BitmapText":
        draw_text(a, M)
    for c in (a.kids.values() if a.kids else []):
        draw(c, M)

I = np.eye(3)
draw(bg, I); draw(ov, I)
Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8)).save(args.out)
print("wrote", args.out)
