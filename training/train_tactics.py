"""Trains the learned tactics (TacticsBrain: which attack and when, and how to move in a fight) by self-play, with PPO over Godot RL Agents.

In rounds: each round plays in a world of a seed of its own, the learners against the scripted brain and (from the second round on) against the
network as it was at the end of an earlier round, so it learns to beat both. After each round the model is saved (training/tactics/round_N.zip),
exported for the game (training/tactics/round_N.json, the same form as ai/tactics.json), and a line is written to training/tactics/progress.log.
A run can be stopped and started again: it carries on from the last round saved.

    python -I training/train_tactics.py [--rounds 1000] [--round-steps 20000] [--port 11040] [--envs 2] [--learners 4] [--duel] [--out DIR]
"""
import argparse
import glob
import json
import os
import random
import re
import sys
import time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
os.environ.setdefault("GODOT_SCENE", "res://training/tactics_env.tscn")

import numpy as np
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

import gd_launch  # noqa: starts the project's own scene

OUT = os.path.join(here, "tactics")
CAUSES = ("outlive", "fall", "pages", "harm")


class Tally(BaseCallback):
    """Adds up the reward of the round, and how often the learners fell and outlived others, for the progress log."""

    def __init__(self):
        super().__init__()
        self.total = 0.0
        self.n = 0

    def _on_step(self):
        self.total += float(np.sum(self.locals["rewards"]))
        self.n += len(self.locals["rewards"])
        return True


def export(model, path):
    """Writes the policy network as JSON for scripts/policy_net.gd: its two hidden layers (tanh) and the action head."""
    net = model.policy
    layers = []
    for name in ("mlp_extractor.policy_net.0", "mlp_extractor.policy_net.2", "action_net"):
        module = net
        for part in name.split("."):
            module = getattr(module, part) if not part.isdigit() else module[int(part)]
        layers.append({"w": module.weight.detach().numpy().tolist(), "b": module.bias.detach().numpy().tolist()})
    casts = 40
    json.dump({"activation": "tanh", "sample": True, "layers": layers, "outputs": {"cast": [0, casts], "mode": [casts, casts + 4]}}, open(path, "w"))


def last_round():
    rounds = [int(m.group(1)) for p in glob.glob(os.path.join(OUT, "round_*.zip")) if (m := re.search(r"round_(\d+)\.zip$", p))]
    return max(rounds) if rounds else 0


def log(line):
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(os.path.join(OUT, "progress.log"), "a", encoding="utf-8") as f:
        f.write("%s %s\n" % (stamp, line))
    print(stamp, line, flush=True)


def make_env(port, seed, envs, learners, opponent, duel=False):
    extra = {"learners": learners}
    if duel:
        extra["duel"] = 1
    if opponent:
        extra["opponent"] = opponent
    return StableBaselinesGodotEnv(env_path="godot", n_parallel=envs, port=port, show_window=False, speedup=8, action_repeat=12, framerate=60,
                                   world_seed=seed, **extra)


def main():
    global OUT
    parser = argparse.ArgumentParser()
    parser.add_argument("--rounds", type=int, default=1000)
    parser.add_argument("--round-steps", type=int, default=20000)
    parser.add_argument("--port", type=int, default=11040)
    parser.add_argument("--envs", type=int, default=2)
    parser.add_argument("--learners", type=int, default=4)
    parser.add_argument("--duel", action="store_true", help="each learner fights one opponent over and over (a denser reward)")
    parser.add_argument("--out", default=OUT, help="the folder rounds are kept in (a trial can use one of its own)")
    args = parser.parse_args()
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    start = last_round()
    model = None
    for k in range(start + 1, start + 1 + args.rounds):
        seed = random.Random(k).randrange(0, 40)
        earlier = [p for p in glob.glob(os.path.join(OUT, "round_*.json"))]
        # Half the rounds the opponents include the latest version, half an older one drawn at random: it must beat all it has been.
        opponent = ""
        if earlier:
            earlier.sort(key=lambda p: int(re.search(r"round_(\d+)", p).group(1)))
            opponent = earlier[-1] if random.Random(k * 7).random() < 0.5 else random.Random(k * 13).choice(earlier)
            opponent = "res://" + os.path.relpath(opponent, os.path.dirname(here)).replace("\\", "/")
        env = make_env(args.port, seed, args.envs, args.learners, opponent, args.duel)
        if model is None:
            previous = os.path.join(OUT, "round_%d.zip" % start)
            if start > 0 and os.path.exists(previous):
                model = PPO.load(previous, env=env, device="cpu")
            else:
                model = PPO("MultiInputPolicy", env, n_steps=512, batch_size=256, learning_rate=3e-4, ent_coef=0.02, gamma=0.995, verbose=0, device="cpu")
        else:
            model.set_env(env)
        tally = Tally()
        began = time.time()
        model.learn(total_timesteps=args.round_steps, callback=tally, reset_num_timesteps=False)
        infos = [i for i in getattr(env, "last_infos", []) or []]
        env.close()
        model.save(os.path.join(OUT, "round_%d.zip" % k))
        export(model, os.path.join(OUT, "round_%d.json" % k))
        log("round %d seed %d opponent %s: reward per decision %.4f over %d decisions, %.0f s, steps %d" % (
            k, seed, os.path.basename(opponent) or "scripted", tally.total / max(tally.n, 1), tally.n, time.time() - began, model.num_timesteps))


if __name__ == "__main__":
    main()
