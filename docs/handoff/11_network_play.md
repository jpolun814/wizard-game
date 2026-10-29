# 11. Network play (built; read this before touching anything that a second machine must see)

Friends play together over a network: one hosts, the others join by address. It is built on Godot's own high-level multiplayer
(`ENetMultiplayerPeer` on the SceneTree's `MultiplayerAPI`, `MultiplayerSynchronizer`, `@rpc`). Nothing hand-rolls packets.

## What the owner decided (2026-10-29)

- Connect over the same home network, or over the internet by typing the host's IP (the host forwards UDP port `24565`). A relay
  (Steam and the like) may come later; nothing here stops it.
- One player hosts, and the host's game is the referee for the shared things (pages, the collapse, gates, the end of the match).
- Brains (AI wizards) fill the seats nobody takes, up to four.
- A Host / Join screen, then everyone shares the waiting room and walks into the portal; the match starts when the last person has.
- Friends only for now: each machine is trusted to read its own person's strokes and to say what happened to its own wizard.
- Rejoining can wait. Esc opens the menu but the world goes on.

## How it fits together

| Piece | Where | What it does |
|---|---|---|
| `Net` autoload | `scripts/net.gd` | host / join / leave, the roster (people in seat order, the host first), which scene each machine is in, `Net.send(node, method, args)` (an rpc to every machine in the same scene) |
| First screen | `scenes/menu.tscn`, `scripts/menu.gd` | the main scene: Play alone, Host a game, Join (address box, remembered in `user://settings.cfg`) |
| A wizard on another machine | `scripts/wizard.gd` (`share`, `is_person`, `is_likeness`, `_follow`, `_tell_others`) | a *likeness*: the same `Wizard` scene with a `MultiplayerSynchronizer` added, driven by the machine that owns it |
| Casting | `arena.cast_by` -> `_spawn_everywhere` / `_spawn_seen` | the driving machine pays for the spell, then every machine spawns the same spell from the same origin with the same random seed |
| Waiting room | `scripts/lab.gd` (`_meet_people`, `_stepped_in`, `_go`) | likenesses of everyone, the host's address in the title, the portal waits for every person |
| A match | `scripts/world.gd` (`_my_seat`, `_places`, `_spawn_wizards`, `_watch_falls`, `_begin_collapse`, `_gates_cleared`, `_back_to_room`) | seats, brains on the host, pages, books of the fallen, the collapse, gates, the end |

**Who drives what.** Every wizard has a multiplayer authority: a person's wizard is driven by that person's machine; a brain's by the
host. Only the driving machine moves the wizard and changes its stamina, status and death. On the other machines the same node is a
likeness: `take_damage`, `push`, `pull`, `apply_debuff`, `faint`, `heal`, `drain`, `pay_max`, `stick_in_ground` and
`gain_temp_stamina` do nothing there, and `has_shield`, `is_frozen` and `lava_proof` read the synced `marks`. So a spell can safely run
on every machine: each one hurts only the wizards it drives, and the synchronizer shows the result everywhere. Playing alone, the tree
has Godot's `OfflineMultiplayerPeer`, this machine is peer 1 and the authority over everything, and every one of those checks is a
no-op.

**What is synced** (`Wizard.share`): `net_position` (a likeness glides to it, or snaps past `SNAP` px), velocity, facing, stamina,
max stamina, Offering stamina, the cast colour and the casting pose every frame; death, fainting, the animation, the stroke being
drawn (`shown_stroke`, thinned to points 8 px apart), `marks`, visibility and modulate when they change. Hurt flashes, "Interrupted!"
and chants are one-off rpcs (`_show_hurt`, `_show_interrupt`, `_show_chant`).

**Names are paths.** Godot finds a node on another machine by its path, so every shared node has a name that is the same everywhere:
`Wizard<peer id>` for a person's, `Rival<seat>` for a brain's, `Page<k>` for a page laid from the seed, `Spoils<wizard>` for a fallen
wizard's book, `Gate<g>_<k>` for a piece of a gate. Anything new that must be shared needs a name like these, set before it is
added or right after.

**Scenes.** Each machine says which scene it is in (`Net.enter_scene`: `lab`, `world0`, `world1`...); synchronizers have a
visibility filter (`Net.is_here`) and `Net.send` only calls machines in the same scene, so nothing is sent to a machine that does not
have the nodes yet. A machine says it is leaving (`_leave_network_scene`) as its screen fades, before the scene is freed.

**The host decides:** who reads a page (`read_page` -> `_ask_to_read` -> `_page_read`), when a wizard has fallen and drops its book
(`_watch_falls`), when the collapse begins (`_begin_collapse`), which gate pieces are gone (`_gates_cleared`), and when the match is
over (`_back_to_room`, ten seconds after one wizard is left). Everything that follows from the seed (the world, the pages, who holds
what, where each seat starts) every machine works out for itself.

**Seats.** A person's seat is their place in `Net.roster`; seats are 0 to 3 and give the look (`Net.LOOKS`: hooded, dark, pyre,
bone), the ledger and the starting place. Someone who leaves mid-match leaves a 0 in their seat (their wizard falls and drops its
book); the waiting room closes the gaps. Playing alone, the player is seat 0 and nothing changed.

## Testing (both tests run two copies of the game on this computer, talking over 127.0.0.1)

```
"$GODOT" --headless --path . tests/net_check.tscn -- role=host &        # then:
"$GODOT" --headless --path . tests/net_check.tscn -- role=client        # the waiting room: see each other walk, a fireball each way, leaving
"$GODOT" --headless --path . tests/net_match_check.tscn -- role=host &  # then:
"$GODOT" --headless --path . tests/net_match_check.tscn -- role=client  # a whole match: portal, cut-scene, world, a page, a gate, the collapse, a fall, back to the room
```
`tests/net_crowd_check.tscn` runs three copies (`role=host`, then `role=first`, then `role=second`, a second apart): a spell from one
guest to the other, through the host. Add `leave` to both copies of the match test for the one who joined to leave mid-match; add `out=DIR` and drop `--headless` for
pictures from both sides. **Never pass `--fixed-fps` to these:** a headless copy with a fixed frame rate runs faster than the clock,
so its waits end before the other copy has answered. The waiting-room test with `out=` moves the real mouse pointer.

## Known limits (tell the owner; fix when asked)

- **Tested only on one computer, over localhost.** Two machines on a home network and the internet are untested. The first time a
  copy hosts, Windows asks whether to let it through the firewall: allow it on private networks.
- **Hazards and gates run on every machine.** Sentinels, piranhas, thorns, gas and spells' own objects (stone walls, trees, ice) are
  simulated by each machine for itself, so in a close call they can disagree for a moment. Gates follow the host's (a piece gone there
  is removed everywhere), but a piece gone on a client and not on the host stays gone on that client only.
- **The waiting room's dummies and turret are each machine's own;** the turret shoots at whoever is on that screen.
- **Hits are decided by the one who is hit.** A fireball that hits a likeness on your screen but missed on its owner's did nothing.
  This is the friendly choice (nobody is hit by something they dodged on their own screen); strangers would need the host to decide.
- **R (reset the room) does nothing in a network game,** and F1's summons are only on your own machine.
- **Joining once a match has begun is refused** (the joiner sees "Check the address and try again.").
