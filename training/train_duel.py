"""The curriculum: a wizard learns to play through a person's controls alone (HandBrain: keys, a spell, where), by self-play in the duel arena
(training/duel_arena.tscn), one stage at a time. Stage 1 is a flat lane, two wizards and Fireball only.

How it learns, and why (the research behind each choice is in docs/handoff/17_learned_ai.md):
- PPO with invalid-action masking (sb3-contrib MaskablePPO): a spell not in the book, or any spell while the hand is drawing, cannot be chosen at
  all; punishing such choices instead fails when most choices are impossible (Huang and Ontanon, 2020).
- Self-play against a pool of its own past versions: the latest most of the time, an older one now and then (OpenAI Five's 80 to 20, done in the
  arena), so it keeps beating what it was and does not go round in circles or forget.
- The reward is outcomes only (TacticsAgent in a duel): strength taken from the other against strength lost, and the bout won or lost. Nothing says
  how to win.
- A measure every few rounds, learning nothing, against yardsticks: a dummy that stands still (can it aim?), a turret that stands and casts
  Fireball at it (can it dodge, and win?), and an earlier version of itself (is it still getting better?). The pass mark for a stage is in PASS.
- A stage past the first starts from the last network of the one before (--from round_N.zip, kept in the new folder as champion.zip/json): the
  choices of the new spells start as likely as Fireball was, a little less (NEW_SPELL_SHARE), so it tries them where it would have thrown a Fireball
  (choices it was never allowed are otherwise left where chance put them, and seldom tried). Its measure adds a bout against that champion, which
  has only its own stage's spells: the new ones must win more than the old did alone. A quarter of its training bouts are fought with an earlier
  stage's book (DuelArena.EARLIER_SHARE).

Each round's network is saved (round_N.zip) and exported for the game and the arena's pool (round_N.json); progress.log has a line for each round
and each measure. Stop it by creating STOP in its folder. It carries on from the last round saved.

    python -I training/train_duel.py [--stage 1] [--out training/duel] [--envs 5] [--lanes 4] [--port 11400] [--round-steps 20480]
    python -I training/train_duel.py --stage 2 --out training/duel3 --from training/duel2/round_85.zip
"""
import argparse
import glob
import json
import os
import random
import re
import shutil
import math
import sys
import time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
os.environ["GODOT_SCENE"] = "res://training/duel_arena.tscn"

import numpy as np
import torch
from sb3_contrib import MaskablePPO
from sb3_contrib.common.maskable.utils import get_action_masks
from stable_baselines3.common.callbacks import BaseCallback
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

import gd_launch  # noqa: starts the project's own scene
from entity_net import EntityExtractor, export_dict, SIZE as ENTITY_SIZE

HEADS = [("aim_x", 32), ("aim_y", 18), ("cast", 97), ("jump", 2), ("move", 3)]  # HandBrain.HEADS, in order (by name: Godot RL Agents sorts them)
MASK = sum(n for _, n in HEADS)
EVAL_EVERY = int(os.environ.get("EVAL_EVERY", "5"))
EVAL_DECISIONS = int(os.environ.get("EVAL_DECISIONS", "20000"))
PASS = {"dummy": 0.9, "turret": 0.6}  # the stage is learned when it fells the still dummy this often (it aims) and beats the turret this often (it
                                      # dodges). The turret mark was 0.75, set without evidence; the owner set it at 0.6 for now (2026-11-11)
STAGE = 1  # (set from --stage in main)
OUT = os.path.join(here, "duel2")  # (training/duel holds the first stage 1 run, with one flat network)
ENT_COEF = 0.003  # the pull toward trying everything: at 0.01 it held the 576 aiming cells near random against the few hits (2026-11-11)
REFINE_ENT = 0.001  # once it aims: at 0.003 its aim, good at its likeliest (57% of shots landed), was spread wide enough that choices drawn by
                    # weight landed 48%
N_EPOCHS = 10     # passes over each batch of play: more is learned from the rare hits
LEARNING_RATE = 3e-4  # how far each update moves the network while it learns; REFINE_RATE once it aims (see curriculum)
REFINE_RATE = 1e-4    # lowered when the first run plateaued (the dummy 81 to 89%, the turret 44 to 49% for eight measures, 2026-11-11): it refines what
                      # it has instead of jostling about it (the turret went 45, 51, 60%)
