"""Trains the learned tactics (TacticsBrain: which attack and when, and how to move in a fight) by self-play, with PPO over Godot RL Agents.

In rounds: each round plays in a world of a seed of its own, the learners against the scripted brain and (from the second round on) against the
network as it was at the end of an earlier round, so it learns to beat both. After each round the model is saved (training/tactics/round_N.zip),
exported for the game (training/tactics/round_N.json, the same form as ai/tactics.json), and a line is written to training/tactics/progress.log.
A run can be stopped and started again: it carries on from the last round saved.

    python -I training/train_tactics.py [--rounds 1000] [--round-steps 20000] [--port 11040] [--envs 2] [--learners 4] [--duel] [--out DIR]
                                        [--arena] [--lanes 3]

--arena trains in the bare training arena (training/training_arena.tscn: flat lanes, one duel to a lane) instead of a match world. A new network then
starts as a copy of the scripted brain: its first choices are, almost always, "do what the scripted brain would" (see scripted_start), so it begins as
strong as the scripted brain and learns only where doing otherwise wins. Its first WARMUP_ROUNDS rounds teach only the critic; then it learns in small
steps (learning rate 1e-4, target_kl, a narrow clip), against the scripted brain two rounds in three and its latest self the third. Every EVAL_EVERY
rounds it is measured against the scripted brain alone, learning nothing ("measure" lines in the progress log): the best network so far is kept as
best.zip and best.json, and a measure well under the best sends training back to it.
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
import torch

OUT = os.path.join(here, "tactics")
CAUSES = ("outlive", "fall", "pages", "harm")


class Tally(BaseCallback):
    """Adds up the reward of the round, and how often the learners fell and outlived others, for the progress log."""

    def __init__(self):
        super().__init__()
        self.total = 0.0
        self.n = 0
        self.infos = []

    def _on_step(self):
        self.total += float(np.sum(self.locals["rewards"]))
        self.n += len(self.locals["rewards"])
        self.infos = list(self.locals.get("infos", []) or self.infos)
        return True

    def bouts(self):
        """Bouts won and lost by all the learners this round (from what each agent counts of its own life: TacticsAgent.get_info)."""
        return bouts_of(self.infos)


def bouts_of(infos):
    """Bouts won and lost, from what each agent counts of its own (TacticsAgent.get_info): felled the other or fell, and, of the bouts that ran their
    time, won or lost on points (training_arena.gd)."""
    infos = [i for i in infos if isinstance(i, dict)]
    won = sum(int(i.get("outlived", 0)) + int(i.get("points_won", 0)) for i in infos)
    lost = sum(int(i.get("deaths", 0)) + int(i.get("points_lost", 0)) for i in infos)
    return won, lost


def scripted_start(model, casts=40):
    """Makes a new network start as the scripted brain: its last layer leans hard toward choice 0 of each kind ("the scripted brain's own pick" for
    the attack, "the scripted footwork" for the movement), and its weights are made small, so that what it senses hardly moves it at first."""
    with torch.no_grad():
        head = model.policy.action_net
        head.weight.mul_(0.1)
        head.bias.zero_()
        head.bias[0] = 9.0       # the scripted attack all but once in two hundred choices (at 6, one in ten went elsewhere, often into a spell that hurt it)
        head.bias[casts] = 8.0   # and the scripted footwork all but once in a thousand


WARMUP_ROUNDS = int(os.environ.get("WARMUP_ROUNDS", "4"))      # arena: the first rounds teach only the critic (what a moment is worth); the choices stay the scripted brain's copy
EVAL_EVERY = int(os.environ.get("EVAL_EVERY", "4"))         # arena: rounds between measures against the scripted brain
EVAL_DECISIONS = int(os.environ.get("EVAL_DECISIONS", "60000"))  # decisions in a measure, played without learning: about 170 bouts (a fall or points), so one measure is good to about 0.04
GIVE_BACK = 0.08       # a measure this far under the best so far, and training goes back to the best network


def freeze_choices(model, frozen):
    """Holds the policy's own layers still (or lets them learn again), so that only the critic learns. A critic that starts untrained gives
    advantages that are noise, and a policy that learns from those wanders off a good start (the first arena run fell from 0.52 to 0.37 so)."""
    for name, param in model.policy.named_parameters():
        if name.startswith("mlp_extractor.policy_net") or name.startswith("action_net"):
            param.requires_grad_(not frozen)


def measure(model, args, seed):
    """Bouts won and lost against the scripted brain alone, playing as the game would (choices sampled), learning nothing."""
    env = make_env(args.port, seed, args.envs, args.learners, "", args.duel, args.lanes)
    obs = env.reset()
    decisions = 0
    infos = []
    while decisions < EVAL_DECISIONS:
        action, _ = model.predict(obs, deterministic=False)
        obs, rewards, dones, step_infos = env.step(action)
        decisions += len(rewards)
        infos = list(step_infos) or infos
    env.close()
    return bouts_of(infos)


def read_best():
    path = os.path.join(OUT, "best.txt")
    if os.path.exists(path):
        parts = open(path).read().split()
        return int(parts[0]), float(parts[1])
    return 0, -1.0


def export(model, path):
    """Writes the policy network as JSON for scripts/policy_net.gd: its two hidden layers (tanh) and the action head."""
    net = model.policy
    layers = []
    for name in ("mlp_extractor.policy_net.0", "mlp_extractor.policy_net.2", "action_net"):
        module = net
        for part in name.split("."):
            module = getattr(module, part) if not part.isdigit() else module[int(part)]
        layers.append({"w": module.weight.detach().cpu().numpy().tolist(), "b": module.bias.detach().cpu().numpy().tolist()})
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


def make_env(port, seed, envs, learners, opponent, duel=False, lanes=0):
    extra = {"learners": learners}
    if duel:
        extra["duel"] = 1
    if lanes:
        extra = {"lanes": lanes}
    if opponent:
        extra["opponent"] = opponent
    return StableBaselinesGodotEnv(env_path="godot", n_parallel=envs, port=port, show_window=False, speedup=8, action_repeat=12, framerate=60,
                                   world_seed=seed, **extra)


def main():
    global OUT
    torch.set_num_threads(int(os.environ.get("TRAIN_THREADS", "2")))  # (the rest of the cores are the games': torch would take them all, and the games would wait)
    parser = argparse.ArgumentParser()
    parser.add_argument("--rounds", type=int, default=1000)
    parser.add_argument("--round-steps", type=int, default=20000)
    parser.add_argument("--port", type=int, default=11040)
    parser.add_argument("--envs", type=int, default=2)
    parser.add_argument("--learners", type=int, default=4)
    parser.add_argument("--duel", action="store_true", help="each learner fights one opponent over and over (a denser reward)")
    parser.add_argument("--out", default=OUT, help="the folder rounds are kept in (a trial can use one of its own)")
    parser.add_argument("--arena", action="store_true", help="train in the bare training arena, starting from a copy of the scripted brain")
    parser.add_argument("--lanes", type=int, default=3)
    parser.add_argument("--device", default="cpu", help="cpu, or cuda for the graphics card (for a small network the processor is often the faster)")
    args = parser.parse_args()
    if args.arena:
        os.environ["GODOT_SCENE"] = "res://training/training_arena.tscn"
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    start = last_round()
    model = None
    for k in range(start + 1, start + 1 + args.rounds):
        seed = random.Random(k).randrange(0, 40)
        earlier = [p for p in glob.glob(os.path.join(OUT, "round_*.json"))]
        # Half the rounds the opponents include the latest version, half an older one drawn at random: it must beat all it has been.
        opponent = ""
        if args.arena:
            # The arena: the scripted brain two rounds in three, and the latest network the third. Not old networks drawn at random: beating weaker
            # copies of itself taught it tricks that lost to the scripted brain. None at all while only the critic learns.
            if earlier and k > WARMUP_ROUNDS and k % 3 == 0:
                earlier.sort(key=lambda p: int(re.search(r"round_(\d+)", p).group(1)))
                opponent = earlier[-1]
        elif earlier:
            earlier.sort(key=lambda p: int(re.search(r"round_(\d+)", p).group(1)))
            opponent = earlier[-1] if random.Random(k * 7).random() < 0.5 else random.Random(k * 13).choice(earlier)
        if opponent:
            opponent = "res://" + os.path.relpath(opponent, os.path.dirname(here)).replace("\\", "/")
        env = make_env(args.port, seed, args.envs, args.learners, opponent, args.duel, args.lanes if args.arena else 0)
        if model is None:
            previous = os.path.join(OUT, "round_%d.zip" % start)
            if start > 0 and os.path.exists(previous):
                model = PPO.load(previous, env=env, device=args.device)
            else:
                gentle = dict(learning_rate=1e-4, target_kl=0.015, clip_range=0.1) if args.arena else dict(learning_rate=3e-4)  # (small steps, from a good start)
                model = PPO("MultiInputPolicy", env, n_steps=512, batch_size=256, ent_coef=0.005 if args.arena else 0.02, gamma=0.995,
                            verbose=0, device=args.device, **gentle)
                if args.arena:
                    scripted_start(model)
        else:
            model.set_env(env)
        if args.arena:
            freeze_choices(model, k <= WARMUP_ROUNDS)
        tally = Tally()
        began = time.time()
        model.learn(total_timesteps=args.round_steps, callback=tally, reset_num_timesteps=False)
        infos = [i for i in getattr(env, "last_infos", []) or []]
        env.close()
        model.save(os.path.join(OUT, "round_%d.zip" % k))
        export(model, os.path.join(OUT, "round_%d.json" % k))
        won, lost = tally.bouts()
        log("round %d seed %d opponent %s: reward per decision %.4f over %d decisions, %.0f s, steps %d, won %d lost %d (%s)" % (
            k, seed, os.path.basename(opponent) or "scripted", tally.total / max(tally.n, 1), tally.n, time.time() - began, model.num_timesteps,
            won, lost, ("%.2f" % (won / (won + lost))) if won + lost else "-"))
        if args.arena and k >= WARMUP_ROUNDS and (k - WARMUP_ROUNDS) % EVAL_EVERY == 0:
            began = time.time()
            won, lost = measure(model, args, seed)
            share = won / (won + lost) if won + lost else 0.0
            best_round, best = read_best()
            note = ""
            if share > best:
                best_round, best = k, share
                model.save(os.path.join(OUT, "best.zip"))
                export(model, os.path.join(OUT, "best.json"))
                open(os.path.join(OUT, "best.txt"), "w").write("%d %.4f" % (k, share))
                note = ", the best so far"
            elif share < best - GIVE_BACK:
                model = PPO.load(os.path.join(OUT, "best.zip"), device=args.device)
                note = ", well under the best (round %d, %.2f): back to that network" % (best_round, best)
            log("measure after round %d against the scripted brain alone: won %d lost %d (%.2f) in %.0f s%s" % (k, won, lost, share, time.time() - began, note))


if __name__ == "__main__":
    main()
