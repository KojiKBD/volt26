"""Encode the title's JPG sequences using the same movie format as Play."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--ffmpeg", default="ffmpeg")
parser.add_argument("--include-play", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1] / "Graphics/VOLT26"
sequences = [("edit", "edit", "edit"), ("opt", "opt", "options"),
             ("exit", "exit", "exit")]
if args.include_play:
    sequences.insert(0, ("gameplay", "gmban", "play"))
for folder, prefix, name in sequences:
    source = root / "City_bg" / folder
    expected = {f"{prefix}_{i:05d}.jpg" for i in range(90)}
    if {p.name for p in source.glob("*.jpg")} != expected:
        raise ValueError(f"Expected exactly 90 consecutive frames in {source}")
    subprocess.run([
        args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-framerate", "30", "-start_number", "0",
        "-i", str(source / f"{prefix}_%05d.jpg"),
        "-frames:v", "90", "-an", "-c:v", "mpeg4", "-vtag", "DX50",
        "-q:v", "2", "-pix_fmt", "yuv420p",
        str(root / "TitleTravelCity" / f"banner_{name}.avi"),
    ], check=True)
    print(f"Encoded {name}: 90 frames at 30 fps")