REFINE_FROM = 0.5     # the share of its shots that land on the dummy from which it refines: smaller steps, and less pull toward trying everything
CHAMPION_PASS = 0.6  # past stage 1, it must also beat the last stage's champion this often (the champion with its own stage's spells only)
NEW_SPELL_SHARE = 1.0 / 3.0  # at the start of a stage, each new spell is this likely against Fireball's choice (see the docstring)
STAGE_SPELLS = {1: ["Ignite"], 2: ["Frostbolt", "Barrier", "Stone Wall"]}  # DuelArena.STAGES
DUMMY_FLOOR = 0.25  # the least share of bouts against a still dummy: at 0.1 its aim on a still target slipped (93% felled, then 80%, 81%) while
                    # it learned to fight moving ones (2026-11-11): practice keeps the skill


class MaskedGodotEnv(StableBaselinesGodotEnv):
    """The Godot environment, telling MaskablePPO which choices can be made: the last numbers of every observation are the mask (HandBrain.mask)."""

    def _check_order(self):
        order = list(self.envs[0].action_spaces[0].keys())
        assert order == [h for h, _ in HEADS], "the heads come in another order than HEADS: %s" % order

    def _keep(self, obs):
        self._masks = np.asarray(obs["obs"])[:, -MASK:] > 0.5
        return obs

    def reset(self):
        self._check_order()
        return self._keep(super().reset())

    def step(self, action):
        obs, rewards, dones, infos = super().step(action)
        return self._keep(obs), rewards, dones, infos

    def env_method(self, method_name=None, *args, indices=None, **kwargs):
        if method_name == "action_masks":
            return list(self._masks)
        raise NotImplementedError(method_name)

    def get_attr(self, attr_name, indices=None):
        if attr_name == "action_masks":
            return [None] * self.num_envs
        return super().get_attr(attr_name, indices)


class Tally(BaseCallback):
    """The round's reward and its bouts, for the progress log."""

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


def counts_of(infos):
    """What every learner counted of its bouts (TacticsAgent.get_info), added up."""
    out = {}
    for i in infos:
        if isinstance(i, dict):
            for key in ("outlived", "deaths", "points_won", "points_lost", "draws", "hits", "casts"):
                out[key] = out.get(key, 0) + int(i.get(key, 0))
            for key, n in i.items():  # ("cast Frostbolt": how often each spell was cast, HandAgent.get_info)
                if isinstance(key, str) and key.startswith("cast "):
                    out[key] = out.get(key, 0) + int(n)
    return out


def bouts_of(infos):
    """Bouts won and lost: by a fall, or (a bout that ran its time) on points."""
    c = counts_of(infos)
    return c.get("outlived", 0) + c.get("points_won", 0), c.get("deaths", 0) + c.get("points_lost", 0)


def make_env(args, seed, opponent, dummy_share=0.0, near=0.0, opponent_stage=0):
    return MaskedGodotEnv(env_path="godot", n_parallel=args.envs, port=args.port, show_window=False, speedup=8, action_repeat=12, framerate=60,
                          world_seed=seed, lanes=args.lanes, stage=args.stage, pool=OUT.replace("\\", "/"), opponent=opponent, dummy_share=dummy_share, near=near,
                          opponent_stage=opponent_stage)


def curriculum():
    """Where the stage stands, from the last measure (kept in curriculum.json, so a restart keeps it): the share of training bouts against a dummy
    that stands still (half at first, falling as it learns to fell the dummy: a still target is the first step of aiming, a moving one the next),
    and how much a near miss still pays (HandAgent: all of it at first, none once a quarter of its shots hit the dummy)."""
    path = os.path.join(OUT, "curriculum.json")
    data = json.load(open(path)) if os.path.exists(path) else {}
    if STAGE > 1:  # (it aims already: a little dummy practice to keep it, no near misses; it refines once it beats the champion, see main)
        return data.get("dummy_share", DUMMY_FLOOR), data.get("near", 0.0), data.get("refine", False)
    return data.get("dummy_share", 0.5), data.get("near", 1.0), data.get("refine", False)


def export(model, path):
    """The policy network as JSON for scripts/policy_net.gd (kind "entity", see training/entity_net.py), its heads named as HandBrain names them."""
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(export_dict(model.policy, HEADS), f)
    os.replace(tmp, path)  # (the arena may be reading the pool: a file is there whole or not at all)


