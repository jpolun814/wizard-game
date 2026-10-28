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

## Planned

1. The opening cut-scene: the four wizards grab at a pile of pages, and in the scuffle all but the starting pages are knocked into the
   portal and scattered over the map. The same scene whether the other wizards are AI or real. It plays before the loading screen.
2. AI wizards that seek pages and attack, balanced by running AI-only matches headless. Their three looks share one set of stats.
3. The portal grows unstable: after about 3 minutes the screen shakes and everyone is teleported into a newly generated, smaller
   world; then 2 minutes, then 1, then a final world with no caves. Every uncollected page is carried over; wizards land spread apart;
   shots, fires and walls are cleared. The next world should be generated in the background during the stage.
4. Watching a living wizard after death.
5. Delete what the boss loop left: the boss room and its lock in `WorldGraph`, the boss stash text in the old docs, the solo flow.
