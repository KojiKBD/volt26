"""Rebuild the SortMenu dock icons from the owner's icons.ai.

usage: python tools/sort-menu/build_icons.py ICONS.ai [OUT_DIR]
       (OUT_DIR defaults to Graphics/VOLT26/SortMenu)

icons.ai holds twelve icons in two rows: plain on top, the hover twin
(outlined in black) below, in the dock's order -- profile, mods, trophy
(SCORES), search, favorite (ADD FAV), heart (FAVS), marathon, sorts, player,
advanced, styles, playlists.  The file's PDF preview only shows what is on its
artboards, so the artwork is read from Illustrator's own data inside the file
(the zstd-compressed AIPrivateData streams) and its paths are redrawn as SVG.
Each icon is written as <name>.png and <name>_hover.png, 192 px square, the
pair at one scale so the larger of the two fills 170 px.

Needs pikepdf, zstandard and cairosvg.
"""
import json, os, re, sys
import pikepdf, zstandard, cairosvg


def cmyk2rgb(c, m, y, k):
    return ((1 - c) * (1 - k), (1 - m) * (1 - k), (1 - y) * (1 - k))

def parse(path):
    lines = open(path, 'rb').read().decode('latin-1').split('\n')
    start = next(i for i, l in enumerate(lines) if l.startswith('%AI5_BeginLayer'))
    items = []          # {d, fill, stroke, width, rule, bbox}
    fill = (0, 0, 0); stroke = (0, 0, 0); width = 1; rule = 'nonzero'
    cur = []; sub = []; compound = None; pt = (0, 0)
    in_raster = False
    def bbox_of(segs):
        xs = [v for s in segs for v in s[1][0::2]]; ys = [v for s in segs for v in s[1][1::2]]
        return [min(xs), min(ys), max(xs), max(ys)]
    def emit(segs, f, s):
        if not segs: return
        d = []
        for op, a in segs:
            if op == 'M': d.append('M%.3f %.3f' % (a[0], -a[1]))
            elif op == 'L': d.append('L%.3f %.3f' % (a[0], -a[1]))
            elif op == 'C': d.append('C%.3f %.3f %.3f %.3f %.3f %.3f' % (a[0], -a[1], a[2], -a[3], a[4], -a[5]))
            elif op == 'Z': d.append('Z')
        items.append({'d': ' '.join(d), 'fill': fill if f else None, 'stroke': stroke if s else None,
                      'width': width, 'rule': rule,
                      'bbox': bbox_of([x for x in segs if x[0] != 'Z'])})
    for line in lines[start:]:
        if line.startswith('%AI5_BeginRaster'): in_raster = True; continue
        if line.startswith('%AI5_EndRaster'): in_raster = False; continue
        if in_raster or line.startswith('%'): continue
        t = line.split()
        if not t: continue
        op = t[-1]
        def nums(n):
            return [float(x) for x in t[-1 - n:-1]]
        try:
            if op == 'm': pt = tuple(nums(2)); cur.append(('M', list(pt)))
            elif op in ('l', 'L'): pt = tuple(nums(2)); cur.append(('L', list(pt)))
            elif op in ('c', 'C'): a = nums(6); cur.append(('C', a)); pt = (a[4], a[5])
            elif op in ('v', 'V'): a = nums(4); cur.append(('C', [pt[0], pt[1]] + a)); pt = (a[2], a[3])
            elif op in ('y', 'Y'): a = nums(4); cur.append(('C', a[:2] + a[2:] + [])); cur[-1] = ('C', [a[0], a[1], a[2], a[3], a[2], a[3]]); pt = (a[2], a[3])
            elif op in ('f', 'F', 's', 'S', 'b', 'B', 'n', 'N'):
                if op in 'fsbn': cur.append(('Z', []))
                f = op in 'fFbB'; s = op in 'sSbB'
                if compound is not None:
                    compound['segs'] += cur
                    compound['f'] = compound['f'] or f; compound['s'] = compound['s'] or s
                    compound['fill'], compound['stroke'] = fill, stroke
                else:
                    emit(cur, f, s)
                cur = []
            elif op == '*u': compound = {'segs': [], 'f': False, 's': False}
            elif op == '*U':
                if compound:
                    emit(compound['segs'], compound['f'], compound['s'])
                compound = None
            elif op == 'Xa': v = nums(7); fill = tuple(v[4:7])
            elif op == 'XA': v = nums(7); stroke = tuple(v[4:7])
            elif op == 'k' and len(t) == 5: fill = cmyk2rgb(*nums(4))
            elif op == 'K' and len(t) == 5: stroke = cmyk2rgb(*nums(4))
            elif op == 'g' and len(t) == 2: g = nums(1)[0]; fill = (g, g, g)
            elif op == 'G' and len(t) == 2: g = nums(1)[0]; stroke = (g, g, g)
            elif op == 'XR' and len(t) == 2: rule = 'evenodd' if nums(1)[0] == 1 else 'nonzero'
            elif op == 'w' and len(t) == 2: width = nums(1)[0]
            elif ' w ' in ' ' + line + ' ':
                m = re.search(r'(\S+) w', line)
                if m: width = float(m.group(1))
        except (ValueError, StopIteration):
            pass
    return items

