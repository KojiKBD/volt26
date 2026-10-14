"""Builds the menu transition's frames (Graphics/VOLT26/TransMenu, TransMenu2)
at 960x540 from the 1920x1080 sources kept in
tools/title-menu/transition-frames-1080p/.

Each frame used to be decoded from a 1920x1080 PNG and uploaded as a
2048x2048 texture (16 MB) while the transition played, one every 1/30 s,
which the cabinet could not keep up with.  At 960x540 a frame is a 1024x1024
texture (4 MB), small enough for the transition to load the whole sequence
with its screen ("_volt26 menu transition.lua").  The frames are flat shapes,
shown full screen for 1/30 s each, so the halved resolution does not show in
motion.

    python tools/title-menu/shrink_transition_frames.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools" / "title-menu" / "transition-frames-1080p"
TARGET = ROOT / "Graphics" / "VOLT26"
SIZE = (960, 540)

for folder in ("TransMenu", "TransMenu2"):
    for src in sorted((SOURCE / folder).glob("*.png")):
        im = Image.open(src).convert("RGBA").resize(SIZE, Image.LANCZOS)
        if im.getextrema()[3] == (255, 255):
            im = im.convert("RGB")
        dst = TARGET / folder / src.name
        im.save(dst, optimize=True)
        print(dst.relative_to(ROOT), dst.stat().st_size)