def settle(model, refine):
    """The learning rate and the pull toward trying everything for where the stage stands (see REFINE_FROM)."""
    rate = REFINE_RATE if refine else LEARNING_RATE
    model.learning_rate = rate
    model.lr_schedule = lambda _: rate
    model.ent_coef = REFINE_ENT if refine else ENT_COEF
    model.n_epochs = N_EPOCHS


def spell_order():
    """Senses.SPELL_ORDER, read from scripts/senses.gd: where each spell's choice lies in the cast head."""
    text = open(os.path.join(os.path.dirname(here), "scripts", "senses.gd"), encoding="utf-8").read()
    body = re.search(r"const SPELL_ORDER := \[(.*?)\]", text, re.S).group(1)
    return re.findall(r'"([^"]+)"', body)


def warm_start(model):
    """The spells this stage adds start as likely as Fireball's choice, times NEW_SPELL_SHARE, at the moments it would throw one (their rows of the
    last layer copied from Fireball's): a network that was never allowed them left them where chance put them, and would seldom try them."""
    order = spell_order()
    cast_at = sum(n for name, n in HEADS[:[h for h, _ in HEADS].index("cast")])
    net = model.policy.action_net
    fire = cast_at + 1 + order.index("Ignite")
    with torch.no_grad():
        for spell in STAGE_SPELLS[STAGE]:
            row = cast_at + 1 + order.index(spell)
            net.weight[row] = net.weight[fire]
            net.bias[row] = net.bias[fire] + math.log(NEW_SPELL_SHARE)


def last_round():
    rounds = [int(m.group(1)) for p in glob.glob(os.path.join(OUT, "round_*.zip")) if (m := re.search(r"round_(\d+)\.zip$", p))]
    return max(rounds) if rounds else 0


def log(line):
    stamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(os.path.join(OUT, "progress.log"), "a", encoding="utf-8") as f:
        f.write("%s %s\n" % (stamp, line))
    print(stamp, line, flush=True)


def measure(model, args, seed, opponent, opponent_stage=0):
    """Bouts won and lost against one opponent, playing as it would in a game (choices drawn by weight, impossible ones masked), learning nothing."""
    env = make_env(args, seed, opponent, opponent_stage=opponent_stage)
    obs = env.reset()
    decisions = 0
    infos = []
    while decisions < EVAL_DECISIONS:
        action, _ = model.predict(obs, deterministic=False, action_masks=get_action_masks(env))
        obs, rewards, dones, step_infos = env.step(action)
        decisions += len(rewards)
        infos = list(step_infos) or infos
    env.close()
    return counts_of(infos)


