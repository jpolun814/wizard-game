# PvP arena: the direction (2026-10-28)

The game is no longer a solo roguelite against a boss. It is a last-wizard-standing race for pages. This replaces the boss and the
single-run loop in `docs/roguelite_exploration_design.md`; the spells, the world generator and the pages stay.

## The game

- Four wizards, all the same: no schools, the same health, the same everything. Only the look differs (the player's, and the three
  of `dark_wizard`, `bone_wizard` and `pyre_wizard`). The player is one of the four; real players take over from the AI wizards when
  multiplayer exists. At least 2 and at most 4 wizards.
- Everyone starts with a few pages (one attack, one move, one defence and the two chants of the bonfire and the rift). The rest are
  scattered over the map. Everyone races to collect them and attacks the others.
- Last wizard standing wins. There is no boss fight. A wizard at 0 stamina is out for the round, and may watch one still alive.

## Built

- `Ledger` (`scripts/ledger.gd`): the pages one wizard holds. The player's is `player.ledger`. The waiting room's ledger holds every
  page (`Ledger.complete()`).
- `Pages.deal(seed, wizards)`: each wizard's starting pages, from the seed. Starting attacks and defences differ between wizards, so
  no one else can find that page on the map; the three moves repeat for the fourth wizard.
- `Pages.plan(graph, rng, dealt)`: lays every page that no wizard started with. `World.ledgers` holds the four ledgers.
- Tests: `tests/test_pages.gd`, and the `pages` scenario of `tests/showcase.tscn`.
- The cut-scene (`scenes/intro.tscn`, `scripts/intro.gd`), played when the lab's portal is entered, before the loading screen. Four wizards
  (the player's and the looks of `dark_wizard`, `bone_wizard` and `pyre_wizard`) run to a pile of pages in the cathedral hall; in the
  scuffle every page but one each wizard keeps is knocked through the portal; then they run in after them. Any key skips it. It ends
  with the `finished` signal and a change to `scenes/loading.tscn`. Tests: `tests/intro_check.tscn`, `tests/flow_check.tscn`.

- AI wizards that walk the world for pages and fight each other. `WorldBuilder.shut(world)` is the world with every gate shut; `Walkways`
  (`scripts/world/walkways.gd`) is the one set of rules for where a wizard can stand and the moves between (walk, step, fall, jump), shared by
  the generator's reachability test and the wizards. `WorldNav` is a path finder over it, kept to the tiles that can be left as well as
  come to (no pit with no way out). `WizardRoute` follows a path: when to jump, how fast, when it is stuck. `WizardBrain` chooses
  what to go for (the nearest page by the way it must walk, else the nearest wizard), fights when a rival is in sight and near, and casts
  only what its ledger holds. All four wizards have the player's own body (a capsule), health and stamina rules. The AI cannot get past a
  gate (a chasm, a wall of ice and so on), so a page behind one is not for it. A rival's stamina and spells show only under Insight.
- Tests: `tests/test_nav.gd`, `tests/route_check.tscn` (each kind of move, tried in the real physics), `tests/arena_sim.tscn` (AI-only
  matches).

- The collapsing worlds (`scripts/match_state.gd`, `World._watch_portal` and `_collapse`). A match is four worlds: 1200 tiles wide for 3 minutes,
  800 for 2, 560 for 1, then a last open one 360 wide with no caves, no castle and no gates that does not collapse. Six seconds before a world
  gives way the screen shakes and the banner reads "The portal is growing unstable"; then it fades out, the loading screen shows the next
  world's incantation, and the next world is built from a seed of its own (`MatchState.seed_for`). Each wizard keeps their ledger and their
  stamina; every page no one holds is laid again in the new world (`Pages.plan` skips what a ledger holds); a wizard already beaten is not
  brought back; the wizards land at the new world's starting places, which are far apart (a small world with too few ways down starts the rest
  on open ground). `WorldGraph.size` is the width to build; `WorldGraph.build_open` and `SurfaceGen.open` make the last world.
  Tests: `tests/test_stages.gd` (the smaller worlds), `tests/collapse_check.tscn` (a whole match, with the time shortened by `MatchState.hurry`).
  Not yet: the next world is built after the fade rather than in the background during the stage, so the loading screen shows for a few seconds.
- **Spectating.** A player who falls while rivals live is out for the round: the match and its collapses go on, the hidden body follows a living
  wizard (`World._follow_watched`), a click picks the next, and the player stays out in later worlds (`World._stay_out`). The game-over screen
  comes only when no rival is left. Test: `tests/spectate_check.tscn` (add `-- collapse` to follow it into the next world).

- **AI wizards clear gates.** When no page is to be had, a wizard goes to the nearest gate that a spell it holds can clear (`WizardBrain.CLEARS`: Ignite or Fire Breath for
  thorns, gas and ice, Stonefall or Earthquake for a wall and for ice), steps up to what is left of it and strikes until it is gone. `World._watch_gates` sees ice, wall, thorns or gas
  go (a thicket or a bank at a time), marks the gate open and builds the ways again (`WorldNav.version` tells the wizards to think again about the pages they gave up). A human who
  clears a gate opens it for the AI too. Chasms, floods, piranhas, the dark stretch and sentinels are not cleared by the AI yet: it treats them as walls. Test: `tests/gate_check.tscn`.
- **No boss left in the code.** `WorldGraph` has no boss hall, guard or boss lock (`deepest` is just the farthest hall); every locked area may hold a page and a Rift may land anywhere open.

## Planned

1. Balance the AI wizards by running AI-only matches headless (see `tests/arena_sim.gd`). They share one set of stats; only skill differs. A first tally of 11 final-world
   fights (stage 3, three AIs, the player standing down) gave the dark wizard 6 wins, the bone wizard 5, the pyre wizard 1; starting places are not the same, so look at that again
   with more seeds. Teach them to get past the other gates (chasm, flood, piranhas, dark, sentinel).
