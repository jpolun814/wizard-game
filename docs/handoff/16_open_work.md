# 16. Open work

What the owner has asked for or decided that is not built yet, and what is known to be wrong. Everything finished has been taken out of this list; the history
is in git. Any player-facing line follows section 0 of `CLAUDE.md`, and no new spell is built without the owner approving the idea first.

## Waiting on the owner

- **More attacking spells** (about 60% of spells able to do damage was the aim): on hold. Propose ideas as `CLAUDE.md` section 6 says; build only what the owner picks.

## Bugs and known failures

- **`test_world` (full set):** on seeds 7, 15 and 23 the rooms next to the start of a 1200-wide world with halls cannot be reached. It fails the same way at the start of
  2026-11-12, before that day's work; not looked into.
- **`tutorial_ai_check` (a long run by hand, in neither set):** the AI wizard now puts the giant to sleep and goes on (a gate it had already cleared was chosen again and again), but stops at the first pond of piranhas, column 22. It stands at the edge with a Frost Bridge cast and does not cross; the likely cause is `BrainDanger.in_shoal` still seeing the bridged water as bitten, so `follow_route` waits. It takes about 1100 seconds of the match to run the tutorial through, which is why it is not in a set.
- **`brain_spells_check`, by the dice** (2026-11-16): a brain's dice are now drawn from the global ones (`WizardBrain`: `rng.seed = randi()`), so `-- dice=N` brings a failure back
  exactly. Hunter's Mark (the rival was put over a gap and fell out of the world) and Mirage (the real page it needs was out of its sight) failed because of the scenes, and are fixed.
  Not fixed: Push (about half the dice), Tornado and Spore Puff (now and then) never get up to the rival's ledge, or never cast, in the 60 seconds. The wizard is in fight
  mode (`BrainCombat.footwork`) and runs at the rival under the ledge without leaping or lifting; the "page" in its status is only its last journey, not the cause. The run
  that `python tools/run_checks.py` makes is `dice=0`, which fails all three: try `-- only=Push dice=0`.
- **Intermittent:** `net_spells_check`'s "the one on the tether pays the other half" under full-set load.

## Easing in new players (settings, not modes)

The owner prefers settings to easy and hard modes. Built: Rival skill (Easy, Normal, Hard) on the Settings page. The owner (2026-11-16) turned down the ideas
proposed so far (a smaller wizard count, a list of the spells held with their shapes, and the like): ask before building any aid.

## Competitive play and ranks (owner, 2026-11-06)

- **Custom and competitive matches,** as in Rocket League: a custom match lets every setting be changed; a competitive one uses one fixed set (eight wizards, standard
  rival skill, no aids, standard regeneration and collapse), the same for everyone, and only it counts toward rank. It needs a choice on the first screen and in the
  host's lobby, the settings sent to every machine, and `Library` recording the match type.
- **Ranks:** a tier only, from the Wizard101 levels (Novice, Master, Grandmaster and so on; confirm the list with the owner). There is no favored school (owner, 2026-11-16: "just
  grandmaster, not grandmaster pyromancer"). The rating rises on a good result and falls on a bad one (an Elo summed over every pair of wizards by finishing place, or a Glicko or
  TrueSkill style rating, so new players move fast at first); the tier, not the number, is shown; AI wizards wear made-up titles for show and never touch the rating. Clients are
  trusted, so a rating is only fair among friends: say so, build no anti-cheat. Order: the custom and competitive split first, then the rating and tier.

## The server (owner, 2026-11-06)

- **Decided:** no Steam for now. Friends off the home network will join a dedicated server on a cloud machine (AWS) by address, which the game already does.
- **Built:** a dedicated server with trusted clients (`-- --server`, `tools/run_server.bat` and `tools/run_client.bat`; `11_network_play.md`).
- **Not tried:** the "Windows Dedicated Server" export preset (`export_presets.cfg`, `build/WizardServer.exe`): this computer has no export templates. When it is
  exported, run it with `--headless -- --server`, and make whatever needs art or sound to exist cope (the `Warmup` autoload loads pictures and sounds at start-up).
  A Linux preset for AWS comes after.
- **The big step:** the server as referee, running the one true simulation while clients send only their inputs. It touches every spell, the AI and the liquids, so it
  goes in parts (damage, deaths, page reading and the result first). Ranks only count once this is done.
