"""Starts a training world and takes random actions, to see that the game and the trainer talk, and how fast it goes."""
import sys, time
import numpy as np
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

import gd_launch  # noqa: starts the project's own scene, see gd_launch.py
n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
env = StableBaselinesGodotEnv(env_path="godot", n_parallel=1, port=11008, show_window=False, speedup=1, action_repeat=6, framerate=60)
print("observation space", env.observation_space, "action space", env.action_space, "agents", env.num_envs)
obs = env.reset()
t = time.time(); total = 0.0; dones = 0
for i in range(n):
    actions = np.array([env.action_space.sample() for _ in range(env.num_envs)])
    obs, rew, done, info = env.step(actions)
    total += float(np.sum(rew)); dones += int(np.sum(done))
print("steps", n, "agents", env.num_envs, "total reward %.2f" % total, "dones", dones, "seconds %.1f" % (time.time() - t), "decisions/s %.0f" % (n * env.num_envs / (time.time() - t)))
env.close()
