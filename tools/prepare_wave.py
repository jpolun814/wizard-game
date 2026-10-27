"""Cuts the wave animation for Tide Surf from "Tsunami animation" by mkwong98 (CC0, opengameart.org/content/tsunami-animation).

    python tools/prepare_wave.py <wave_2.gif> <out dir>

The gif has 13 frames of 48x32: four of a wave rising and curling over, then nine of a rolling swell. They are recoloured from
saturated blue to a dark, cold green-grey (a ramp by brightness) so the water sits with the rest of the game, and written as two
strips: surf_crest.png (the four curling frames) and surf_body.png (the nine swell frames).
"""

import os
import sys

from PIL import Image

RAMP = [(0.0, (8, 28, 38)), (0.45, (24, 78, 92)), (0.75, (96, 160, 168)), (1.0, (214, 236, 232))]


def ramp(v):
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        if v <= b:
            k = (v - a) / (b - a)
            return tuple(int(ca[i] + (cb[i] - ca[i]) * k) for i in range(3))
    return RAMP[-1][1]


def recolour(frame):
    out = frame.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # the gif is blue to white: brightness runs from the blue's own level up to white
            v = (r + g + 2 * b) / (4 * 255.0)
            v = min(1.0, max(0.0, (v - 0.2) / 0.8))
            px[x, y] = (*ramp(v), a)
    return out


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    gif = Image.open(src)
    frames = []
    for i in range(gif.n_frames):
        gif.seek(i)
        frames.append(recolour(gif.convert("RGBA")))
    for name, part in [("surf_crest", frames[:4]), ("surf_body", frames[4:])]:
        strip = Image.new("RGBA", (48 * len(part), 32), (0, 0, 0, 0))
        for i, f in enumerate(part):
            strip.paste(f, (i * 48, 0))
        strip.save(os.path.join(out_dir, name + ".png"))
        print("wrote", name, len(part), "frames")


if __name__ == "__main__":
    main()