def main():
    global OUT
    torch.set_num_threads(int(os.environ.get("TRAIN_THREADS", "2")))
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", type=int, default=1)
    parser.add_argument("--out", default=OUT)
    parser.add_argument("--envs", type=int, default=5)
    parser.add_argument("--lanes", type=int, default=4)
    parser.add_argument("--port", type=int, default=11400)
    parser.add_argument("--round-steps", type=int, default=20480)
    parser.add_argument("--rounds", type=int, default=100000)
    parser.add_argument("--from", dest="start_from", default="", help="the last stage's network (round_N.zip) to begin a new stage with")
    args = parser.parse_args()
    global STAGE
    STAGE = args.stage
    OUT = os.path.abspath(args.out)
    os.makedirs(OUT, exist_ok=True)
    start = last_round()
    champion = os.path.join(OUT, "champion.json").replace("\\", "/")
    if start == 0 and args.start_from:  # (a new stage: the last one's network, kept here, is the pool's first opponent and the champion to beat)
        shutil.copyfile(args.start_from, os.path.join(OUT, "champion.zip"))
        shutil.copyfile(args.start_from[:-4] + ".json", champion)
        shutil.copyfile(args.start_from[:-4] + ".json", os.path.join(OUT, "round_0.json"))
    model = None
    for k in range(start + 1, start + 1 + args.rounds):
        if os.path.exists(os.path.join(OUT, "STOP")):
            log("stopped (STOP)")
            return
        seed = random.Random(k).randrange(0, 1000)
        share, near, refine = curriculum()
        env = make_env(args, seed, "pool", share, near)
        if model is None:
            previous = os.path.join(OUT, "round_%d.zip" % start)
            if start > 0 and os.path.exists(previous):
                model = MaskablePPO.load(previous, env=env, device="cpu", custom_objects={"learning_rate": LEARNING_RATE, "lr_schedule": lambda _: LEARNING_RATE})
            elif os.path.exists(os.path.join(OUT, "champion.zip")):
                model = MaskablePPO.load(os.path.join(OUT, "champion.zip"), env=env, device="cpu", custom_objects={"learning_rate": LEARNING_RATE, "lr_schedule": lambda _: LEARNING_RATE})
                warm_start(model)
                log("stage %d begins from %s, the new spells %s as likely as Fireball times %.2f" % (STAGE, args.start_from, STAGE_SPELLS[STAGE], NEW_SPELL_SHARE))
            else:
                assert env.observation_space["obs"].shape[0] == ENTITY_SIZE, "the senses are %d numbers, the network reads %d" % (
                    env.observation_space["obs"].shape[0], ENTITY_SIZE)
                model = MaskablePPO("MultiInputPolicy", env, n_steps=512, batch_size=512, n_epochs=N_EPOCHS, learning_rate=LEARNING_RATE, ent_coef=ENT_COEF, gamma=0.99,
                                    policy_kwargs=dict(features_extractor_class=EntityExtractor, net_arch=dict(pi=[256], vf=[256])), verbose=0, device="cpu")
                export(model, os.path.join(OUT, "round_0.json"))  # (the pool's first opponent: the untrained network, as random as the learner)
        else:
            model.set_env(env)
        settle(model, refine)
        tally = Tally()
        began = time.time()
        model.learn(total_timesteps=args.round_steps, callback=tally, reset_num_timesteps=False)
        env.close()
        model.save(os.path.join(OUT, "round_%d.zip" % k))
        export(model, os.path.join(OUT, "round_%d.json" % k))
        won, lost = bouts_of(tally.infos)
        log("round %d: reward per decision %.4f, %d decisions in %.0f s, steps %d, against the pool won %d lost %d (%s)" % (
            k, tally.total / max(tally.n, 1), tally.n, time.time() - began, model.num_timesteps, won, lost,
            ("%.2f" % (won / (won + lost))) if won + lost else "-"))
        if k % EVAL_EVERY == 0:
            began = time.time()
            shares = {}
            earlier = max(0, k // 2)
            spells_used = {}
            against = [("dummy", "dummy", 0), ("turret", "turret", 0)]
            if STAGE > 1:
                against.append(("champion", champion, STAGE - 1))
            against.append(("round %d" % earlier, os.path.join(OUT, "round_%d.json" % earlier).replace("\\", "/"), 0))
            for name, opponent, opponent_stage in against:
                c = measure(model, args, seed, opponent, opponent_stage)
                for key, n in c.items():
                    if key.startswith("cast "):
                        spells_used[key[5:]] = spells_used.get(key[5:], 0) + n
                if name == "dummy":  # (a dummy is beaten only by felling it: one that is only scratched in the time "wins on points")
                    won = c.get("outlived", 0)
                    lost = c.get("deaths", 0) + c.get("points_won", 0) + c.get("points_lost", 0) + c.get("draws", 0)
                else:
                    won = c.get("outlived", 0) + c.get("points_won", 0)
                    lost = c.get("deaths", 0) + c.get("points_lost", 0)
                shares[name] = (won, lost, won / (won + lost) if won + lost else 0.0, c.get("hits", 0), c.get("casts", 0))
            marks = dict(PASS, champion=CHAMPION_PASS) if STAGE > 1 else PASS
            passed = all(shares[name][2] >= mark for name, mark in marks.items())
            hit_share = shares["dummy"][3] / max(shares["dummy"][4], 1)
            refined = refine or (shares["champion"][2] >= REFINE_FROM if STAGE > 1 else hit_share >= REFINE_FROM)
            json.dump({"dummy_share": round(max(DUMMY_FLOOR, 0.5 * (1.0 - shares["dummy"][2])), 3), "near": round(max(0.0, 1.0 - hit_share / 0.25), 3),
                       "refine": refined}, open(os.path.join(OUT, "curriculum.json"), "w"))
            log("measure after round %d (%.0f s): %s, cast %s%s" % (k, time.time() - began, ", ".join(
                "%s won %d lost %d (%.2f), hit %d of %d casts" % (n, w, l, s, h, c) for n, (w, l, s, h, c) in shares.items()),
                ", ".join("%s %d" % (spell, n) for spell, n in sorted(spells_used.items(), key=lambda kv: -kv[1])),
                "  STAGE %d PASSED" % args.stage if passed else ""))


if __name__ == "__main__":
    main()
