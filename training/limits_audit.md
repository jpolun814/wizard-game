# Audit of human limits (2026-11-09, before any limit was built)

Default view: 1280x720, stretch canvas_items, aspect expand; Camera2D zoom 1.5, offset (0,-150), smoothing 7 -> about 853x480 world px, centred 150 px above the feet.

| # | Limit | Status | Evidence / what is missing |
|---|---|---|---|
| 1 | Typing blocks draw/move/jump | partly | brain _act (347-368), _tend (371), _hurdle (295) still run while typing (break the chant rather than blocked). Scrying Eye chant instant (324). |
| 2 | Drawing blocks typing; one stroke | partly | _begin_cast (2132) has no is_drawing guard; a planned _react can overwrite a stroke mid-draw. |
| 3 | Stroke drawn on screen, dragged by camera | not | strokes built in world space, injected by Caster.cast_stroke after a timer (wizard.gd 1123-1130). |
| 4 | Shake / hand wobble | partly | _shaken on every brain stroke; _handed only on attacks, with 4-10% deliberate botches (remove: owner says no made-up mistakes). |
| 5 | Limited sight | mostly not | _sight_is_limited only gates pages; page sight 620x380 with no wall/smoke/dark check; _nearest_foe any range through walls; _feel_strength reads rival max_stamina and page count; attack scoring reads foe status; _incoming_shot/_track_shots see all shots; _real_page_near knows unseen pages; ENGAGE 620 wider than screen. |
| 6 | Sneak | bug | Wizard.is_unseen() = is_faded() and not in group "player" (wizard.gd:703): brains always see the host's person through Sneak. No Hex exception. |
| 7 | Decoy | not | brain never considers decoys. |
| 8 | Mirage | partly | believed until one is seen fading within 700 px; then all skipped. |
| 9 | Reaction / attention | partly | _reaction_time lerp(0.4,0.15,skill)+0..0.12; no attention limit. |
| 10 | Chords staggered | not | mask set at once. |
| 11 | No drawing off screen | not | attacks up to 460 px sideways, Spark gate strikes 40 tiles. |
| 12 | New-page reading time | not | Ledger.knows_spell is pages.has. |
| 13 | Knows who is human | obeyed | wizard.human never read (except the Sneak leak). |
| 14 | Cursor speed | n/a | stroke over fixed draw_time (owner: current speed is fine). |

Training: wizard_env.gd swaps in LearnedBrain + WizardAgent, ACTION_REPEAT 6 (~10 decisions/s); actions move L/stand/R + jump only; obs 249 = Sensing 236 (self 7, 11x9 grid x2, 3 pages <900 px, 2 rivals <900 px with stamina, 4 threats <500 px) + 13 route. No sight checks in Sensing (rivals filtered only by visible; pages include mirages). Reward: route progress, pages, hurt, death, jump cost.
