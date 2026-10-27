"""Makes the mountains', tundra's and ashlands' backdrops from the graveyard's (GothicVania Cemetery by ansimuz, CC0).

Each place keeps the pictures' pixel art and gets its own colours: a picture's brightness is mapped onto a palette, so the
blood moon becomes a pale moon over the peaks, a hazy sun over the snow, or a smoulder over the ash. The far crags get
snow on their high parts. Run it from the project folder: python tools/prepare_biome_backdrops.py
"""
import os
import numpy as np
from PIL import Image

SOURCE = "art/backgrounds/cemetery"
rng = np.random.default_rng(7)


def load(name):
    return np.asarray(Image.open(os.path.join(SOURCE, name)).convert("RGBA")).astype(np.float32) / 255.0


def hexcolour(code):
    return np.array([int(code[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32) / 255.0


def gradient(stops, values):
    """Maps values in 0..1 onto a list of (position, colour) stops."""
    out = np.zeros(values.shape + (3,), dtype=np.float32)
    positions = [p for p, _ in stops]
    for channel in range(3):
        out[..., channel] = np.interp(values, positions, [hexcolour(c)[channel] for _, c in stops])
    return out


def recolour(image, stops, lift=0.0):
    brightness = image[..., :3] @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    brightness = np.clip((brightness - brightness.min()) / max(brightness.max() - brightness.min(), 1e-3) + lift, 0.0, 1.0)
    rgb = gradient(stops, brightness)
    return np.concatenate([rgb, image[..., 3:]], axis=2)


def save(array, place, name):
    folder = os.path.join("art/backgrounds", place)
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(array, 0, 1) * 255).astype(np.uint8)).save(os.path.join(folder, name))


def crags(image, top, bottom, snow=None, rim=None):
    """The far crags: a haze from the tops of the rocks down, snow on the high parts, a glow along the edge."""
    h, w = image.shape[:2]
    alpha = image[..., 3]
    out = np.zeros_like(image)
    tops = np.array([np.argmax(alpha[:, x] > 0.5) if (alpha[:, x] > 0.5).any() else h for x in range(w)])
    glow = np.convolve(rng.random(w), np.ones(9) / 9, mode="same") > 0.55  # embers glow along some of the ridge, not all of it
    shoulder = np.percentile(tops[tops < h], 70) if (tops < h).any() else h
    for x in range(w):
        for y in range(h):
            if alpha[y, x] <= 0.5:
                continue
            t = (y - tops[x]) / max(h - tops[x], 1)
            colour = hexcolour(top) * (1 - t) + hexcolour(bottom) * t
            if snow is not None:
                depth = np.clip((shoulder - tops[x]) * 0.7, 0, 60)
                depth += 3 * np.sin(x / 2.3) + rng.integers(-2, 3) if depth > 4 else 0
                if y - tops[x] < depth:
                    lit = 1.0 - 0.45 * (y - tops[x]) / max(depth, 1)
                    colour = hexcolour(snow[0]) * lit + hexcolour(snow[1]) * (1 - lit)
            if rim is not None and y - tops[x] < 2 and glow[x]:
                colour = hexcolour(rim)
            out[y, x, :3] = colour
            out[y, x, 3] = 1.0
    return out


sky = load("sky.png")
far = load("far.png")
near = load("near.png")

# Mountains: a cold twilight, a pale moon, tall grey-blue peaks capped with snow.
save(recolour(sky, [(0.0, "#070b18"), (0.35, "#1b2744"), (0.7, "#4a628f"), (1.0, "#e8f0ff")]), "mountains", "sky.png")
save(crags(far, "#6f82a6", "#171d30", snow=("#f2f7ff", "#a9bdd9")), "mountains", "far.png")
save(recolour(near, [(0.0, "#080b14"), (0.6, "#1b2438"), (1.0, "#53668c")]), "mountains", "near.png")

# Tundra: a pale low sun in a teal sky, ice-white ridges, snow-covered ground with the graveyard's bare trees standing in it.
save(recolour(sky, [(0.0, "#08202c"), (0.4, "#1f5a6e"), (0.75, "#86c4d4"), (1.0, "#f4fcff")]), "tundra", "sky.png")
save(crags(far, "#c9e4ee", "#4a7a90", snow=("#ffffff", "#cfe9f2")), "tundra", "far.png")
save(recolour(near, [(0.0, "#1c3345"), (0.5, "#5a8aa3"), (1.0, "#f2fbff")], lift=0.25), "tundra", "near.png")

# Ashlands: a smouldering red sky, black crags edged with ember, ash-dark hills.
save(recolour(sky, [(0.0, "#0d0305"), (0.4, "#4a0f0c"), (0.75, "#b8350f"), (1.0, "#ffb347")]), "ashlands", "sky.png")
save(crags(far, "#1c0807", "#040102", rim="#ff6a1f"), "ashlands", "far.png")
save(recolour(near, [(0.0, "#070203"), (0.6, "#2a0c08"), (1.0, "#7a2a14")]), "ashlands", "near.png")
print("done")

# Snow: the ice tiles (church stone, recoloured) brightened to snow, for the mountains' high ground and the tundra's floor.
ice = np.asarray(Image.open("art/tiles/ice.png").convert("RGBA")).astype(np.float32) / 255.0
snow = recolour(ice, [(0.0, "#a3b9d6"), (0.5, "#e2edf9"), (1.0, "#ffffff")])
Image.fromarray((np.clip(snow, 0, 1) * 255).astype(np.uint8)).save("art/tiles/snow.png")
print("snow tiles done")
