"""Trains the learned footwork by playing: PPO (stable-baselines3) over Godot RL Agents, the AI wizards of a world as the agents (see wizard_agent.gd for what they
sense and are rewarded for). Runs at low priority, headless.

    python training/train_ppo.py [steps] [world_seed]      # saves training/ppo_footwork.zip every so often
"""
import sys, os
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.callbacks import BaseCallback
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

import gd_launch  # noqa: starts the project's own scene, see gd_launch.py

steps = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 3
here = os.path.dirname(os.path.abspath(__file__))
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
model = PPO("MultiInputPolicy", env, n_steps=256, batch_size=128, learning_rate=3e-4, ent_coef=0.01, verbose=1, device="cpu")
model.learn(total_timesteps=steps, callback=[Rewards(), CheckpointCallback(save_freq=5000, save_path=os.path.join(here, "ckpt"), name_prefix="ppo")])
model.save(os.path.join(here, "ppo_footwork"))
env.close()
