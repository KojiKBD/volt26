#!/usr/bin/env python3
"""Bake the hidden song's blood texture (ScreenGameplay underlay/Secret.lua):
a seamless 512 px tile of thick, dirty blood -- mottled body, dark clots and
clumps, fine grain and a few lighter glints -- in greys, which the theme
tints red through the vertex colours of the rising liquid.

Usage: python tools/secret/build_blood_texture.py [--theme <theme root>]
Writes Graphics/VOLT26/Secret/blood.png.
"""
import argparse, os
import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(26)


def band(size, width=0.6):
    """Seamless noise with features about `size` pixels across."""
    fx = np.fft.fftfreq(N)[:, None]
    fy = np.fft.fftfreq(N)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f0 = 1.0 / size
    amp = np.exp(-((np.log(np.maximum(f, 1e-6)) - np.log(f0)) ** 2) / (2 * width ** 2))
    amp[0, 0] = 0
    spec = amp * (rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N)))
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--theme", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    a = ap.parse_args()

    body = band(160, 0.8)                     # broad mottling
    mid = band(60, 0.5)                       # uneven thickness, swirls
    cluster = band(120, 0.6)                  # where clots gather
    clotsA = band(38, 0.45)                   # clumps
    clotsB = band(15, 0.4)                    # small clots
    grain = rng.random((N, N))                # fine dirt

    v = 0.80 + 0.18 * (body - 0.5) * 2 + 0.14 * (mid - 0.5) * 2
    # Clots: the darkest parts of two sizes of clump noise, soft-edged, more
    # of them where the cluster noise is high (blood clots in clumps).
    gather = np.clip((cluster - 0.35) / 0.3, 0, 1)
    ca = np.clip((0.30 + 0.12 * gather - clotsA) / 0.10, 0, 1) ** 1.2
    cb = np.clip((0.22 + 0.14 * gather - clotsB) / 0.07, 0, 1) ** 1.2
    v = v * (1 - 0.6 * ca) * (1 - 0.5 * cb)
    # Wet rims round the bigger clots.
    v = v + np.clip(1 - np.abs(clotsA - (0.32 + 0.12 * gather)) / 0.018, 0, 1) * 0.08
    # Dirt: grain, dark crumbs, a few glints.
    v = v * (0.84 + 0.16 * grain)
    crumbs = rng.random((N, N)) < 0.004
    glints = rng.random((N, N)) < 0.001
    v[crumbs] *= 0.45
    v[glints] = np.minimum(1, v[glints] + 0.3)
    v = np.clip(v, 0, 1)

    img = (v * 255).astype(np.uint8)
    out = os.path.join(os.path.abspath(a.theme), "Graphics", "VOLT26", "Secret")
    os.makedirs(out, exist_ok=True)
    Image.fromarray(img, "L").convert("RGB").save(os.path.join(out, "blood.png"), optimize=True)
    print("written", os.path.join(out, "blood.png"))


if __name__ == "__main__":
    main()
