# Read this first, every session

This is a Godot game built by one owner through many sessions. This file is the complete handoff for every agent that
works on it. It holds everything you need: the owner's wording rules in section 0 (the number one priority), the game,
the rules, the codebase, the testing and the known problems. Chapter files for particular jobs are in `docs/handoff/`;
chapter 11 (network play) is the newest work.

# HANDOFF: read this before you touch anything

This is the guide for any AI model picking up this game. It tells you what the game is, what the owner wants, how
the code fits together, and the mistakes that have already been made, so you don't make them again.
`docs/original_vision.md` is the first design document. It is older than the game: use it for intent, but
trust the code and this file where they disagree.

**Read this file first, then the chapter for the job in hand** (`docs/handoff/`):

| Chapter | Read it before you... |
|---|---|
| `01_feedback_log.md` | do anything at all: every request the owner made, quoted, and the lesson behind it |
| `02_codebase_map.md` | change code: every script, the scene tree, coordinates, physics layers |
| `03_gestures_and_spell_design.md` | add or change a spell or gesture: how recognition works, design rules, school identities, vetted ideas |
| `04_art_and_assets.md` | add or change anything visible: style rules, every source, how to judge and process an asset |
| `05_audio.md` | touch sound: sources, layering, choosing sounds you can't hear |
| `06_enemies_and_ai.md` | touch enemies or the dark wizard |
| `07_testing.md` | say anything is done |
| `08_working_with_the_owner.md` | reply to the owner |
| `09_godot_pitfalls.md` | debug something strange |
| `11_network_play.md` | touch anything a second machine must see: wizards, spells, pages, gates, the match (done: host and join over a network) |

---

## 0. Player-facing words: THE NUMBER ONE PRIORITY

**Read this section before writing, changing or reviewing any text a player can read.** It covers spell
descriptions, spellbook pages, rituals, incantation names, tooltips, banners, prompts and button labels.
Mistakes here have been the owner's most repeated complaint, and they are the easiest to make. Every line
must pass every test below. A line that fails one test is not finished, however correct it looks.

### The principle

The game's text is a page in a world where magic is real. A reader in that world learns about a spell the
way they would learn about a plant, a storm or a tool: what it is, what it brings about, and how it looks.
The page never talks about the game. It has no numbers, no rules, no tips on how to use the spell, and no
description of the system behind it.

The player discovers a spell's strengths, weaknesses, counters, side effects and quirks by casting it and
watching. The page does not hand them over. Withholding those things is deliberate. It is the point.

### First, decide who is speaking and who is addressed

Before any other check, answer two questions about the line: **who is speaking**, and **who is being spoken to**.
The standard terms: text that exists inside the story world is **diegetic**; text outside it (interface, prompts)
is **non-diegetic**. The one spoken to is the **addressee**. A text with a narrator inside it speaks to a
**narratee**. Use these two questions and these words in review; do not invent others.

**Diegetic: the world speaks to the wizard (the character).**
- Where: the spellbook pages, spell names, chant names and incantations, mob descriptions, the names of pages.
- The speaker is the world, or a scholar who wrote the tome. The addressee is the wizard, who is a person in a
  world where magic is real and the game does not exist.
- So: no key names, no buttons, no "player", no "spell" as a game object, no stamina bar, no numbers, no
  rules and no tips. Read it as lore. "Hurl a bolt of fire." is a wizard reading about magic.
- Verbs fit the thing named (a shadow is moved, not walked). The pronoun "this" points at the act the reader is
  performing; "it" points at the nearest noun.

**Non-diegetic: the game speaks to the human holding the controller.**
- Where: the pause screen, the controls list, key prompts ("Press Tab to read"), the loading screen, banners and
  the like.
- The speaker is the game. The addressee is the human. These lines may name keys and mouse buttons and may use
  plain words such as "pause", "page" and "world".
- They still follow the rest of this section: imperative, short, no numbers, no rules, no tips.

**Mixed text is the third case.** Floating words over a wizard ("Too tired", "Perfect"), the Insight tooltip and
the chant failure lines sit between the two. Decide for each which side it is on and write it that way. If a
single line seems to need both audiences, split it: the world part goes in the book, the key part goes in a prompt.

**Most wording mistakes are a line written for one audience that landed in the other**: a key name in a spellbook
page, or a piece of lore ("Walk your shadow") in a controls list. When a line feels off and no test says why,
re-ask the two questions first.

**A missing line is also a mistake.** If the player has done something and nothing in the world or the interface
tells them what happened or what to do next, add the shortest non-diegetic line that fixes it, or a visible cue
in the world. "On-screen text is a last resort" below says when that is allowed.

**More patterns the owner has taught (apply them to every line):**
- **The place decides the audience.** The waiting room is outside the story, so its lines are plain prompts
  addressed to the human ("Walk into the portal to start the game"). The spellbook is inside it.
- **A diegetic line says what the thing is, not how to use it.** "Gain deeper knowledge of those around you" is
  right for Insight. "Look at a creature to learn what it is" is a how-to and is wrong.
- **Never rely on sound alone.** A player may have the sound off. Any outcome the player cannot otherwise see (a
  shape that matches nothing, a chant that fizzles) gets one short word on screen.
