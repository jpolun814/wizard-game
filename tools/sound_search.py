"""Finds sounds by describing them, and says what a sound is: the nearest thing to listening that a script can do.

    python tools/sound_search.py index <folder> [<folder>...]      adds every .wav/.ogg/.mp3/.flac under the folders to tools/sound_index.npz (files already in it are skipped)
    python tools/sound_search.py find "a heavy stone door scraping" [-n 10]     the best matches in the index, with their scores
    python tools/sound_search.py label audio/wizard__step_dirt_1.wav            how well a file matches each of a list of plain descriptions
    python tools/sound_search.py check "a footstep" audio/a.wav audio/b.wav     scores each file against one description

It uses LAION's CLAP (laion/clap-htsat-unfused, a model that puts sounds and sentences in one space; downloaded on first use, about 600 MB, kept by
Hugging Face's cache). Scores are cosine similarities: only their order and gaps mean anything, and a model is a proxy for an ear, never the ear
(the owner's is final). Good at "is this a footstep, a whoosh, thunder, wind"; poor at "is it pleasant" or "is it too loud". Needs torch, transformers,
numpy, soundfile.
"""
import argparse
import os
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
INDEX = os.path.join(HERE, "sound_index.npz")
MODEL = "laion/clap-htsat-unfused"
RATE = 48000
KINDS = ["a footstep", "a whoosh of air", "thunder", "an explosion", "wind blowing", "water flowing", "fire crackling", "a rock or stone thud", "breaking ice or glass",
         "a human voice", "a magical spell", "a rumble", "a creature growl", "a click", "cloth rustling", "a heartbeat"]


def load_model():
    import torch
    from transformers import ClapModel, ClapProcessor
    return ClapModel.from_pretrained(MODEL).eval(), ClapProcessor.from_pretrained(MODEL), torch


def clip(path):
    x, rate = sf.read(path, always_2d=True)
    x = x.mean(axis=1).astype(np.float32)
    if rate != RATE:
        n = int(len(x) * RATE / rate)
        x = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)
    x = x[: RATE * 10]
    return x * (0.9 / max(float(np.abs(x).max()), 1e-6))  # every clip at one peak: the model hears level, and a quiet recording would score worse for being quiet


def embed_audio(files, model, proc, torch):
    out = []
    for i in range(0, len(files), 16):
        batch = [clip(f) for f in files[i:i + 16]]
        inputs = proc(audios=batch, sampling_rate=RATE, return_tensors="pt")
        with torch.no_grad():
            e = model.get_audio_features(**inputs)
        out.append(torch.nn.functional.normalize(e, dim=-1).numpy())
        print("  %d/%d" % (min(i + 16, len(files)), len(files)), file=sys.stderr)
    return np.concatenate(out)


def embed_text(texts, model, proc, torch):
    with torch.no_grad():
        e = model.get_text_features(**proc(text=texts, return_tensors="pt", padding=True))
    return torch.nn.functional.normalize(e, dim=-1).numpy()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["index", "find", "label", "check"])
    ap.add_argument("args", nargs="+")
    ap.add_argument("-n", type=int, default=10)
    a = ap.parse_args()
    model, proc, torch = load_model()
    if a.cmd == "index":  # adds to the index: files already in it are kept, not embedded again
        files = sorted(os.path.join(r, f) for d in a.args for r, _, fs in os.walk(d) for f in fs if f.lower().endswith((".wav", ".ogg", ".flac", ".mp3")) and "__MACOSX" not in r and not f.startswith("._"))
        old = np.load(INDEX) if os.path.exists(INDEX) else None
        have = set(str(f) for f in old["files"]) if old is not None else set()
        new = [f for f in files if f not in have]
        if new:
            vecs = embed_audio(new, model, proc, torch)
            np.savez(INDEX, files=np.array(list(old["files"] if old is not None else []) + new), vecs=np.concatenate([old["vecs"], vecs]) if old is not None else vecs)
        print("indexed", len(new), "new,", len(have) + len(new), "in all")
    elif a.cmd == "find":
        d = np.load(INDEX)
        s = d["vecs"] @ embed_text([a.args[0]], model, proc, torch)[0]
        for k in np.argsort(-s)[: a.n]:
            print("%.3f  %s" % (s[k], d["files"][k]))
    elif a.cmd == "label":
        s = embed_text(KINDS, model, proc, torch) @ embed_audio(a.args, model, proc, torch).T
        for j, f in enumerate(a.args):
            print(f)
            for k in np.argsort(-s[:, j])[:4]:
                print("   %.3f  %s" % (s[k, j], KINDS[k]))
    else:
        s = embed_audio(a.args[1:], model, proc, torch) @ embed_text([a.args[0]], model, proc, torch)[0]
        for f, v in zip(a.args[1:], s):
            print("%.3f  %s" % (v, f))


if __name__ == "__main__":
    main()
