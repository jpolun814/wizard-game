# 16. Open work

What the owner has asked for or decided that is not built yet, and what is known to be wrong. Everything finished has been taken out of this list; the history
is in git. Any player-facing line follows section 0 of `CLAUDE.md`, and no new spell is built without the owner approving the idea first.

## Waiting on the owner

- **Stand-in art:** the small shots of Barbs, Pebble, Hailstorm and Insect Plague (`art/fx/thorn.png`, `pebble.png`, `hailstone.png`, `insect.png`, drawn by
  `tools/make_shot_art.py`) and the Leech tether (soft round beads) are not a final look.
- **Push's line** ("Blast out a rush of air that shoves everything in its path.") waits for the owner's words.
- **More attacking spells** (about 60% of spells able to do damage was the aim): on hold. Propose ideas as `CLAUDE.md` section 6 says; build only what the owner picks.

## Bugs and known failures

- **A page out of sync in a network game.** Not reproduced for ordinary pages. The lead is the Mirage: each machine spawns its own, with a node name of its own, so a
  read found by name (`_page_read`) cannot find it on the other machine. Fix idea: the host decides when it shimmers out and in and sends it by name, and a spawned
  Mirage gets the same name everywhere (the caster's name and a count).
- **`test_world` (full set):** on seeds 7, 15 and 23 the rooms next to the start of a 1200-wide world with halls cannot be reached. It fails the same way at the start of
  2026-11-12, before that day's work; not looked into.
- **`tutorial_ai_check` (full set):** the AI wizard is held up at the tutorial's giant.
- **Intermittent:** `brain_spells_check` now and then fails one spell (Tornado reaching the rival's ledge, Mirage, Faint) and passes on the second try;
  `net_spells_check`'s "the one on the tether pays the other half" under full-set load.
- **The opening cut-scene** shows ten wizards (`scripts/intro.gd`, `WIZARDS` and `EXTRAS`); a match has eight.

## Easing in new players (settings, not modes)

The owner prefers settings to easy and hard modes. Built: Rival skill (Easy, Normal, Hard) on the Settings page. Not built: the number of wizards (2 to 8; the host's
choice in a network game; `WorldGraph.PLAYERS` is a constant used widely), a small list of the spells held with their shapes (a non-diegetic aid), faster regeneration
for the person, fewer worlds or a slower collapse, one extra starting page. A "which spell now?" drill in the tutorial could come later.

## Competitive play and ranks (owner, 2026-11-06)

- **Custom and competitive matches,** as in Rocket League: a custom match lets every setting be changed; a competitive one uses one fixed set (eight wizards, standard
  rival skill, no aids, standard regeneration and collapse), the same for everyone, and only it counts toward rank. It needs a choice on the first screen and in the
  host's lobby, the settings sent to every machine, and `Library` recording the match type.
- **Ranks:** a title of two parts, a tier (the Wizard101 levels, such as Novice, Master and Grandmaster; confirm the list with the owner) and the school favoured, as
  in "Grandmaster Pyromancer". The owner's answers: the favoured school counts **casts that hit** only; the rating rises on a good result and falls on a bad one
  (an Elo summed over every pair of wizards by finishing place, or a Glicko or TrueSkill style rating, so new players move fast at first); the tier, not the number, is
  shown; AI wizards wear made-up titles for show and never touch the rating. Clients are trusted, so a rating is only fair among friends: say so, build no anti-cheat.
  Order: the custom and competitive split first, then the rating and tier, then the school.

## The server (owner, 2026-11-06)

- **Decided:** no Steam for now. Friends off the home network will join a dedicated server on a cloud machine (AWS) by address, which the game already does.
- **Built:** a dedicated server with trusted clients (`-- --server`, `tools/run_server.bat` and `tools/run_client.bat`; `11_network_play.md`).
- **Not tried:** the "Windows Dedicated Server" export preset (`export_presets.cfg`, `build/WizardServer.exe`): this computer has no export templates. When it is
  exported, run it with `--headless -- --server`, and make whatever needs art or sound to exist cope (the `Warmup` autoload loads pictures and sounds at start-up).
  A Linux preset for AWS comes after.
- **The big step:** the server as referee, running the one true simulation while clients send only their inputs. It touches every spell, the AI and the liquids, so it
  goes in parts (damage, deaths, page reading and the result first). Ranks only count once this is done.
