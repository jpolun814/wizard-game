# 15. SOLVED (2026-11-06): `net_match_check` timed out with eight wizards

**It was the test, not the game.** When the host is the last wizard standing in what the game counts as a real match (`Library.real_match()`, true because the
scene is no longer under `res://tests/`), `World._count_wizards` shows the winner's stats screen and `_epilogue_when_stats_are_away` holds the ending until
someone puts it away. Nobody is there in the check, so the match never ended and both copies waited for their timers (619 s to 1216 s runs).

Found by: a 120 s limit after the brains were struck plus a diagnostic of who was alive (only the host: so the match should have ended), then reading the win logic in `scripts/world.gd` (`_count_wizards`).
Not the cause (cleared by running with the original files): the pond and liquid-flow threading. Fix: the host in `tests/net_match_check.gd` hides any `StatsScreen` while it waits
for the waiting room. The check now takes about 60 s, and gives up after 300 s (`GIVE_UP`), and 120 s after the brains are struck.

Lesson: a check that waits for a timer is slow to fail. Give each wait its own short limit and print a line saying what it waited for.
