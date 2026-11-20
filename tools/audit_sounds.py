"""Judges every sound in the game against what it is meant to be, and looks for better ones in the NOX pack.

    python tools/audit_sounds.py [report.md]

For each owner and event (data/sounds.json and each spell's `sounds`), the sound's files are scored against the words in tools/sound_descriptions.json
with CLAP (tools/sound_search.py), and the same words are scored against every recording in the index (`sound_search.py index <NOX folder>`).
The report gives, for each: the score, how many of the pack's recordings match the words better (rank), and the three best of them. A low score means the
sound may not be what it claims; a high rank number means the pack has something that fits better. A proxy for an ear, never one.
"""
import glob
import json
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sound_search as ss

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def owned():
    reg = json.load(open(os.path.join(ROOT, "data/sounds.json")))
    for f in glob.glob(os.path.join(ROOT, "data/spells/*.tres")):
        t = open(f, encoding="utf-8").read()
        n = re.search(r'spell_name = "([^"]+)"', t)
        m = re.search(r"^sounds = (\{.*\})$", t, re.M)
        if n and m:
            reg[n.group(1)] = json.loads(m.group(1))
    for owner, events in sorted(reg.items()):
        if owner.startswith("mob_") and owner != "mob_basic":
            continue
        for event, name in sorted(events.items()):
            files = sorted(glob.glob(os.path.join(ROOT, "audio", name + ".*")) + glob.glob(os.path.join(ROOT, "audio", name + "_[0-9]*.*")))
            files = [f for f in files if not f.endswith(".import")]
            yield owner, event, files


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "sound_audit.md")
    words = json.load(open(os.path.join(ROOT, "tools/sound_descriptions.json")))
    model, proc, torch = ss.load_model()
    idx = np.load(ss.INDEX)
    names = [os.path.basename(str(f)) for f in idx["files"]]
    rows = []
    texts = {}
    for owner, event, files in owned():
        d = words.get("%s/%s" % (owner, event)) or words.get("*/" + event)
        if d is None:
            print("no description:", owner, event)
            continue
        if d not in texts:
            texts[d] = ss.embed_text([d], model, proc, torch)[0]
        v = ss.embed_audio(files, model, proc, torch).mean(axis=0)
        v /= np.linalg.norm(v)
        score = float(v @ texts[d])
        pack = idx["vecs"] @ texts[d]
        rank = int((pack > score).sum())
        best = [(float(pack[k]), names[k]) for k in np.argsort(-pack)[:3]]
        rows.append((owner, event, d, score, rank, best))
    rows.sort(key=lambda r: (-r[4], r[3]))
    with open(out, "w", encoding="utf-8") as f:
        f.write("| owner / event | meant to be | score | better in pack | best three |\n|---|---|---|---|---|\n")
        for owner, event, d, score, rank, best in rows:
            f.write("| %s / %s | %s | %.2f | %d | %s |\n" % (owner, event, d, score, rank, "; ".join("%.2f %s" % b for b in best)))
    print("wrote", out, len(rows))


if __name__ == "__main__":
    main()
