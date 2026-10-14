"""Builds the end-of-session screens' pictures from the owner's mockup.

Input: the "gameover" artboard of tools/notes-radar/art/radar.svg (open in
Illustrator), exported piece by piece by
  export_gameover_art.jsx  -> art/item_NN.png, art/items.json (the artboard)
  export_gameover_card.jsx -> art/card/item_NN.png, art/card/items.json
                              (the leaves of player 1's score card)
Output: Graphics/VOLT26/GameOver/*.png and GameOverArt.lua (positions, in
artboard pixels, of player 1's card; player 2's is the same card mirrored,
see BGAnimations/_volt26 gameover kit.lua).

    python tools/gameover/build_gameover_art.py

The artboard (art/items.json, back to front):
  00 the navy ground          01 the faded next card (the carousel's step)
  02 03 the two halves' art   04 the dark band between the halves
  05 player 1's card          06 player 2's card (mirrored for the mockup)
Player 1's card (art/card/items.json):
  00 score plate   01 jacket frame   03 white band   04 black band
  05-08 RANK       11 the meter (placeholder picture)
  17 EX underline  22 ITG underline  23 the grade (placeholder picture)
"""
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ART = HERE / "art"
OUT = ROOT / "Graphics" / "VOLT26" / "GameOver"


def item(folder, n):
    return Image.open(folder / f"item_{n:02d}.png").convert("RGBA")


def stack(folder, numbers):
    im = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
    for n in numbers:
        im.alpha_composite(item(folder, n))
    return im


def save_piece(name, im):
    box = im.getbbox()
    im.crop(box).save(OUT / f"{name}.png", optimize=True)
    x0, y0, x1, y1 = box
    return {"X": (x0 + x1) / 2, "Y": (y0 + y1) / 2, "W": x1 - x0, "H": y1 - y0}


def corners(im):
    """The four corners of a slanted quad: top-left, top-right,
    bottom-right, bottom-left (artboard pixels)."""
    a = im.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    px = a.load()
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if px[x, y]]
    tl = min(pts, key=lambda p: p[0] + p[1])
    tr = max(pts, key=lambda p: p[0] - p[1])
    br = max(pts, key=lambda p: p[0] + p[1])
    bl = min(pts, key=lambda p: p[0] - p[1])
    return [tl, tr, br, bl]


def lua(value, indent=0):
    pad = "\t" * indent
    if isinstance(value, dict):
        inner = ",\n".join(f"{pad}\t{k} = {lua(v, indent + 1)}" for k, v in value.items())
        return "{\n" + inner + "\n" + pad + "}"
    if isinstance(value, (list, tuple)):
        return "{ " + ", ".join(lua(v, indent) for v in value) + " }"
    if isinstance(value, float):
        return f"{value:.2f}".rstrip("0").rstrip(".")
    return str(value)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    board = json.loads((ART / "items.json").read_text(encoding="utf-8"))
    card = ART / "card"

    # The ground in layers, so the screens can slip things between them (the
    # summary's faded cards go under the halves' art, as in the mockup): the
    # navy (a flat colour, drawn as a quad), each half's art (64% opaque in
    # the artboard, kept in the pictures' alpha) and the band.
    navy = item(ART, 0).getpixel((960, 540))
    (OUT / "background.png").unlink(missing_ok=True)
    pieces = {
        "TwinsTop": save_piece("twins_top", item(ART, 2)),
        "TwinsBottom": save_piece("twins_bottom", item(ART, 3)),
        "BandArt": save_piece("band", item(ART, 4)),
        "Bands": save_piece("bands", stack(card, [4, 3])),
        "Rank": save_piece("rank", stack(card, [5, 6, 7, 8])),
        "JacketFrame": save_piece("jacket_frame", item(card, 1)),
        "ScorePlate": save_piece("score_plate", item(card, 0)),
        "ItgLine": save_piece("underline_itg", item(card, 22)),
        "ExLine": save_piece("underline_ex", item(card, 17)),
    }

    def bbox(folder, n):
        x0, y0, x1, y1 = item(folder, n).getbbox()
        return {"X": (x0 + x1) / 2, "Y": (y0 + y1) / 2, "W": x1 - x0, "H": y1 - y0}

    p1 = bbox(ART, 5)
    p2 = bbox(ART, 6)
    step = board[1]["bounds"][0] - board[5]["bounds"][0]
    band = bbox(ART, 4)
    art = {
        "Ground": [round(c / 255, 4) for c in navy[:3]],
        "Card": {"P1": {"X": p1["X"], "Y": p1["Y"]}, "P2": {"X": p2["X"], "Y": p2["Y"]},
                 "Step": step, "NeighbourAlpha": board[1]["opacity"] / 100},
        "Band": band,
        "Pieces": pieces,
        "Jacket": {"Corners": corners(item(card, 1))},
        "Badge": bbox(card, 11),
        "Grade": bbox(card, 23),
        # Text boxes: the mockup's text frames (left, top, right, bottom).
        "Name": {"Box": [136.27, 98.06, 470, 152.28]},
        "Title": {"Box": [130.39, 142.28, 590, 209.53]},
        # Score lines, measured on the drawn digits: where the value's
        # baseline starts, its cap height, the tag's and the tail's, and the
        # line's slope (degrees).
        "Itg": {"X": 177, "Y": 449, "Cap": 21, "TagCap": 8, "TailCap": 13, "Rot": -5},
        "Ex": {"X": 323, "Y": 417, "Cap": 21, "TagCap": 8, "TailCap": 13, "Rot": -3.5},
    }
    text = ("-- Generated by tools/gameover/build_gameover_art.py from the \"gameover\"\n"
            "-- artboard of radar.svg.  Artboard pixels (1920x1080), player 1's card.\n"
            "return " + lua(art) + "\n")
    (ROOT / "BGAnimations" / "_volt26 gameover art.lua").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
