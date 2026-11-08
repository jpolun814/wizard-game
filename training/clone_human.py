"""Learns to move like a person from play recordings (behavior cloning).

Reads recordings (play_*.log, solo_*.log, net_*.log, or received .gz ones): every `O` line is what the wizard sensed (see scripts/sensing.gd) and the
`A` line before it is what the person was doing (move -1/0/1, jump, buttons). Trains a small network from the one to the other, prints how well it
copies (against always doing the most common thing), and writes the weights to JSON for the game to run (scripts/learned_brain.gd).

    python training/clone_human.py [--logs DIR_OR_FILE ...] [--out training/human_policy.json] [--epochs 40]
"""
import argparse, glob, gzip, json, os, sys
import numpy as np
import torch
import torch.nn as nn

GRID_CELLS = 11 * 9
DEFAULT_LOGS = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "wizard-game", "play_logs")


def read_lines(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def parse_obs(text):
    """`O` payload: 7 numbers, a digit for each ground tile (0 open, 1 platform, 2 solid, +4 lethal), then the rest of the numbers."""
    head, grid, rest = text.split(" ")
    out = [float(v) for v in head.split(",")]
    for ch in grid:
        code = int(ch)
        out += [(code & 3) * 0.5, 1.0 if code & 4 else 0.0]
    out += [float(v) for v in rest.split(",")]
    return out


def examples(path):
    """(observation, move 0..2, jump 0..1) for each O line, with the action last written before it."""
    action = None
    xs, moves, jumps = [], [], []
    for line in read_lines(path):
        parts = line.split(" ", 2)
        if len(parts) < 3:
            continue
        kind, rest = parts[1], parts[2]
        if kind == "A":
            a = rest.split()
            action = (int(a[0]) + 1, int(a[1]))
        elif kind == "O" and action is not None:
            try:
                xs.append(parse_obs(rest))
            except ValueError:
                continue
            moves.append(action[0])
            jumps.append(action[1])
    return xs, moves, jumps


def find_logs(targets):
    files = []
    for t in targets:
        if os.path.isdir(t):
            for pat in ("play_*.log", "solo_*.log", "net_*.log", "*.gz"):
                files += glob.glob(os.path.join(t, pat))
        elif os.path.isfile(t):
            files.append(t)
    return sorted(set(files))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="*", default=[DEFAULT_LOGS])
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "human_policy.json"))
    ap.add_argument("--epochs", type=int, default=40)
    args = ap.parse_args()

    X, M, J, per_file = [], [], [], []
    for path in find_logs(args.logs):
        xs, ms, js = examples(path)
        if xs:
            per_file.append((path, len(xs)))
            X += xs; M += ms; J += js
    if len(X) < 200:
        sys.exit("only %d examples: record more games (single-player records by itself)" % len(X))
    for path, n in per_file:
        print("%6d  %s" % (n, os.path.basename(path)))
    X = np.array(X, dtype=np.float32); M = np.array(M); J = np.array(J)
    print("examples", len(X), "inputs", X.shape[1])

    # Whole recordings are held out for the test, as the policy must copy a game it has not seen.
    n = len(X)
    cut = int(n * 0.85)
    Xt, Mt, Jt, Xv, Mv, Jv = X[:cut], M[:cut], J[:cut], X[cut:], M[cut:], J[cut:]

    net = nn.Sequential(nn.Linear(X.shape[1], 128), nn.ReLU(), nn.Linear(128, 64), nn.ReLU(), nn.Linear(64, 5))
    opt = torch.optim.Adam(net.parameters(), 1e-3, weight_decay=1e-4)
    # Jumping is rare: weigh it up so that the policy does not learn never to jump.
    jump_weight = torch.tensor([1.0, min(8.0, max(1.0, float((Jt == 0).sum()) / max(1, (Jt == 1).sum())))])
    xt, mt, jt = torch.tensor(Xt), torch.tensor(Mt), torch.tensor(Jt)
    xv, mv, jv = torch.tensor(Xv), torch.tensor(Mv), torch.tensor(Jv)
    for epoch in range(args.epochs):
        order = torch.randperm(len(xt))
        for i in range(0, len(xt), 256):
            idx = order[i:i + 256]
            out = net(xt[idx])
            loss = nn.functional.cross_entropy(out[:, :3], mt[idx]) + nn.functional.cross_entropy(out[:, 3:], jt[idx], weight=jump_weight)
            opt.zero_grad(); loss.backward(); opt.step()
        if epoch % 10 == 9 or epoch == args.epochs - 1:
            with torch.no_grad():
                out = net(xv)
                macc = (out[:, :3].argmax(1) == mv).float().mean().item()
                jacc = (out[:, 3:].argmax(1) == jv).float().mean().item()
            print("epoch %2d  move %.3f (always the commonest: %.3f)  jump %.3f (never jumping: %.3f)" % (
                epoch + 1, macc, np.bincount(Mv, minlength=3).max() / len(Mv), jacc, 1 - Jv.mean()))

    layers = [m for m in net if isinstance(m, nn.Linear)]
    data = {"inputs": int(X.shape[1]), "layers": [{"w": l.weight.detach().numpy().tolist(), "b": l.bias.detach().numpy().tolist()} for l in layers],
            "outputs": {"move": [0, 3], "jump": [3, 5]}}
    with open(args.out, "w") as f:
        json.dump(data, f)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
