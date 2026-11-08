"""Trains the learned footwork by playing: PPO (stable-baselines3) over Godot RL Agents, the AI wizards of a world as the agents (see wizard_agent.gd for what they
sense and are rewarded for). Runs at low priority, headless.

    python training/train_ppo.py [steps] [world_seed]      # saves training/ppo_footwork.zip every so often
"""
import sys, os, json
import numpy as np
from stable_baselines3.common.vec_env import VecEnvWrapper
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.callbacks import BaseCallback
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

import gd_launch  # noqa: starts the project's own scene, see gd_launch.py

steps = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 3
here = os.path.dirname(os.path.abspath(__file__))
class HumanLike(VecEnvWrapper):
    """Adds to each reward a little for every move a copy of the owner (human_policy.json, from clone_human.py) would likely have made, so that the learner
    is drawn toward how a person moves and not only toward the hand-made reward."""
    def __init__(self, venv, weight):
        super().__init__(venv)
        data = json.load(open(os.path.join(here, "human_policy.json")))
        self.layers = [(np.array(l["w"], dtype=np.float32), np.array(l["b"], dtype=np.float32)) for l in data["layers"]]
        self.weight = weight
        self.last = None
        self.acts = None

    def _logp(self, obs, acts):
        x = obs[:, :self.layers[0][0].shape[1]]
        for i, (w, b) in enumerate(self.layers):
            x = x @ w.T + b
            if i < len(self.layers) - 1:
                x = np.maximum(x, 0.0)
        def logsoft(z):
            z = z - z.max(axis=1, keepdims=True)
            return z - np.log(np.exp(z).sum(axis=1, keepdims=True))
        lm, lj = logsoft(x[:, :3]), logsoft(x[:, 3:])
        idx = np.arange(len(acts))
        return lm[idx, acts[:, 1]] + lj[idx, acts[:, 0]]  # (the trainer orders the choices jump, move) + np.log(6.0)  # (above doing a thing at random)

    def reset(self):
        self.last = self.venv.reset()
        return self.last

    def step_async(self, actions):
        self.acts = np.array(actions).reshape(len(actions), -1).astype(np.int64)
        self.venv.step_async(actions)

    def step_wait(self):
        obs, rew, done, info = self.venv.step_wait()
        if self.last is not None and self.acts is not None and self.acts.shape[1] == 2:
            rew = rew + self.weight * self._logp(np.asarray(self.last["obs"], dtype=np.float32), self.acts)
        self.last = obs
        return obs, rew, done, info


class Rewards(BaseCallback):
    """Prints the average reward a decision earned over each stretch of play, since a godot-rl world has no episodes of its own to report."""
    def __init__(self):
        super().__init__()
        self.total = 0.0
        self.n = 0

    def _on_step(self):
        self.total += float(sum(self.locals["rewards"]))
        self.n += len(self.locals["rewards"])
        if self.n >= 7 * 256:
            print("REWARD per decision %.4f over %d decisions (step %d)" % (self.total / self.n, self.n, self.num_timesteps), flush=True)
            self.total = 0.0
            self.n = 0
        return True


env = StableBaselinesGodotEnv(env_path="godot", n_parallel=1, port=int(sys.argv[3]) if len(sys.argv) > 3 else 11009, show_window=False, speedup=8, action_repeat=6, framerate=60, world_seed=seed)
human = float(os.environ.get("HUMAN_WEIGHT", "0"))
if human > 0:
    env = HumanLike(env, human)
model = PPO("MultiInputPolicy", env, n_steps=256, batch_size=128, learning_rate=3e-4, ent_coef=0.01, verbose=1, device="cpu")
model.learn(total_timesteps=steps, callback=[Rewards(), CheckpointCallback(save_freq=5000, save_path=os.path.join(here, "ckpt"), name_prefix=(sys.argv[4] if len(sys.argv) > 4 else "ppo"))])
model.save(os.path.join(here, sys.argv[4] if len(sys.argv) > 4 else "ppo_footwork"))
env.close()