def svg(items, box, scale=1.0):
    x0, y0, x1, y1 = box
    w, h = (x1 - x0) * scale, (y1 - y0) * scale
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%f %f %f %f">' %
           (round(w), round(h), x0, -y1, x1 - x0, y1 - y0)]
    def col(c): return 'rgb(%d,%d,%d)' % tuple(round(max(0, min(1, v)) * 255) for v in c)
    for it in items:
        attrs = 'fill="%s" fill-rule="%s"' % (col(it['fill']) if it['fill'] else 'none', it['rule'])
        if it['stroke']: attrs += ' stroke="%s" stroke-width="%f"' % (col(it['stroke']), it['width'])
        out.append('<path d="%s" %s/>' % (it['d'], attrs))
    out.append('</svg>')
    return '\n'.join(out)


# Each icon's column, by the x of its centre in the artwork (points).
COLUMNS = [('profile', -70, -25), ('mods', -20, 40), ('trophy', 50, 122), ('search', 128, 200),
           ('favorite', 205, 272), ('heart', 276, 340), ('marathon', 345, 395), ('sorts', 400, 455),
           ('player', 456, 500), ('advanced', 505, 580), ('styles', 600, 642), ('playlists', 644, 700)]
ROW_SPLIT = -50     # centres above this y are the plain row
SIZE, FILL = 192, 170

def native_text(ai_path, out_path):
    pdf = pikepdf.open(ai_path)
    private = pdf.pages[0].obj['/PieceInfo']['/Illustrator']['/Private']
    keys = sorted((k for k in private.keys() if k.startswith('/AIPrivateData')), key=lambda k: int(k[14:]))
    data = b''.join(private[k].read_bytes() for k in keys)
    marker = b'%AI24_ZStandard_Data'
    start = data.find(marker)
    if start < 0:
        raise SystemExit('no AI24 ZStandard data in ' + ai_path)
    text = zstandard.ZstdDecompressor().decompressobj().decompress(data[start + len(marker):])
    open(out_path, 'wb').write(text)

def main():
    ai_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else 'Graphics/VOLT26/SortMenu'
    native = os.path.join(out_dir, '.icons_native.tmp')
    native_text(ai_path, native)
    items = parse(native)
    os.remove(native)
    groups = {}
    for it in items:
        b = it['bbox']
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        column = [c for c in COLUMNS if c[1] <= cx <= c[2]]
        if len(column) != 1:
            raise SystemExit('a shape at x=%.1f is in no icon column; update COLUMNS' % cx)
        groups.setdefault((column[0][0], 'plain' if cy > ROW_SPLIT else 'hover'), []).append(it)
    def bbox(its):
        return [min(i['bbox'][0] for i in its), min(i['bbox'][1] for i in its),
                max(i['bbox'][2] for i in its), max(i['bbox'][3] for i in its)]
    for name, _, _ in COLUMNS:
        pair = [bbox(groups[(name, 'plain')]), bbox(groups[(name, 'hover')])]
        scale = FILL / max(max(b[2] - b[0], b[3] - b[1]) for b in pair)
        for row, suffix in (('plain', ''), ('hover', '_hover')):
            b = bbox(groups[(name, row)])
            cx, cy, half = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2, SIZE / scale / 2
            doc = svg(groups[(name, row)], [cx - half, cy - half, cx + half, cy + half], scale)
            cairosvg.svg2png(bytestring=doc.encode(), write_to=os.path.join(out_dir, name + suffix + '.png'),
                             output_width=SIZE, output_height=SIZE)
        print(name)

if __name__ == '__main__':
    main()
