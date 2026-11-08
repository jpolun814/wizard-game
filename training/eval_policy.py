"""Measures a trained footwork policy against the scripted legs in the same world: reward per decision, deaths, pages read, jumps.

    python training/eval_policy.py MODEL.zip [decisions] [world_seed] [port]     # MODEL "scripted" plays the scripted legs
"""
import sys, os
import numpy as np
from stable_baselines3 import PPO
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

import gd_launch  # noqa

model_path = sys.argv[1]
n = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
seed = int(sys.argv[3]) if len(sys.argv) > 3 else 3
port = int(sys.argv[4]) if len(sys.argv) > 4 else 11020
extra = {"scripted": ""} if model_path == "scripted" else {}
env = StableBaselinesGodotEnv(env_path="godot", n_parallel=1, port=port, show_window=False, speedup=8, action_repeat=6, framerate=60, world_seed=seed, **extra)
model = None if model_path == "scripted" else PPO.load(model_path, device="cpu")
obs = env.reset()
total = 0.0; deaths = 0; count = 0; last = None
for i in range(n):
    if model is None:
        actions = np.array([env.action_space.sample() for _ in range(env.num_envs)])
    else:
        actions, _ = model.predict(obs, deterministic=True)
    obs, rew, done, info = env.step(actions)
    total += float(np.sum(rew)); count += len(rew); deaths += int(np.sum(done)); last = info
pages = sum(i.get("pages", 0) for i in last); jumps = sum(i.get("jumps", 0) for i in last)
print("RESULT %s: reward per decision %.4f  deaths %d  pages %d  jumps %d  (%d decisions, %d wizards)" % (model_path, total / count, deaths, pages, jumps, n, env.num_envs))
env.close()
