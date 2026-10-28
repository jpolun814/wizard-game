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

## Planned

1. Balance the AI wizards by running AI-only matches headless (see `tests/arena_sim.gd`). They share one set of stats; only skill differs.
   Teach them to get past gates with the spells they hold.
2. The portal grows unstable: after about 3 minutes the screen shakes and everyone is teleported into a newly generated, smaller
   world; then 2 minutes, then 1, then a final world with no caves. Every uncollected page is carried over; wizards land spread apart;
   shots, fires and walls are cleared. The next world should be generated in the background during the stage.
3. Watching a living wizard after death.
4. Delete what the boss loop left: the boss room and its lock in `WorldGraph`, the boss stash text in the old docs, the solo flow.
