"""Renders every variant of every slot into a frame-aligned sprite sheet + writes manifest.json.
usage: python build.py [out_dir] [slot ...]   (default out_dir: art_source/parts_sheets). Then run tools/pack_parts.gd."""
import itertools
import json
import os
import sys
import time
from multiprocessing import Pool

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from parts import SLOTS, OPTIONS, KEY, SPELLS, variant_key, render_layer, W, H  # noqa: E402
from poses import ANIMS, all_frames  # noqa: E402

COLS = 9
DEFAULT = {k: v[0] for k, v in OPTIONS.items()}


def sheet_size(n):
    return COLS * W, ((n + COLS - 1) // COLS) * H


def variants(slot):
    deps = dict(SLOTS)[slot]
    seen = {}
    for combo in itertools.product(*[OPTIONS[d] for d in deps]):
        cfg = dict(DEFAULT)
        cfg.update(zip(deps, combo))
        seen.setdefault(variant_key(slot, cfg), cfg)
    return seen


_FRAMES = None


def job(args):
    global _FRAMES
    slot, key, cfg, out = args
    if _FRAMES is None:
        _FRAMES = all_frames()
    sw, sh = sheet_size(len(_FRAMES))
    sheet = np.zeros((sh, sw, 4), np.uint8)
    for k, (_, i, p, extra) in enumerate(_FRAMES):
        px = render_layer(slot, p, extra, cfg, i)
        x, y = (k % COLS) * W, (k // COLS) * H
        sheet[y:y + H, x:x + W] = px
    if not sheet[..., 3].any():
        return slot, key, False
    os.makedirs(os.path.join(out, slot), exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(out, slot, key + ".png"), optimize=True)
    return slot, key, True


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "art_source", "parts_sheets"))
    only = sys.argv[2:]  # optional: limit to some slots
    tasks = []
    for slot, _ in SLOTS:
        if only and slot not in only:
            continue
        for key, cfg in variants(slot).items():
            tasks.append((slot, key, cfg, out))
    t0 = time.time()
    written = {}
    with Pool(max(1, os.cpu_count() - 1)) as pool:
        for n, (slot, key, ok) in enumerate(pool.imap_unordered(job, tasks), 1):
            if ok:
                written.setdefault(slot, []).append(key)
            if n % 25 == 0:
                print(f"{n}/{len(tasks)}  {time.time() - t0:.0f}s", flush=True)
    frames, start = {}, 0
    for name, n, _, fps, loop in ANIMS:
        frames[name] = dict(start=start, count=n, fps=fps, loop=loop)
        start += n
    sw, sh = sheet_size(start)
    manifest_path = os.path.join(out, "manifest.json")
    old = {}
    if only and os.path.exists(manifest_path):
        old = json.load(open(manifest_path))["slots"]
    slots = []
    for slot, deps in SLOTS:
        keys = sorted(written.get(slot, [])) if (not only or slot in only) else next(
            (s["variants"] for s in old if s["name"] == slot), [])
        slots.append(dict(name=slot, depends_on=deps, variants=keys))
    manifest = dict(
        frame_size=[W, H], columns=COLS, sheet_size=[sw, sh], frame_count=start,
        feet="bottom row of the frame, centred at x=127; the figure faces right",
        animations=frames,
        options=OPTIONS,
        magic=dict(slot="magic", key_greys=[list(k) for k in KEY], white=[255, 255, 255],
                   rule="each pixel of the magic slot is one of these greys; replace by the cast spell's ramp "
                        "(near-white, light, mid, deep); pure white stays white. See godot/magic_ramp.gdshader.",
                   example_spells={k: [list(c) for c in v] for k, v in SPELLS.items()}),
        slots=slots,
        file_pattern="<slot>/<variant>.png where <variant> joins the slot's depends_on option values with '-' "
                     "(hats in HAT_NO_COLOR ignore hat_color). A missing file means that slot is empty for that choice.",
        draw_order="slots are listed back to front",
    )
    json.dump(manifest, open(manifest_path, "w"), indent=1)
    print(f"done: {sum(len(v) for v in written.values())} sheets in {time.time() - t0:.0f}s -> {out}")


if __name__ == "__main__":
    main()