- **One name for one thing, everywhere.** The bar and the tooltip both say "Stamina", for wizards and mobs alike.
  Do not rename a thing between screens.
- **The controls list holds only controls that always apply.** Leave out keys that matter only sometimes (a spell's
  own control), and never say the same thing in both columns of a row.
- **Intuitive actions need no text.** If the world already shows how to do something (grab a vine), say nothing.
  Where a first-time player would be lost (the waiting room's portal), give one short prompt.

### On-screen text is a last resort

Words appear on screen only when the player could not learn the same thing from what the game already shows them.
This is the rule for all on-screen text, not just spellbook pages. Apply it before any of the seven tests.

- **Show it, don't say it.** If sight, sound or motion already tells the player something, add no words.
  A blinded player is in the dark: no "Blinded!" line. A rooted player cannot move: no "Rooted!" line. A minimap
  that appears is its own confirmation: no "Minimap revealed" line. A shot that fizzles still gets the one word "Misfire", because a player may have the sound off.
  A stroke that is too short needs no "Stroke too short" line.
- **Say it only when it is hidden.** Words are for information the player has no other way to get: a key they
  must press, a state they cannot perceive, or an outcome they could not otherwise work out. A refused chant
  whose words were wrong is hidden, so it gets a line. A chant that fails with no visible result gets a line.
- **Keep what the game means to show.** Information the design deliberately gives the player (the accuracy of a
  chant, the stats Insight reveals) is part of the design. It stays, and it is not "text to cut".
- **Even then, keep it short and imperative**, and pass the seven tests below.

### The seven tests (apply all of them to every line)

**Test 1: Is it said to the reader, in the imperative?**
Every line starts with a verb addressed to the reader: "Hurl a bolt of fire.", "Kindle a bonfire and heal
your wounds.", "Press Tab to open the spellbook." Lines that describe the system fail, even when they are
grammatical: "Tab opens the spellbook." "Fire does 12 damage." "Speed is increased." A reader is a person
doing something, not an observer of a machine.

**Test 2: Does it name the thing, rather than its effect on other things?**
Say what the spell *is*, or what it brings about. Do not say what it does to whatever it touches.
- Fails: "Slow anything in the snow." (a rule about targets)
- Passes: "Cast a powerful snowstorm that slows people down." (the storm itself)
- Passes: "Sprout thorny brambles from the ground." (names the thing growing; the thorns' damage is left to discover)
- Passes: "Open a black hole that pulls everything toward it." (the hole is the thing)
A quick check: would the line still make sense if the spell had no effect at all on anything? If the line
collapses without its effect, it is describing the rule, not the spell.

**Test 3: Are there no numbers?**
No counts, durations, percentages, multipliers, distances, costs or damage figures. Not "for 10 seconds",
not "50% more damage", not "1.6 times faster", not "6 damage each", not "two hits". Words such as "a little
while" and "for a while" are fine; they are how a person speaks. The owner's example of what not to write:
"move 1.6 times faster, allowing you to run past poison clouds without losing all max stamina". The right
version is "Run faster." or "Surge with speed for a little while."

**Test 4: Is there no meta information?**
Meta information is anything about the game rather than the world: how to use a spell, when to use it, what
counters it, what it combines with, how it interacts with the stamina bar, the cost, the maximum, the
mechanics. Fails: "to draw attacks", "in the direction you draw", "costs no stamina", "lowers your maximum",
"spent last", "walk slower", "the caster is spared" (state it as the spell's own effect instead, or leave it).
Passes: "Burst a ring of blood outward, throwing back everything near you." A wizard in the world would know
that from the spell itself.

**Test 5: Is it written for a world where the spell is knowledge, not a weapon?**
Most spells are things scholars have recorded: a storm, a bloom of thorns, a shadow, a wall. Their lines
describe what they are and what they do in the world. Combat-manual language fails: "deal damage to foes",
"stun the target", "counter enemy attacks", "aggro", "tank". Write as a lore book would, not as a game guide.

**Test 6: Are team words absent?**
Spells in this game have no sides. Never write "foes", "enemies", "allies", "rivals", "your team" or
"opponents". Use "anyone", "anything", "whoever", "everything" or "the target". A shot cannot hit only the
enemy, so the text must not imply it can.

**Test 7: Would a real person say it, and would it be understood on first reading?**
Read the line aloud as a sentence someone might actually speak. Fails: "Quicken your feet." (nobody says this),
"Hold your breath for a while, even under water." (the phrase "even under water" implies water was not
included, so the reader doubts the claim), "Offering" (a label, not an action).
Passes: "Run faster for a while." "Hold your breath for a while." "Give blood now, and draw on its strength once
the rest is spent." (confirmed by the owner). Pronouns must be clear: "Knock the target
unconscious", not "Knock whoever is under it unconscious" (the reader cannot tell what "it" means).

### Vocabulary that works

- Use **conjure** for a summoned thing ("Conjure a shadow of yourself.", "Conjure an erupting volcano.").
- Use **kindle** for fire ("Kindle a bonfire.").
- Use **burst** for a blast ("Burst a ring of blood outward.").
- Use **freeze** for ice ("Freeze the surface of a body of water.").
- Use **sprout**, **grow**, **raise**, **summon** for things that come up out of the world.
- Use **negate** rather than **catch**, **absorb** or **block** when a spell stops harm ("Wrap yourself in a veil
  of blood that negates the next few blows.").
- Use **a little while** or **for a while** instead of a number.
- Use **the target** or **anyone** instead of **it**, **whoever** or **them** when the referent is unclear.

### The owner's standing corrections (each one is a rule)

- "Burst" lines: "everything near you", not "everything near". The reader needs to know whose surroundings.
- Decoy: "Conjure a shadow of yourself." Not "to draw attacks", which explains why and how to use it.
- Faint: "Knock the target unconscious." Not "Draw the strength out of whoever is under it".
- Frost Bridge: "Freeze the surface of a body of water." Not "Freeze the water into a bridge of ice".
- Great Oak: "Grow a great oak." Not "that comes crashing down". The falling is what happens; it is for the player to see.
- Gust: "Blow a gust of wind." Not "in the direction you draw".
- Hex: "Curse someone with a dark star: they take extra damage and cannot hide from you." The owner suggested this.
- Ice Prison: "Freeze things in a block of solid ice." Not "Lock anything inside the circle".
- Crimson Veil: "negates", not "catches".
- Volcano: "Conjure an erupting volcano." Not "Erupt a volcano that spits lava".
- Black Hole (formerly Abyss): name it Black Hole, and describe it as a black hole, not as a "knot of darkness".
- Eclipse: the owner's described effect (the world goes dark around the player, with a dim ring) is a mechanic
  (built: `Eclipse` darkens the watcher's screen), not a line to write yet. Do not describe the mechanic on the page.
- Rituals: "Tear open a way to a random place. This can be devastating." (the owner dropped the "Warning:" label). "Gain deeper knowledge of those around you."
  "Never tire for a while." "Jump again in mid-air for a while." "Hold your breath for a while."
  "Open a long-lasting portal back to your mark." "Mark this place." "Show the land around you."
- Bonfire: "Kindle a bonfire and heal your wounds." (confirmed by the owner). ("Wounds" is the
  in-world word for what costs maximum stamina.)

### The spellbook is a canon tome

Decided by the owner: the spellbook is an in-world tome only. It holds the spell's name, its drawn picture, and
one short line of what it is. It has no manual, no cost line, no counters, no numbers and no how-to. The reader
learns the rest by casting. Do not add anything that makes the book a game guide, even if it would help a player.

### What to do before you ship a line of text

1. Write the line.
2. Run all seven tests, in order, and say aloud which one it passes or fails.
3. If it fails any test, rewrite it. Do not argue for it.
4. Show the owner the full set of lines you changed, not just the one that prompted the change. The owner has
   asked for the whole list to be shown every time, so the complete picture is visible.
5. Do not present a line as final until the owner has confirmed it. Unconfirmed lines are drafts.

### Known mistakes to avoid repeating

- Picking a verb by analogy to a person or animal instead of by what the thing is. "Walk your decoy" sounds like
  walking a dog; "Move your decoy around" fits a shadow. Ask what the object is, then use the plain verb for that.
- Using "it" when the line is about the action the reader is performing. Say "this" ("This can be devastating."),
  so the pronoun points at the act and not at the noun before it.

- Writing grammatically correct lines that nobody would actually say.
- Keeping numbers "because they are short".
- Explaining the mechanic ("Lowers your maximum", "costs no stamina") instead of the thing.
- Adding a combat slant to a spell whose lore is about the world.
- Writing "foes" or "enemies" out of habit.
- Explaining a line's purpose in the line ("to draw attacks").
- Treating one correction as applying only to the spell it was about, rather than to every line with the same fault.

## 1. What the game is

A 2D side-view last-wizard-standing duel built in Godot 4.7.2 and GDScript. You are a wizard, and you cast spells by
**actually doing magic**:

- **Fast spells:** hold a school's mouse button(s) and draw a shape. The shape is read by a $1 recognizer
  plus hand-written shape detectors.
- **Rituals:** press Enter and type a pseudo-Latin chant. Typing accuracy sets the ritual's power.

A match: four identical wizards (you and three AI wizards, or friends over a network with AI wizards in the empty seats) race through a generated world for spellbook pages and fight each other. The last one standing wins. The AI wizards cast the same
spells you do, drawing them visibly. There are no waves and no boss (see `docs/pvp_arena_design.md`).

**The owner's taste, in their words:**
- "sick as hell"
- "not a fan of the cartoony style"
- "that dark wizard was a lot of fun"

**The look:** dark gothic pixel art.
- **Biomes** (the look of each place):
  - a blood-moon graveyard.
  - a jungle (rain, great trees with vines hanging from them), snowy peaks and ashlands (embers and lava over dark basalt).
  - a castle (the whole world is castles side by side, with gothic church interiors, doorways tall enough for a giant, and a giant roaming the ground floors) and the underground (a great cavern under a roof of rock, no sky).
  - **Living scenery** (`World._raise_biome_life`, `docs/handoff/02_codebase_map.md`): the graveyard has low mist (`MistBank`), bats (`CritterFlock`) and crypts (`Crypt`, each with a page and a skeleton guard); the jungle has rope bridges between neighbouring great trees (`CanopyBridge`), light shafts, fireflies, swaying vines, birds that burst away and downpours (`Squall`); the peaks have avalanches (`Avalanche`), sheets of ice that make a wizard slide (`IceSheet`) and an aurora; the ashlands have lava lakes that swell (`LavaSurge`), ash storms with falling embers (`EmberRain`) and volcanoes that spit before they erupt; the underground has glowing crystals, drips, stalactites that fall on whoever walks under (`FallingRock`) and cave-ins (`CaveLife`). Storms, avalanches, swells and cave-ins follow the world's age, so every machine of a match sees them at the same time. Run `tests/showcase.tscn -- scenario=life` with `WORLD_SEED` (0 jungle, 1 graveyard, 4 mountains, 5 ashlands, 13 underground).
  - Each world of a match is one of these six, in an order the seed picks; the last, small world is all open sky, one of the first four.
  - **Each biome has landmarks of its own, not just a reskin; only the underground has tunnels.** The graveyard is dark with rain and fog, and its skeletons roam
    (`Mob.roams`). The ashlands have volcanoes that erupt now and then (`Eruption`) and pits of lava. The snowy peaks are mountains to climb (`MountainGale`: wind that grows toward the summits and pushes a wizard without the run animation, seen as streaks; `SnowCloud`: clouds that drift past in front of whoever is in them), with a page on each
    summit. The jungle has pits of mud (`Mudslide`, dug by the world), thickets of thorns (`Bramble`) and great trees (`JungleTree`: dense, in three sizes and mirrored or not, each large one with the oak's ledges to hop between and a vine to climb to the high one, where most of the pages lie; the AI climbs the vines; the ponds are full of `Piranhas`). Its art is still named for the swamp it was cut from. The castle is a row of castles with five floors: a cellar down a
    stair, the ground floor, the first, and the second and third under the keep (see `docs/world_generation.md`).
- **Characters and art:** LuizMelo characters, Ansimuz GothicVania environments, and CC0 pixel effects.

## 2. The eleven rules that matter most

*Where a rule below concerns player-facing text and differs from section 0, section 0 wins. In particular, section 0
allows no numbers at all (not even damage), and the spellbook is a canon tome with no cost line.*

1. **Spells must reflect something real, and must be counterable.** Fire Nova (a magic ring blast) was removed
   because it "doesn't seem to reflect anything in real life and is impossible to block."
   - Every spell needs a real-world analogue: a flamethrower, a lightning strike, quicksand, a boulder.
   - Every spell needs a counterplay: block it, dodge it, or take cover.
   - Ground, stone walls, ice and platforms block things physically.
2. **The gesture is a picture of the effect.**
   - Volcano is a mountain triangle. Fire Breath is a cone (`<`). Mudslide is a U (the pit of mud).
   - Black Hole is an inward spiral. Blizzard is a star with a snow line.
   - Icicles are V shapes. Push is a circle (the area) plus a line out of it (the direction).
   - Never assign an arbitrary shape.
3. **No code-drawn pictures.** "All the other code-drawn pictures stick out like sore thumbs; they absolutely
   have to be replaced."
   - Everything in the world must be real pixel art from free assets.
   - The only exceptions are interface elements: health bars, the gesture trail, shadows, and pixel snowflakes
     or shards made of pixel squares.
   - Before adding `draw_circle`, `draw_line` or `draw_polygon` for a world object, look for an asset first.
4. **Pixel art at one consistent pixel size.**
   - 1 art pixel equals 1 world pixel. Camera zoom is 1.5. The texture filter is "Nearest Mipmap" (project setting `2`).
   - Only whole-number scales: 2x for the lightning, the tornado and the swamp/cathedral backdrops; 1x for characters.
   - Never use 0.6x, 1.5x or similar on pixel art.
   - Tiles are 16 px art composed 2x2 into 32 px world cells.
5. **Don't make things solid or harmful unless the spell's real-world analogue would be.**
   - Firewall: anyone can pass through it ("I wanted the fire wall to be something anyone could pass
	 through").
   - Barrier: only touches projectiles.
   - Black Hole: does no damage.
   - Stonefall: hits everyone beneath it, the caster included.
   - Lightning: cannot pass through platforms.
   - Stonefall: does not explode; it thuds.
6. **Consistency within a role.** All melee enemies look the same (skeletons). The owner disliked the earth
   melee enemy looking different. Schools are shown by a coloured outline and tint, not by different creatures.
7. **Never commit, push or delete the owner's files without being asked.**
   - Never run `git checkout .`,
     `git reset --hard` or `git clean`.
   - `art_source/enemies/` and `art/wizard_parts/` are the owner's original art, now unused. Keep them.
8. **Test before you claim.**
   - Run `tests/test_gestures.gd` and the showcase screenshots, and actually look at the screenshots.
   - Tell the owner what you could not verify (you cannot hear sounds or feel the controls).
9. **Keep text short in game.** The owner disliked wordy spellbook entries, repeated "costs no stamina",
   explaining edge cases, and filler headings like "Incantations, continued."
10. **Talk to the player, not about the game.** Every sentence of on-screen text is imperative and addressed to the player ("Press Tab to
	open the spellbook", "Gives you endless stamina"), never a statement about the system ("Tab opens the spellbook", "Snow slows everything under it"). A key
	and action table may use short verb-first labels. No ALL-CAPS result lines ("The ritual backfired", not "RITUAL BACKFIRED").
    **Spellbook entries** follow nine more rules (owner-confirmed):
	1. Start with a verb addressed to the player ("Hurl a bolt of fire").
    2. Say only what the spell does. Never name what counters it, what it combines with, or how to avoid it: the player learns those.
	3. Never mention self-harm ("you too"); it is implied.
	4. Never mention cost scaling or size ("a longer cone costs more").
	5. Write as a wizard inside the universe. No game-loop or meta words: wave, level, run, walkers, "to draw attacks", "as long as your stroke".
    6. Never mention interface actions such as double-clicking.
	7. Be accurate, and say "anyone" or "everything" where a spell has no teams.
    8. Keep it short; numbers only for damage and duration.
    9. Never describe the stroke: the animation shows it.
11. **Don't change what they didn't ask about.** When feedback names five things, fix those five, check
    nothing else broke, and report briefly.
12. **Describe what the thing does to the player, never the numbers behind it.** No multipliers, percentages or comparisons: never "1.6 times faster", "50% more damage", "half damage" or "walks slower". Write "Run faster." The only numbers allowed are damage and durations in seconds. Don't list side effects, weaknesses or interactions (what burns it, what it stops, what it combines with): the player learns those by playing. One effect per spell, in one short line.
13. **Name no team.** Spell and game text says "anyone", "anything" or "whoever", never "foes", "enemies", "allies" or "rivals" (spells have no teams, see section 5).

## 3. Run, test and look

```
GODOT="/c/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                          # after adding or changing any asset
"$GODOT" --headless --path . --quit-after 200                  # parse check: grep the output for "SCRIPT ERROR"
"$GODOT" --headless -s tests/test_gestures.gd                  # must print "470 of 470" (or more, if you add checks)
"$GODOT" --headless -s tests/test_pages.gd                     # the pages each wizard is dealt and a ledger's rules
"$GODOT" --headless --path . tests/intro_check.tscn            # the cut-scene (add `-- mode=skip`, or `-- out=DIR` for pictures, without --headless)
"$GODOT" --headless --path . tests/flow_check.tscn             # lab, portal, cut-scene, loading, world
"$GODOT" --headless -s tests/test_nav.gd -- seeds=6            # the wizards' map of the ways agrees with the generator's
"$GODOT" --headless -s tests/test_stages.gd -- seeds=6         # the smaller worlds a match collapses into: walkable, spread starts, every page placed
"$GODOT" --headless --fixed-fps 60 --path . tests/collapse_check.tscn  # a whole match through its collapses (time shortened)
"$GODOT" --headless --fixed-fps 60 --path . tests/gate_check.tscn -- seed=8 only=ice  # a wizard clears gates with spells (without only= it walks to them: minutes)
"$GODOT" --headless --fixed-fps 60 --path . tests/dark_check.tscn  # a wizard walks across a stretch of spike strips
"$GODOT" --headless --fixed-fps 60 --path . tests/spectate_check.tscn  # the player falls and watches a rival (add `-- collapse` to follow into the next world)
"$GODOT" --headless --fixed-fps 60 --path . tests/pull_check.tscn  # the portal tears open at the top and sucks the wizards in (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/spark_check.tscn  # Spark Strike lands on the ground under open sky
"$GODOT" --headless --fixed-fps 60 --path . tests/stairs_check.tscn  # a castle stair to the cellar is walked down and dropped through with S (stairs are hollow, and the only way between floors: no ladders, no doors)
"$GODOT" --headless --fixed-fps 60 --path . tests/parity_check.tscn  # Push, Geyser, Burst, Tornado, Tide Surf and a shot do the same to a person's wizard and the brain's
"$GODOT" --path . tests/eclipse_check.tscn  # an Eclipse darkens the screen of the one inside it (add `-- out=DIR` for pictures)
"$GODOT" --headless --fixed-fps 60 --path . tests/sentinel_check.tscn  # a sentinel shoots a rival wizard in range, not one out of range
"$GODOT" --headless --fixed-fps 60 --path . tests/cross_check.tscn -- seed=4 kind=flood spells=Frost%Bridge  # a wizard crosses a gate with a spell (kind=chasm, flood, piranhas, sentinel, wall or gas; spells=chant:deep_breath for a chant; no spells= and it stays put)
"$GODOT" --headless --fixed-fps 60 --path . tests/route_check.tscn -- seed=3 moves=500  # every kind of move works in real physics (`trace=X,Y,TX,TY` follows one)
"$GODOT" --headless --fixed-fps 60 --path . tests/arena_sim.tscn -- seed=7 seconds=300 report=60  # AI wizards alone in a world: pages read, who is beaten, where they were held up
"$GODOT" --path . tests/showcase.tscn -- scenario=spells out=C:/some/dir          # a screenshot of every spell
"$GODOT" --path . tests/showcase.tscn -- scenario=spells only=Fire_Breath out=DIR # one spell, frame by frame
"$GODOT" --headless --path . tests/showcase.tscn -- scenario=soak out=DIR  # random play; look for errors
"$GODOT" --headless --path . tests/net_check.tscn -- role=host &  then  ... -- role=client  # two copies in a shared waiting room (no --fixed-fps!)
"$GODOT" --headless --path . tests/net_match_check.tscn -- role=host &  then  ... -- role=client  # two copies play a whole match (add `leave` to both)
```

- **Other scenarios:** `world`, `kinds`, `ui` (portal, spellbook pages, pause, game over), `wizard` (a dark-wizard
  duel), `brawl`, and the other scenarios named at the top of `tests/showcase.gd`.
- **Screenshots need a window:** don't pass `--headless` for them.
- **Looking at screenshots:**
  - Open the PNGs with your image-reading tool.
  - To compare many, paste crops into one contact sheet with PIL.
  - Crop lower than you think: ground-level effects sit near the bottom.
- **Scripts run with `-s` cannot see autoloads (`Sfx`).** Anything that needs the game must run as a scene, which
  is why the showcase is a scene.
- **Python:** use `python -I` for anything that reads downloaded files. Install packages with
  `pip install --isolated --index-url https://pypi.org/simple <pkg>`.
- **Shell quirk:** in this environment, long bash heredocs containing apostrophes sometimes fail to parse. Write
  the Python edit script to a file in the scratchpad and run that.

## 4. Controls

| Key or button | Action |
|---|---|
| A / D | Move |
| W or Space | Jump |
| S | Drop through a wooden platform |
| Left mouse | Fire school |
| Right mouse | Water school |
| Middle mouse | Air school |
| Left + Right | Earth school |
| Left + Middle | Flora school |
| Right + Middle | Shadow school |
| Left + Right + Middle | Blood school |
| W at a vine | Take hold of a Liana; W and S climb, Space or a sideways key lets go |
| N / R (waiting room) | Night on and off / reset the room |
| Tab | Spellbook (arrow keys turn pages) |
| Enter | Incantation box |
| M | Mute |
| Esc | Pause and controls list (in a network game the world goes on) |
| F1 | Debug summon panel |
| R | New run, on the game-over screen |

## 5. Spells (the `Spell` resources in `res://spells/` are the single source of truth)

| School | Spell | Shape | Real thing | Counterplay |
|---|---|---|---|---|
| Fire | Ignite | straight flick | thrown fireball | dodge, Gust, walls |
| Fire | Firewall | vertical line | burning brush line | it's passable and only burns; walk out of it |
| Fire | Fire Breath | cone `<` | flamethrower from the mouth (follows facing, rises on a jump) | cover, Barrier, distance |
| Fire | Smoke Screen | wavy line going up | a bank of smoke enemies cannot see through | wind (Tornado, Gust), Tsunami |
| Fire | Flare | flame: a loop with its point up | a small harmless flame that follows you and lights the dark | it burns out |
| Fire | Spark | tall zigzag | a lightning strike from the sky; stops at the first platform or ground | shelter under a platform |
| Water | Frostbolt | flick | thrown ice spear | as Ignite |
| Water | Icicles | one or more Vs in a row, under a ceiling | icicles hanging from the ceiling | step around |
| Water | Ice Prison | circle | freezing whoever is inside solid | Push or Earth shatter; Barrier |
| Water | Blizzard | star then a level line | snow cloud | leave the area |
| Water | Frost Bridge | wavy line across water | freezing a pond so you can cross | fire melts it |
| Water | Geyser | mountain: a triangle with a line up its middle (as Volcano) | a jet of water that throws what stands on it | step off while it bubbles |
| Air | Push | circle then a line out | a shove of air; the only spell that lifts you | positioning |
| Air | Barrier | circle | a shield bubble | wait it out |
| Air | Tornado | tall narrow coil going down | a whirlwind | avoid it |
| Air | Gust | straight flick | wind along the stroke: turns shots, sweeps flyers, smoke and you sideways | heavy foes resist |
| Earth | Stonefall | circle with a line down | a dropped boulder | watch the shadow |
| Earth | Stone Wall | line starting on the ground, a platform or another stone wall | a raised slab | Earthquake, Stonefall, shots wear it down |
| Earth | Mudslide | U | a pit of mud: slows, no jumping; flyers pass over | walk out |
| Earth | Earthquake | three peaks | the ground shakes | flyers unaffected |
| Earth | Volcano | triangle mountain | eruption | stay out of the arc |
| Flora | Bramble | low sawtooth | a thicket of thorns: slows and pricks | jump it; fire |
| Flora | Spore Puff | cone `<` (as Fire Breath) | poison spores poured from your mouth | wind, water |
| Flora | Liana | leaf and line: an almond on its point, then a line up | a vine to climb | fire |
| Flora | Great Oak | trunk drawn up into a round crown | a tree: ledges and a wall, and when it falls it crushes | fire, Earthquake, Stonefall; it creaks first |
| Flora | Flytrap | tall narrow W | a trap that snaps shut on whoever steps in | jump, fire |
| Flora | Lily Pads | chain of low loops | floating leaves to cross water or a pit | fire; they sink after 8 s |
| Shadow | Decoy | figure of eight | a shadow that draws enemies' attacks | it wears out |
| Shadow | Eclipse | crescent | darkness: enemies inside see only what is close | Flare |
| Shadow | Hex | pentagram (five-point star, one stroke) | a curse: 50% more damage | short time |
| Shadow | Black Hole | inward spiral | a dark knot that pulls everything across the world toward it (walls still stop it) | walk out |
| Shadow | Shadow Step | flick | slipping along the stroke | |

**The spellbook is a canon tome only** (owner decision): in-world text and the drawn picture, no manual, no cost line. What a spell does, what counters it and how much it costs are learned in play. The table above is the first 32 spells. The other ten (the six Blood spells, Tide Surf, Obsidian Armor, Glowcap and Moonbeam) are in `spells/` and `docs/spell_pool.md`. The school and spell plan is in `docs/spell_pool.md`; the direction of the game (a last-wizard-standing page race, which replaced the
boss and the solo roguelite loop of `docs/roguelite_exploration_design.md`) is in `docs/pvp_arena_design.md`. The waiting room (`scenes/lab.tscn`, `scripts/lab.gd`) is where every spell is tried; the portal there
starts a run.

**Targeting types:** `directional`, `positional`, `angled`, `shape` and `cone`. The caster's `cast_resolved`
signal passes `info` (radius, line, rect, shapes, aim, spread, reach), and `arena.spawn_spell` routes it.
**No sides:** once a spell is cast it has no team. It hurts whoever it touches: enemies, the player, the dark
wizard, and the caster and its allies too (friendly fire). The one exception is a shot (Ignite, Frostbolt, an enemy's
bolt): it can't hit whoever fired it while it is still inside that body. Once it has flown clear, it can hit them, so
it hits them if it comes back. Blink and Fire Breath start on the caster's body, so the caster is passed by there as
well. `scripts/spells/spell_targets.gd` decides who can be hurt.

## 6. Designing a new spell: checklist

1. **Name the real-world thing.** If you can't, stop.
2. **Pick the school by what it is:**
   - Fire: heat, burning, lightning, light and smoke.
   - Water: cold, slowing, freezing, solid ice, dousing, floods.
   - Air: pushing, deflecting, shields and wind.
   - Earth: stone, ground, sand, weight.
   - Flora: plants: things that grow, hold and trap, and all burn.
   - Shadow: sight, decoys, curses and gravity.
3. **Draw what it looks like.** The stroke should be the thing's silhouette or its motion.
4. **Make sure the shape is distinguishable from every other shape on the same button(s).** The recognizer
   only compares within the held button combination. Add a test case to `tests/test_gestures.gd` and add the
   preview to `GestureTemplates.preview_points`. The dark wizard draws from those previews too.
5. **Physics honesty:** what blocks it, who it hurts (the caster too?), and whether it goes through platforms.
6. **Telegraph:** the enemy or player must see it coming. Examples: Stonefall's shadow, the falling-shot ring,
   the cloud's flicker.
7. **Art from a free pack,** recoloured to the school's colour in `tools/prepare_gothic_art.py`.
8. **A sound,** chosen with `tools/audio_profile.py` or mixed in `tools/make_sounds.py`. Say plainly that you
   couldn't listen to it.
9. **Teach the dark wizard to use it** (`scripts/wizard_brain.gd`): a score in `_attack` and a stroke in
   `_attack_stroke`.
10. **Spellbook:** the stats line comes from `SpellData.DAMAGE`. Keep it short.

## 7. Art: where it comes from and how it's built

- **The pipeline:** `tools/prepare_gothic_art.py <downloads dir>`. It builds `art/chars`, `art/mobs`,
  `art/tiles`, `art/props`, `art/backgrounds`, `art/fx`, `art/ui`, and generates `scripts/pixel_art.gd`
  (frame sizes and body boxes).
- **Folder names** the script expects are listed in its docstring.
- **Downloads are not kept in the repo.** Re-download them into a scratch folder.
- **Credits:** every source and licence is in `art/CREDITS.md`. Add a line for anything new.
- **Licences (owner decision, 2026-10-25):** CC0 and CC-BY are both fine, for everything. CC-BY needs a credit line in
  `art/CREDITS.md` (name the author and link the pack). Prefer CC0 when two assets fit equally. Still skip CC-BY-SA,
  GPL, "personal use only" and paid packs unless told otherwise.
- **Good sources:**
  - kenney.nl: everything is CC0. Its "Tiny Dungeon" and "1-Bit" packs suit the style.
  - opengameart.org: check the licence badge on each page.
  - itch.io: LuizMelo, Ansimuz and CodeManu have CC0 packs. Check the page's licence field.
    `tools/itch_download.py` fetches free pages.
- **Judging an asset:**
  - It must be dark, gothic and pixel art, at roughly the same pixel density as the characters.
  - No cartoon, vector or painterly art.
  - Look at it (make a contact sheet) before using it.
  - Check whether an "effect" sheet secretly contains a character. The GothicVania "fire-sprites" were a
    fire-casting wizard, not fire.
- **Recolouring:** `recolour()` does a hue turn or a dark-to-light ramp, and `key_out()` removes a flat
  background colour.
- **Character frames** are cut so the feet sit on the bottom edge and the body is centred, so flipping a frame
  never shifts the character.

## 8. Godot pitfalls that already bit

- **Never `load()` a texture inside `_draw()` into a local variable.** It gets freed before rendering and draws
  as a **white rectangle**. Use `preload()` constants or a cache.
- **`var x := dict["k"]` fails to parse** ("Cannot infer type"). Give it an explicit type.
- **`Parallax2D` vertical scroll:** use `scroll_scale.y = 1`, or layers drift off the ground line.
- **Raycasts and one-way platforms:** cast from above, downward, when testing "is it covered".
- **numpy on Windows:** `np.arange` is int32. Multiplying by a sample rate overflowed; use `dtype=float64`.
- **Label wrapping:** a Label with autowrap has zero minimum width inside an HBox, and its text collapses. Turn
  autowrap off for short labels.
- **CanvasLayer order:** sky -20, HUD 3, spellbook 5, ritual box 10, debug panel 20.
- **Physics layers:**
  - 1: terrain, stone walls, ice blocks, and spell areas by default.
  - 2: mobs.
  - 4: player.
  - 16: one-way platforms.
  - Player and walking-mob masks are 17. Flyers have mask 0.

## 9. Code style and structure

This code was grown one request at a time, which turns code into spaghetti unless each change keeps the shape
clean. It was cleaned up once, without losing any behaviour. Keep it that way:

- **Comments:** plain English `##` doc comments that say *why*, written like the existing ones. No jargon.
- **Names:** descriptive, and named after what the thing is *now*. When a feature changes, rename it (Quicksand
  became `Mudslide`; the fire walker's effect became `"burning"` when it stopped leaving a trail).
- **One script per spell effect.** Never add a branch on the spell's name (`if spell == "..."`) to a shared
  script. Simple effects extend `SpellEffect` (`scripts/spells/spell_effect.gd`) and fill in `_begin`, `_act`
  and `_finish`; bigger ones are their own Node. Add the new class to `arena._new_effect` or `spawn_spell`.
  A new `class_name` is only registered after `godot --import`.
- **Every spell** joins the `"danger"` group, and implements `danger_at(point)` (the AI wizards avoid danger,
  their own spells included, since they hurt them too). Anything else in `"danger"` (lava) must have it too: it is called on every member.
- **`mob.velocity.x = f()` where `f()` sets `velocity.y` loses the `y`**: GDScript copies the vector before it calls `f()`. Assign to a local first.
- **Find nodes through groups, not by scanning the tree.** `"fires"`, `"clouds"`, `"shots"`, `"rocks"`,
  `"lasting"`, `"earthquakes"`, `"danger"`, `"mobs"` (full list in `02_codebase_map.md`). Anything new that
  burns joins `"fires"` and is then melted, lit and avoided by everything else for free.
- **Check types with the class** (`node is Projectile`, `area is EnemyBolt`), not with spell-name strings.
- **Ask the object, don't reach into it.** Never read another script's `_underscore` variable or call its
  `_method`. Make it public (`facing`, `damage`, `earth_texture`) or add a small method (`is_slowed()`,
  `span()`, `dissipate()`, `velocity()`). No static flags for world state: `Earthquake.is_shaking(tree)` asks
  the group instead.
- **One helper, not copies.** Shared logic lives in one place: `SpellTargets` (who can be hurt, ground, `fire_points`,
  `fire_heat_near`, `shot_damage`), `GestureTemplates.bounds()` for a stroke's box, `PixelFx` for art frames. Look
  there before writing a loop.
- **Keep dependencies pointing one way.** The gesture code (`scripts/gesture/`) knows nothing about spells; it
  must load under `-s`, where autoloads like `Sfx` don't exist. Spell-specific behaviour goes in the spell, the
  arena or the AI (the earthquake's shaky hand is in `wizard_brain._shaken`, not in the caster).
- **Use the engine.** Prefer Godot's own tools (groups, signals, `Area2D` overlaps, `StaticBody2D`, tweens,
  `Rect2` helpers) over hand-rolled bookkeeping.
- **Delete dead code** (unused functions, signals, art) in the same change that makes it dead, and update
  `art/CREDITS.md`, `tools/prepare_gothic_art.py` and these docs to match.
- **Refactoring:** change one thing at a time and re-run the full check after each step (startup, gestures,
  soak waves 3/7/12/17, the spells showcase), comparing screenshots against a baseline taken first.

## 10. Known issues and ideas

**Known issues:**
- The death animation still shows a staff.
- Sounds are untested by ear.

**Ideas the owner may like:**
- Spells that combine: fire melts ice, storm plus water.
- Give each AI wizard its own personality.
- A gesture tutorial room.
- Music (CC0 dark ambient).

When unsure, ask the owner one clear question rather than guessing big.
