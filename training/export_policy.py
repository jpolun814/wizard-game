"""Writes a trained PPO footwork policy as JSON for the game to run (scripts/policy_net.gd): the layers of its policy network, a tanh between them."""
import sys, json
from stable_baselines3 import PPO

model = PPO.load(sys.argv[1], device="cpu")
net = model.policy
layers = []
for name in ("mlp_extractor.policy_net.0", "mlp_extractor.policy_net.2", "action_net"):
    module = net
    for part in name.split("."):
        module = getattr(module, part) if not part.isdigit() else module[int(part)]
    layers.append({"w": module.weight.detach().numpy().tolist(), "b": module.bias.detach().numpy().tolist()})
out = sys.argv[2] if len(sys.argv) > 2 else "ppo_policy.json"
json.dump({"activation": "tanh", "sample": True, "layers": layers, "outputs": {"move": [0, 3], "jump": [3, 5]}}, open(out, "w"))
print("wrote", out, [len(l["b"]) for l in layers])
