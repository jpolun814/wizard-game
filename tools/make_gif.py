"""Puts the frames saved by tests/tools/arena_sim.tscn (frames=DIR) together into a GIF.

    python tools/make_gif.py FRAMES_DIR OUT.gif [--fps 12] [--width 512] [--from N] [--to N] [--colors 128]

All frames share one palette, made from the whole clip, so the colors do not shift from frame to frame, and nothing is dithered, so the pixel art stays clean.
"""
import argparse
import glob
import os

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("frames")
parser.add_argument("out")
parser.add_argument("--fps", type=float, default=12.0)
parser.add_argument("--width", type=int, default=512)
parser.add_argument("--from", dest="first", type=int, default=0)
parser.add_argument("--to", dest="last", type=int, default=10**9)
parser.add_argument("--colors", type=int, default=256)
parser.add_argument("--method", default="FASTOCTREE", help="FASTOCTREE, MEDIANCUT or MAXCOVERAGE: how the palette is made; FASTOCTREE keeps small bright things (a flame) their colors")
parser.add_argument("--local", action="store_true", help="give each picture its own palette: a small bright thing (a flame) keeps its colors, and the file is larger")
parser.add_argument("--crop", default="", help="x0,y0,x1,y1 of the part of each picture to keep, before it is scaled")
args = parser.parse_args()

paths = sorted(glob.glob(os.path.join(args.frames, "f*.png")))[args.first:args.last]
if not paths:
    raise SystemExit("no frames in " + args.frames)
frames = []
for p in paths:
    im = Image.open(p).convert("RGB")
    if args.crop:
        im = im.crop(tuple(int(v) for v in args.crop.split(",")))
    height = round(im.height * args.width / im.width)
    frames.append(im.resize((args.width, height), Image.NEAREST if args.width % im.width == 0 else Image.LANCZOS))

# one palette for the whole clip, drawn from a sheet of every few frames
step = max(1, len(frames) // 40)
sample = frames[::step]
sheet = Image.new("RGB", (frames[0].width, frames[0].height * len(sample)))
for i, f in enumerate(sample):
    sheet.paste(f, (0, i * f.height))
palette = sheet.quantize(colors=args.colors, method=getattr(Image.Quantize, args.method), dither=Image.Dither.NONE)
if args.local:
    out = [f.quantize(colors=args.colors, method=getattr(Image.Quantize, args.method), dither=Image.Dither.NONE) for f in frames]
else:
    out = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
out[0].save(args.out, save_all=True, append_images=out[1:], duration=round(1000 / args.fps), loop=0, optimize=False, disposal=1)
print("%s: %d frames, %.1f s, %d KB" % (args.out, len(out), len(out) / args.fps, os.path.getsize(args.out) // 1024))
