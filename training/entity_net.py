"""The network that reads what a hand-played wizard senses (HandBrain.observe) the way the big game AIs read theirs (OpenAI Five, AlphaStar): each list
of like things (the things on the screen, the other wizards) goes through a small encoder of its own, the same for every slot, and is pooled (the
most of each feature, and the mean, over the slots that hold something), so it reads "a shot coming at me" wherever in the list the shot is; the
rest (itself, the ground, the book, the words, the mask...) goes through a layer of its own. The parts are joined and passed on to the policy and
value heads (Stable-Baselines3's mlp_extractor).

One flat network over all 4,783 numbers was slow to find the few that matter (the other wizard is two of them): it learned to aim, and stalled at
dodging (stage 1, 2026-11-11).

scripts/policy_net.gd runs the same network in the game, from the JSON that export() writes; tests/entity_net_check.tscn checks the two agree.
"""
import torch
import torch.nn as nn
from stable_baselines3.common.torch_layers import BaseFeaturesExtractor

# Where the lists lie in HandBrain.observe() (Senses layout 3): (first number, slots, numbers a slot, the place in a slot that is 1 when it holds something).
# HandBrain checks a loaded network's spans against Senses (Senses.list_spans), so a change of layout cannot pass unnoticed.
LISTS = {
    "things": (2652, 24, 23, 19),
    "rivals": (3204, 7, 49, 16),
}
SIZE = 4814  # HandBrain.SIZE: the senses (4,662) and the mask (152)
ENCODE = 64   # what each slot is encoded into
FLAT = 256    # what the rest is encoded into


class EntityExtractor(BaseFeaturesExtractor):
    def __init__(self, observation_space, lists=None, size=SIZE, encode=ENCODE, flat=FLAT):
        self.lists = dict(lists or LISTS)
        self.size = size
        out = flat + len(self.lists) * encode * 2
        super().__init__(observation_space, features_dim=out)
        taken = sorted((start, start + slots * width) for start, slots, width, _ in self.lists.values())
        self.ranges, at = [], 0
        for start, end in taken:
            if start > at:
                self.ranges.append((at, start))
            at = end
        if at < size:
            self.ranges.append((at, size))
        flat_in = sum(b - a for a, b in self.ranges)
        self.flat = nn.Sequential(nn.Linear(flat_in, flat), nn.Tanh())
        self.encoders = nn.ModuleDict({name: nn.Sequential(nn.Linear(width, encode), nn.Tanh(), nn.Linear(encode, encode), nn.Tanh())
                                       for name, (_, _, width, _) in self.lists.items()})

    def forward(self, observations):
        x = observations["obs"] if isinstance(observations, dict) else observations
        parts = [self.flat(torch.cat([x[:, a:b] for a, b in self.ranges], dim=1))]
        for name, (start, slots, width, present) in self.lists.items():
            slab = x[:, start:start + slots * width].reshape(-1, slots, width)
            held = (slab[:, :, present] > 0.5).unsqueeze(-1)              # (batch, slots, 1)
            enc = self.encoders[name](slab)                              # (batch, slots, encode)
            biggest = torch.where(held, enc, torch.full_like(enc, -2.0)).max(dim=1).values
            biggest = torch.where(held.any(dim=1), biggest, torch.zeros_like(biggest))  # (nothing held: zeros)
            mean = (enc * held).sum(dim=1) / held.sum(dim=1).clamp(min=1)
            parts += [biggest, mean]
        return torch.cat(parts, dim=1)


def _dense(module):
    return {"w": module.weight.detach().cpu().numpy().tolist(), "b": module.bias.detach().cpu().numpy().tolist()}


def export_dict(policy, heads):
    """The policy (an EntityExtractor and SB3's policy head) as the JSON scripts/policy_net.gd runs: kind "entity"."""
    ex = policy.features_extractor
    lists = []
    for name, (start, slots, width, present) in ex.lists.items():
        enc = ex.encoders[name]
        lists.append({"name": name, "from": start, "slots": slots, "width": width, "present": present, "layers": [_dense(enc[0]), _dense(enc[2])]})
    head = [_dense(m) for m in policy.mlp_extractor.policy_net if isinstance(m, nn.Linear)] + [_dense(policy.action_net)]
    outputs, at = {}, 0
    for name, n in heads:
        outputs[name] = [at, at + n]
        at += n
    return {"kind": "entity", "activation": "tanh", "sample": True, "inputs": ex.size, "flat": {"ranges": [list(r) for r in ex.ranges],
            "layer": _dense(ex.flat[0])}, "lists": lists, "head": head, "outputs": outputs}
