"""Starts the game for Godot RL Agents the way this project needs: godot-rl splits its start command at spaces (this project's path has them) and wants an
exported program. Importing this makes it start the project's own training scene with the Godot console program instead, at low priority."""
import os, subprocess
from godot_rl.core.godot_env import GodotEnv

GODOT = os.environ.get("GODOT_EXE", r"C:\Users\Jordan Polun\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
PROJECT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BELOW_NORMAL = 0x00004000  # (Windows) a process that gives way to the games a person is playing


def _check_platform(self, filename):
    pass


def _launch_env(self, env_path, port, show_window, framerate, seed, action_repeat, speedup, **kwargs):
    cmd = [GODOT, "--path", PROJECT, "res://training/wizard_env.tscn"]
    if show_window is False:
        cmd += ["--disable-render-loop", "--headless"]
    if framerate is not None:
        cmd += ["--fixed-fps", str(framerate)]
    cmd += [f"--port={port}", f"--env_seed={seed}", f"--world_seed={kwargs.pop('world_seed', seed)}"]
    if action_repeat is not None:
        cmd += [f"--action_repeat={action_repeat}"]
    if speedup is not None:
        cmd += [f"--speedup={speedup}"]
    for key, value in kwargs.items():
        cmd += [f"--{key}={value}"]
    self.proc = subprocess.Popen(cmd, creationflags=BELOW_NORMAL)


GodotEnv.check_platform = _check_platform
GodotEnv._launch_env = _launch_env
