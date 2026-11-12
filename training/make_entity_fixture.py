"""Writes tests/fixtures/entity_net_fixture.json: a small entity network (training/entity_net.py) with random weights, some senses (lists full, empty
and part full), and the logits the trainer's own network gives for each. tests/entity_net_check.tscn runs the same network in GDScript
(scripts/policy_net.gd) and checks it gives the same logits.

    python -I training/make_entity_fixture.py
"""
import json
import os
import sys
from types import SimpleNamespace

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import torch
import torch.nn as nn
from gymnasium import spaces
import numpy as np
from entity_net import EntityExtractor, export_dict

torch.manual_seed(3)
LISTS = {"things": (10, 3, 5, 4), "rivals": (28, 2, 6, 5)}
SIZE = 44
ex = EntityExtractor(spaces.Dict({"obs": spaces.Box(-5, 5, (SIZE,))}), lists=LISTS, size=SIZE, encode=8, flat=12)
head = nn.Sequential(nn.Linear(ex.features_dim, 16), nn.Tanh())
action = nn.Linear(16, 7)
for p in list(ex.parameters()) + list(head.parameters()) + list(action.parameters()):
    nn.init.uniform_(p, -0.8, 0.8)
policy = SimpleNamespace(features_extractor=ex, mlp_extractor=SimpleNamespace(policy_net=head), action_net=action)
net = export_dict(policy, [("a", 3), ("b", 4)])

rng = np.random.default_rng(5)
samples = []
for k in range(6):
    x = rng.uniform(-1, 1, SIZE).astype(np.float32)
    x[rng.random(SIZE) < 0.4] = 0.0  # (zeros, as the senses have many)
    for name, (start, slots, width, present) in LISTS.items():
        for s in range(slots):
            held = (k + s) % 3 != 0 if k > 0 else False  # the first sample holds nothing in any list
            x[start + s * width + present] = 1.0 if held else 0.0
    with torch.no_grad():
        logits = action(head(ex({"obs": torch.from_numpy(x).unsqueeze(0)})))[0]
    samples.append({"obs": x.tolist(), "logits": logits.numpy().tolist()})

out = os.path.join(os.path.dirname(here), "tests", "fixtures", "entity_net_fixture.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump({"net": net, "samples": samples}, open(out, "w"))
print("wrote", out)
