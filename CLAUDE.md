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
| `12_liquids.md` | touch water or lava: pools are a flowing grid now (`LiquidGrid`, `Pond`), and a Sinkhole dug beside one fills from it |
| `13_portal_world.md` | touch the portal world: a biome where portals open every few seconds, each a colour of its own, and carry you to another |
| `11_network_play.md` | touch anything a second machine must see: wizards, spells, pages, gates, the match (done: host and join over a network) |
| `15_open_problem_net_match.md` | work on the network match check that times out with eight wizards (open, unsolved) |
| `16_backlog_2026_11_05.md` | pick the next job: owner requests not yet coded (bugs, more attack spells, easing in new players, training grounds) |
| `14_spell_expansion_plan.md` | rename a school or a ritual, touch the Library, move the starting pages, or add Barbs, Pebble, Hailstorm, Featherfall, Thorn Whip, Flaming Sphere, Insect Plague, Leech, Raise Dead, Mirage or the Chant of the Scrying Eye (built; the Flaming Sphere is now a rolling sun; the stand-in shot art still waits for the owner) |

---

## 0. Player-facing words: THE NUMBER ONE PRIORITY

**The spellbook changed on 2026-11-07, but the change is small: it gained two stat lines and nothing else.** The owner first made the spellbook a canon tome with
no numbers, then reversed that part. A spell's page now has: (1) **its short description, written as before**: a plain phrase a person would say that names the thing,
about the length of the old lines ("Hurl a bolt of fire.", "Ignite a column of fire.", "Conjure a dying star."); (2) **a damage line**, in the shortest form, as a rate
where it ticks ("14 dmg/sec") or a flat figure where it strikes once ("30 dmg"), nothing when it deals none; (3) **a cost line** ("30 stamina", and "maximum stamina"
for a Necromancy spell, which is paid in maximum stamina; a drawn size gives a range). The two stat lines are written by the game from the spell's data
(`Spell.damage_line`, `Spell.cost_line`; the owner settled the wording: "30 stamina" and "30 max stamina", with no durations for now). Chant pages: the short description, and the cost
(none, except a Rift's maximum stamina). **The two stat lines always sit at the foot of the page, just above the page number, damage first and cost last** (`Spellbook._foot`),
so a reader always knows where to look for them, whatever the length of the description above.

**A line does not have to begin with a verb (owner, 2026-11-07).** It can, but the test is whether a person would say it. A thing that happens in the world is
often better said as a plain statement: "A jet of scalding water shoots up from the ground.", "Icicles grow down from the ceiling.", "Thorny brambles sprout from the
ground.", "A glowing mushroom grows from the ground.", "A stream of rising air." Use a command ("Shake the earth.", "Cover your body in obsidian.", "Summon an undead
servant.") where the reader does the thing. Do not force a verb on a line that reads better without one, and do not reach for a verb that does not fit the noun
("Raise a column of rising air" says "raise" twice and makes no sense of a stream of air). Interface lines (prompts, buttons) stay in the imperative.

**"Into" for what something becomes, "to" for a direction (owner, 2026-11-07).** "Turn the ground to sticky mud" is wrong to the ear and "Turn the ground into sticky mud"
is right. Both are "turn" followed by a result, but they are two different constructions. *Into* is the preposition of transformation: it takes any phrase that names what the
thing becomes, however long ("into sticky mud", "into a block of ice"). *To* after "turn" survives only in a few fixed phrases with a bare noun and no adjective ("turn to
stone", "turn to dust", "turn to ash"); everywhere else it means a direction or a recipient ("turn to the left", "turn to face"). Put an adjective in the phrase ("sticky mud")
and the fixed phrase no longer applies, the reader takes "to" as a direction, and the sentence snags. So: when a line says what a thing becomes, write "into" (or "become");
keep "to" for those bare-noun idioms and for real directions.

**Explicit means the figures, not an explanation. Do not narrate the spell.** The first redo (2026-11-07) wrote every page as a paragraph of mechanics ("the foot of it
flickers for a second, then the whole wall catches and burns for 4 seconds", "14 damage ... again every half second it stays in them") and the owner said it was "way
off the charts". Every other rule in this section still stands, and you may not relax a rule that the owner did not name. Specifically:
- **No mechanics narration.** Timings, warm-ups, how it ends, what it follows, what it is stopped by and what stops it are all left to the player to learn by casting.
  A reader learns "it flickers first" by casting it. The description says what the thing is, and nothing about how it behaves.
- **Stats are figures, not sentences.** Never "deals 14 damage to everything in the flames, again every half second": write the rate, "14 dmg/sec". Work the rate out
  from the code (damage per hit and how often it can land; a wizard cannot be hit more than once in `Wizard.HURT_GRACE`, half a second).
- **Keep the rules that were not reversed:** no how-to, no counters, no team words, no interface talk, no stroke description, nothing about edge cases, short.
  Durations and other figures beyond cost and damage are not asked for: leave them out unless the owner says a particular one belongs.
- **When the owner reverses or adds one rule, make the smallest change that does it.** Reading "be explicit" as "explain everything" was the same over-literal mistake as
  reading "start with a verb" as "never sound human". Ask yourself what the minimal edit is, and make it.

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
  addressed to the human ("Touch the book to start the game"). The spellbook is inside it.
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

**Test 1: Is it said to the reader, or about the world, and never about the machine?**
A line is either addressed to the reader ("Shoot a chilling bolt of ice.", "Kindle a bonfire and heal your wounds.", "Press Tab to open the spellbook.") or a plain
statement of what happens in the world ("Icicles grow down from the ceiling."). A verb first is common but not required (see the start of this section). What fails is a line that
describes the system: "Tab opens the spellbook." "Fire does 12 damage." "Speed is increased." A reader is a person doing something, or watching magic, not an observer of a machine.

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
while" and "for a while" are not wanted either (see the vocabulary list). The owner's example of what not to write:
"move 1.6 times faster, allowing you to run past poison clouds without losing all max stamina". The right
version is "Run faster."

**Test 4: Is there no meta information?**
Meta information is anything about the game rather than the world: how to use a spell, when to use it, what
counters it, what it combines with, how it interacts with the stamina bar, the cost, the maximum, the
mechanics. Fails: "to draw attacks", "in the direction you draw", "costs no stamina", "lowers your maximum",
"spent last", "walk slower", "the caster is spared" (state it as the spell's own effect instead, or leave it).
Passes: "Wrap yourself in a veil of blood that negates the next few attacks." A wizard in the world would know
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
Passes: "Run faster." "Hold your breath." "Give blood now, and draw on its strength once
the rest is spent." (confirmed by the owner). Pronouns must be clear: "Knock the target
unconscious", not "Knock whoever is under it unconscious" (the reader cannot tell what "it" means).

### Vocabulary that works

- Use **conjure** for a summoned thing ("Conjure a shadow of yourself."), and **summon** for a being or a star that is called ("Summon a dying star.", "Summon an undead servant.").
- Use **kindle** for fire ("Kindle a bonfire.").
- Use **freeze** for ice ("Freeze the surface of a body of water.").
- Use **sprout**, **grow**, **raise**, **summon** for things that come up out of the world.
- Use **negate** rather than **catch**, **absorb** or **block** when a spell stops harm ("Wrap yourself in a veil
  of blood that negates the next few attacks.").
- Do not write "for a while" or "for a little while" (owner, 2026-11-07: "I don't like the wording"). Leave the length out: the player learns it by casting. The one exception is where leaving it out would make a spell read as far too strong: Vires Fluant says "for a short amount of time".
- Use **the target** or **anyone** instead of **it**, **whoever** or **them** when the referent is unclear.

### The owner's standing corrections (each one is a rule)

- Decoy: "Conjure a shadow of yourself." Not "to draw attacks", which explains why and how to use it.
- Faint: "Knock the target unconscious." Not "Draw the strength out of whoever is under it".
- Frost Bridge: "Freeze the surface of a body of water." Not "Freeze the water into a bridge of ice".
- Great Oak: "Grow a great oak." Not "that comes crashing down". The falling is what happens; it is for the player to see.
- Gust: "Blow a gust of wind." Not "in the direction you draw".
- Hex: "Curse someone with a dark star: they take extra damage and cannot hide from you." The owner suggested this.
- Ice Prison: "Freeze things in a block of solid ice." Not "Lock anything inside the circle".
- Crimson Veil: "negates", not "catches"; "attacks", not "blows".
- Frostbolt: "Shoot", not "Hurl". Flare: "Light a small flame to light your way." Barrier: "Protect yourself from projectiles by blowing them away." Earthquake: "Shake the earth."
  Moonbeam: no "that lingers for a while". Silence: "Block magic from being cast in the area." Sneak: "Become invisible until your next spell interrupts it." Adrenaline: it makes you
  faster, hurt less and hit harder, and the line says so. Fight or Flight: "Trigger the target's fight or flight response." Raise Dead: "Summon an undead servant."
- Chants: Rite of the Land "Reveal a map of the world."; Vires Fluant "Gain unlimited stamina for a short amount of time." (without the words it reads as overpowered); Locum Muta "Teleport to a random location. WARNING: this can be
  devastating." (the owner wants the warning back); Oculum Mitto "Spy on another wizard."
- Black Hole (formerly Abyss): name it Black Hole, and describe it as a black hole, not as a "knot of darkness".
- Eclipse: the whole world goes dark (for as long as an Earthquake lasts, at the cost of one), so the line says so: "Plunge the whole world into darkness." Not "around you".
- Rituals: "Gain deeper knowledge of those around you."
  "Jump again in mid-air." "Hold your breath."
- Bonfire: "Kindle a bonfire and heal your wounds." (confirmed by the owner). ("Wounds" is the
  in-world word for what costs maximum stamina.)

### The spellbook page (decided 2026-11-07; the "canon tome" rule is amended, not dropped)

A spell's page holds its name and school's mouse buttons, its drawn picture, its short description (as before), a damage line and a cost line (see the start of this
section for the form). Nothing else was added: no durations, no mechanics, no tips, no counters, no stroke, no team words. The description is still the part that must
sound human and name the thing first. The reader still learns how a spell behaves by casting it.

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

A match: eight identical wizards (`WorldGraph.PLAYERS`: you and seven AI wizards, or friends over a network with AI wizards in the empty seats; the four figures are shared out and, once they run out, wear other sets of colours, `Net.rival_palette`) race through a generated world for spellbook pages and fight each other. The last one standing wins. The AI wizards cast the same
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
  - **Living scenery** (`World._raise_biome_life`, `docs/handoff/02_codebase_map.md`): the graveyard has low mist (`MistBank`), bats (`CritterFlock`) and crypts (`Crypt`, each with a page and a skeleton guard); the jungle has rope bridges between neighbouring great trees (`CanopyBridge`), light shafts, fireflies, swaying vines, birds that burst away and downpours (`Squall`); the peaks have avalanches (`Avalanche`), sheets of ice that make a wizard slide (`IceSheet`) and an aurora; the ashlands have lava lakes that swell (`LavaSurge`), ash storms with falling embers (`EmberRain`) and volcanoes that rumble and shake the world, send up a plume of smoke (`SmokePlume`: no one sees through more than a little of it; on a person's own screen `SmokeVeil` hides what lies past it behind a paler haze, so the dark column and the haze are told apart) and pour lava over the rim that cools to a crust and goes (`Eruption`); the underground has glowing crystals, drips, stalactites that fall on whoever walks under (`FallingRock`) and cave-ins (`CaveLife`). Storms, avalanches, swells and cave-ins follow the world's age, so every machine of a match sees them at the same time. Run `tests/showcase.tscn -- scenario=life` with `WORLD_SEED` (0 jungle, 1 graveyard, 4 mountains, 5 ashlands, 13 underground).
  - Each world of a match is one of these six, in an order the seed picks; the last, small world is all open sky, one of the first four.
  - **Each biome has landmarks of its own, not just a reskin; only the underground has tunnels.** The graveyard is dark with rain and fog, and its skeletons roam
    (`Mob.roams`). The ashlands have volcanoes that erupt now and then (`Eruption`) and pits of lava. The snowy peaks are mountains to climb (`MountainGale`: wind that grows toward the summits and pushes a wizard without the run animation, seen as streaks; `SnowCloud`: clouds that drift past in front of whoever is in them), with a page on each
    summit. The jungle has pits of mud (`Mudslide`, dug by the world), thickets of thorns (`Bramble`) and great trees (`JungleTree`: dense, in two sizes and mirrored or not, every one with the oak's ledges to hop between and a vine to climb to the high one, where most of the pages lie; the AI climbs the vines; the ponds are full of `Piranhas`). Its art is still named for the swamp it was cut from. The castle is a row of castles with six floors: a cellar down a
    stairwell, the ground floor and four floors over it, three rooms to a floor (see `docs/world_generation.md`).
- **Characters and art:** LuizMelo characters, Ansimuz GothicVania environments, and CC0 pixel effects.

## 2. The eleven rules that matter most

*Where a rule below concerns player-facing text and differs from section 0, section 0 wins. The spellbook is the exception that changed on 2026-11-07: its
spell and chant pages now state the cost and the damage (see the start of section 0); everywhere else there are still no numbers.*

1. **Spells must reflect something real, and must be counterable.** Fire Nova (a magic ring blast) was removed
   because it "doesn't seem to reflect anything in real life and is impossible to block."
   - Every spell needs a real-world analogue: a flamethrower, a lightning strike, quicksand, a boulder.
   - Every spell needs a counterplay: block it, dodge it, or take cover.
   - Ground, stone walls, ice and platforms block things physically.
2. **The gesture is a picture of the effect.**
   - Fire Breath is a cone (`<`). Mudslide is a wavy line (the Frost Bridge shape, on the Earth buttons); Earthquake is an arrow with a head at both ends (the ground pulled both ways); Stalagmite is one or more peaks (^) drawn over the ground; Sinkhole is a U (the pit).
   - Black Hole is an inward spiral. Blizzard is a star with a snow line.
   - Icicles are V shapes. Push is a circle (the area) plus a line out of it (the direction).
   - Never assign an arbitrary shape.
3. **No code-drawn pictures.** "All the other code-drawn pictures stick out like sore thumbs; they absolutely
   have to be replaced."
   - Everything in the world must be real pixel art from free assets.
   - The only exceptions are interface elements: health bars, the gesture trail, shadows, and pixel snowflakes
     or shards made of pixel squares.
   - Before adding `draw_circle`, `draw_line` or `draw_polygon` for a world object, look for an asset first.
   **Do not make art or sounds yourself, either** (owner, 2026-11-07: "you shouldn't do that"). A picture or a sound that is not code-drawn still has to come from a free source found online (CC0, CC-BY or any
   free licence, credited in `art/CREDITS.md`), not be drawn, synthesised or composed by an agent. A synthesised Eldritch Blast "sounded like a fart"; the Scythe blade an agent drew was kept only because the owner
   happened to like it. If nothing free fits, tell the owner and ask.
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
    **Spellbook entries** (the older nine rules; where they say "no numbers", "no cost" or "never mention cost scaling", the 2026-11-07 decision in section 0 replaces them):
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
12. **Describe what the thing does to the player, never the numbers behind it** (outside the spellbook's spell and chant pages, which now give their costs and damage, section 0). No multipliers, percentages or comparisons: never "1.6 times faster", "50% more damage", "half damage" or "walks slower". Write "Run faster." The only numbers allowed are damage and durations in seconds. Don't list side effects, weaknesses or interactions (what burns it, what it stops, what it combines with): the player learns those by playing. One effect per spell, in one short line.
13. **Name no team.** Spell and game text says "anyone", "anything" or "whoever", never "foes", "enemies", "allies" or "rivals" (spells have no teams, see section 5).

## 3. Run, test and look

```
GODOT="/c/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                          # after adding or changing any asset
"$GODOT" --headless --path . --quit-after 200                  # parse check: grep the output for "SCRIPT ERROR"
"$GODOT" --headless -s tests/test_gestures.gd                  # must print "784 of 784" (or more, if you add checks)
"$GODOT" --headless -s tests/test_pages.gd                     # the pages each wizard is dealt and a ledger's rules
"$GODOT" --headless --path . tests/intro_check.tscn            # the cut-scene (add `-- mode=skip`, or `-- out=DIR` for pictures, without --headless)
"$GODOT" --headless --path . tests/flow_check.tscn             # lab, portal, cut-scene, loading, world
"$GODOT" --headless -s tests/test_nav.gd -- seeds=6            # the wizards' map of the ways agrees with the generator's
"$GODOT" --headless -s tests/test_stages.gd -- seeds=6         # the smaller worlds a match collapses into: walkable, spread starts, every page placed
"$GODOT" --headless --fixed-fps 60 --path . tests/collapse_check.tscn  # a whole match through its collapses (time shortened)
"$GODOT" --headless --fixed-fps 60 --path . tests/gate_check.tscn -- seed=8 only=ice  # a wizard clears gates with spells (without only= it walks to them: minutes)
"$GODOT" --headless --fixed-fps 60 --path . tests/interaction_check.tscn  # spells that meet: water puts out fire, fire dries mud, lightning lights plants and shocks pools, a tornado over fire
"$GODOT" --headless --fixed-fps 60 --path . tests/follow_check.tscn -- seed=0  # piranhas, ice and a Geyser follow a pool's liquid as it flows
"$GODOT" --headless --fixed-fps 60 --path . tests/geyser_check.tscn  # a Geyser's and a Tide Surf's water is real liquid, not made over and over
"$GODOT" --headless --fixed-fps 60 --path . tests/wall_liquid_check.tscn  # a Stone Wall holds back poured lava like any ground, and the lava runs on when it is gone
"$GODOT" --path . tests/minimap_look.tscn -- seed=0 out=DIR  # how much of the minimap is ground (needs a window)
"$GODOT" --path . tests/water_look.tscn -- out=DIR             # pictures of a Geyser and a Tide Surf by the waiting-room pond (needs a window)
"$GODOT" --path . tests/bonfire_look.tscn -- out=DIR [seed=N]  # a picture of a Bonfire beside the wizard in the waiting room, or in the world of a seed (needs a window)
"$GODOT" --path . tests/marks_look.tscn -- out=DIR             # pictures of the Hex, Fight or Flight and Moonbeam marks (needs a window)
"$GODOT" --path . tests/minimap_check.tscn  # the minimap stays in the top right corner as the window is resized
"$GODOT" --headless --fixed-fps 60 --path . tests/eruption_check.tscn -- seed=5  # an ashlands volcano erupts: a smoke plume, lava over the rim that cools and goes (add `out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/stalagmite_check.tscn  # a Stalagmite rises from the ground under the tip of a drawn peak (add `-- out=DIR` for a picture, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/sinkhole_biomes_check.tscn -- seeds=0,1,2,4,5,9,13  # a drawn U digs a pit of its shape in every kind of ground, the castle's slab floors too (add `out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/ridge_check.tscn -- seed=4  # the snowy peaks' ridges: a wizard lands on one and S drops them through it (add `out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/tutorial_path_check.tscn  # the tutorial room is shut off place from place: the book starts empty and a page at each place gives its spell, the dummy and the skeleton (put down by a Faint) kill whoever passes them awake, turrets kill the unprotected, a cliff needs the double jump chant, thorns kill until burnt, a pit cannot be jumped
"$GODOT" --headless --fixed-fps 60 --path . tests/tutorial_check.tscn  # the tutorial room's page at each place, and the library's counts (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/match_stats.tscn -- seed=3  # one whole match of AI wizards at real times: the pacing of each world, how often wizards are near each other, and whether the winner won by pages or by casting (takes minutes; run several seeds and compare the RESULT lines)
"$GODOT" --headless --fixed-fps 60 --path . tests/sinkhole_check.tscn  # a Sinkhole lowers the ground under it and leaves the ground beside it (add `-- out=DIR` for a picture, needs a window)
"$GODOT" --headless -s tests/test_liquid.gd                      # the flowing liquid on its own: falls, levels, fills a pit, keeps its liquid, is quick
"$GODOT" --headless --fixed-fps 60 --path . tests/liquid_world_check.tscn -- seed=3  # a world's pools and a pit dug beside one (seeds 3, 5, 7, 12 have pools)
"$GODOT" --headless --fixed-fps 60 --path . tests/dark_check.tscn  # a wizard walks across a stretch of spike strips
"$GODOT" --headless --fixed-fps 60 --path . tests/spectate_check.tscn  # the player falls and watches a rival (add `-- collapse` to follow into the next world)
"$GODOT" --headless --fixed-fps 60 --path . tests/pull_check.tscn  # the portal tears open at the top and sucks the wizards in (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/spark_check.tscn  # Spark Strike lands on the ground under open sky
"$GODOT" --headless --fixed-fps 60 --path . tests/stairs_check.tscn  # a swinging stair is a one-way platform: a wizard stands on it and holding S drops them through
"$GODOT" --headless --fixed-fps 60 --path . tests/stairwell_check.tscn  # the castle has thirteen swinging stairs (`SwingStair`) in three stairwells, each swinging among landings on other floors; a wizard waits for one, crosses it and is carried (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/menu_check.tscn  # the first screen is the open spellbook: a sign drawn with the left button held chooses its inscription, and the page turns (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/settings_check.tscn  # the Settings page (`SettingsPanel`, kept by `GameSettings` in `user://options.cfg`): a cog sign on the first screen and a button on the pause screen open it; choices are kept, shake and cut-scenes obey them (add `-- out=DIR` for a picture, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/lab_revive_check.tscn  # whoever dies in the waiting room is on their feet at once
"$GODOT" --headless --fixed-fps 60 --path . tests/likeness_check.tscn  # the wizard maker: its words open it, and the page with them comes up before the magic mirror floating over the slab of the waiting room, a figure and colours chosen are worn and kept (`GameSettings` look and palette, `Net.look_of`/`palette_of`/`rival_look`), the four figures are one height (`WizardLook.SCALE`), a brain never wears a person's figure (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --path . tests/look_palettes.tscn -- out=DIR  # every figure in every set of colours, side by side (needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/cluster_check.tscn  # each wizard starts with no spells and finds a cluster of pages by their spawn (`Pages.cluster_of`), in every biome
"$GODOT" --headless --fixed-fps 60 --path . tests/brains_start_check.tscn  # the AI wizards read their cluster
"$GODOT" --headless --fixed-fps 60 --path . tests/blizzard_freeze_check.tscn  # a Blizzard chills and then freezes whoever stays in it (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/group_a_check.tscn  # Barbs, Pebble, Hailstorm and Featherfall
"$GODOT" --headless --fixed-fps 60 --path . tests/group_b_check.tscn  # Thorn Whip and Insect Plague
"$GODOT" --headless --fixed-fps 60 --path . tests/group_d_check.tscn  # Eldritch Blast, Hemorrhage, Supernova and Scythe, each cast in a world against a dummy
"$GODOT" --path . tests/attacks_look.tscn -- out=DIR  # pictures of those four (needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/group_c_check.tscn  # Thunderclap (throws everyone near back but the caster, and dazes them) and Rocket Jump (the caster is thrown far up)
"$GODOT" --headless --fixed-fps 60 --path . tests/leech_check.tscn  # the tether, the split of a spell's cost and what breaks it
"$GODOT" --headless --fixed-fps 60 --path . tests/raise_dead_check.tscn  # a skeleton with a master: never touches them, fights a rival and a rival's skeleton, follows, falls with its master
"$GODOT" --headless --fixed-fps 60 --path . tests/mirage_check.tscn  # a false page that fades when anyone comes near, and a brain that learns
"$GODOT" --headless --fixed-fps 60 --path . tests/sphere_check.tscn  # the Flaming Sphere rolls, climbs a wall, falls into a pit and climbs out, burns, goes out (add `-- out=DIR`, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/eye_check.tscn  # the Chant of the Scrying Eye: a window bottom right, the eye over the watched wizard, the ground made round them (add `-- out=DIR`, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/castle_spells_check.tscn  # the castle takes spells: a boulder rests on a swinging stair, a Stalagmite and a Sinkhole work on an upper floor
"$GODOT" --headless --fixed-fps 60 --path . tests/avalanche_check.tscn  # the peaks' avalanche rumbles, then runs down its slope and hurts whoever it runs over, once
"$GODOT" --headless --fixed-fps 60 --path . tests/pieces_check.tscn  # small pieces: a world's four words and its seed, the spell table and its buttons, a fireball called down onto the ground
"$GODOT" --headless --fixed-fps 60 --path . tests/ritual_check.tscn  # the chants: how accurately they must be said, and what each gives
"$GODOT" --headless --fixed-fps 60 --path . tests/library_screen_check.tscn  # the library's ledger, its face-down cards and its world filters, from a file of its own
"$GODOT" --headless --fixed-fps 60 --path . tests/castle_sinkhole_fall_check.tscn  # a wizard dropped into a castle pit sinks into it and stays, or falls through to the floor below
"$GODOT" --path . tests/castle_sinkhole_look.tscn -- out=DIR  # pictures of a Sinkhole dug in every kind of castle floor (needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/biome_jump_check.tscn  # the F1 panel goes to a world of any biome, whatever the seed deals
"$GODOT" --headless --fixed-fps 60 --path . tests/parity_check.tscn  # Push, Geyser, Tornado, Tide Surf and a shot do the same to a person's wizard and the brain's
"$GODOT" --headless --fixed-fps 60 --path . tests/brain_spells_check.tscn  # the brain knows every spell: each is given alone to an AI wizard in the place it wants it, and cast (add `-- only=Hex,Sneak` for some)
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
"$GODOT" --headless --path . tests/dedicated_check.tscn  # starts a dedicated server (`-- --server`, see tools/run_server.bat) as a program of its own, joins it, plays into a world and leaves (no --fixed-fps). Add `--upnp` to the server (not in the test) to open its port on the home router and print the address to join at
```

- **All the checks at once:** `python tools/run_checks.py` runs the quick set (47 checks, about 55 seconds on six cores) and prints one line for each, ok or FAILED. `--full` adds the slow ones (85 checks, about 3.5 minutes): a whole generated world, the showcase's scenarios, longer route checks and the network checks, which start two or three copies of the game. (`--all` is the old name.) A scene check also fails when it prints a `SCRIPT ERROR`. How it stays fast and steady: long checks are split into shards (`test_nav#1`, `brain_spells_check#2`...); the longest start first (times are kept in `times.json` in the output folder); the network checks run first, all together, each on a port of its own (`WIZARD_PORT`, read by `Net.port()`), with nothing else running, because they run in real time and give up when starved; the rest run below normal priority; a Godot crash while starting is started again and one while closing, after passes were printed, is not a failure; and a check that fails is run once more (a pass then is listed as FLAKY, and the first try is kept as `check_<name>_first_try.txt`). `-j N` sets how many run at once (default cores + 1); names on the end pick checks (`python tools/run_checks.py --full ritual`). A flaky check is a bug in the check or the game, not something to retry past: the ones found so far were a freed page tested with `is` in the brain (`_goal_lost`), a rival with every spell freezing the person in `raise_dead_check`, other wizards putting water in the ground `geyser_check` counted, and a route move that ended on a great tree's ledge. `brain_spells_check dice=N` rolls the dice differently to look for a roll that fails.
- **Coverage:** `python tools/run_checks.py --all --cov` runs the scene checks in a scratch copy of the game with `gd-tools` (see `tools/coverage_run.py` for the setup) counting the lines that ran, and prints the scripts that ran least. It takes ten minutes or more. `gd-tools` cannot read about twenty of the scripts (it names them), so they are left out of the figure; a check run with `-s` has no autoloads, so the gesture, page, navigation and stage checks are not counted either.
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
| Left mouse | Pyromancy (Fire) |
| Right mouse | Aquamagy (Water) |
| Middle mouse | Aerokinesis (Air) |
| Left + Right | Terramancy (Earth) |
| Left + Middle | Druidry (Flora) |
| Right + Middle | Umbramancy (Shadow) |
| Left + Right + Middle | Necromancy (Blood) |
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
| Fire | Firewall | a line up, then a line out to either side: the second line is how wide the wall is, and the wider it is the more it costs (`Caster._up_and_out`, one `Firewall` column every 26 px along it) | burning brush line | it's passable and only burns; walk out of it |
| Fire | Fire Breath | cone `<` | flamethrower from the mouth (follows facing, rises on a jump) | cover, Barrier, distance |
| Fire | Smoke Screen | wavy line going up | a bank of smoke enemies cannot see through | wind (Tornado, Gust), Tsunami |
| Fire | Flare | flame: a loop with its point up | a small harmless flame that follows you and lights the dark | it burns out |
| Fire | Spark | tall zigzag | a lightning strike from the sky; stops at the first platform or ground | shelter under a platform |
| Water | Frostbolt | flick | thrown ice spear | as Ignite |
| Water | Icicles | one or more Vs in a row, under a ceiling | icicles hanging from the ceiling | step around |
| Water | Ice Prison | circle | freezing whoever is inside solid | Push or Earth shatter; Barrier |
| Water | Blizzard | star then a level line | snow cloud | leave the area |
| Water | Frost Bridge | wavy line across water | freezing a pond so you can cross | fire melts it |
| Water | Geyser | an arrow pointing up | a jet of scalding water that throws what stands on it and scalds it (1 dmg/sec), with steam coming off it | step off while it bubbles |
| Air | Push | circle then a line out | a shove of air; the only spell that lifts you | positioning |
| Air | Barrier | circle | a shield bubble | wait it out |
| Air | Tornado | tall narrow coil going down | a whirlwind | avoid it |
| Air | Vacuum | infinity sign on its side (lungs), drawn over a wizard | the air drawn out of someone's lungs: they hold their breath (no chanting) and then suffocate | it lets go when the caster casts again or is hurt; step out of sight to cast, or hit the caster |
| Air | Updraft | arrow pointing up | a column of rising air that stays for the rest of the world; any number can be raised | none; it lifts anyone |
| Air | Gust | straight flick | wind along the stroke: turns shots, sweeps flyers, smoke and you sideways | heavy foes resist |
| Earth | Stonefall | circle with a line down | a dropped boulder | watch the shadow |
| Earth | Stone Wall | line starting on the ground, a platform or another stone wall | a raised slab | Earthquake, Stonefall, shots wear it down |
| Earth | Mudslide | wavy line (as Frost Bridge) | a pit of mud: slows, no jumping; flyers pass over | walk out |
| Earth | Stalagmite | one or more peaks (^) over the ground | spikes of rock that rise from the ground and hurt whatever touches them | step around |
| Earth | Earthquake | arrow with a head at both ends | the ground shakes | flyers unaffected |
| Earth | Sinkhole | U | the ground opens: `Terrain.dig` cuts a pit the shape of the U that was drawn (`Sinkhole.profile_of`) in the open ground and the rock is cut again (permanent) | jump out, fly |
| Flora | Bramble | low sawtooth | a thicket of thorns: slows and pricks | jump it; fire |
| Flora | Spore Puff | cone `<` (as Fire Breath) | poison spores poured from your mouth | wind, water |
| Flora | Liana | leaf and line: an almond lying on its side, then a line up from its left point (a vine) | a vine to climb | fire |
| Flora | Great Oak | trunk drawn up into a round crown | a tree: ledges and a wall, and when it falls it crushes | fire, Earthquake, Stonefall; it creaks first |
| Flora | Flytrap | tall narrow W | a trap that snaps shut on whoever steps in | jump, fire |
| Flora | Lily Pads | a ring (the pad), then a level line across the water where they grow | floating leaves to cross water or a pit | fire; they sink after 8 s |
| Shadow | Decoy | figure of eight | a shadow that draws enemies' attacks | it wears out |
| Shadow | Eclipse | the outline of a crescent moon, drawn in one stroke | the whole world goes dark for as long as an Earthquake lasts (6 s); everyone sees only what is close; costs 60, as an Earthquake does | Flare |
| Shadow | Hex | pentagram (five-point star, one stroke) | a curse: 50% more damage | short time |
| Shadow | Silence | circle with a line struck through it | a ring where nothing can be cast, spell or chant (`Wizard.silenced`) | step out; it fades |
| Shadow | Black Hole | inward spiral | a dark knot that pulls everything toward it, fiercely close in and faintly from far off (walls still stop it) | walk out |
| Shadow | Shadow Step | flick | slipping along the stroke | |

**The spellbook page** (owner decision, 2026-11-07): the drawn picture, a short description, the damage it deals ("14 dmg/sec", "30 dmg") and its cost in stamina (maximum stamina for Necromancy), see section 0. Everything else about a spell, what counters it included, is learned in play. The table above is the first 32 spells. The others (Vacuum, Updraft, Sinkhole, Stalagmite, Silence, Fight or Flight, Sneak, Hunter's Mark, the Blood spells, Tide Surf, Obsidian Armor, Glowcap and Moonbeam) are in `spells/` and `docs/spell_pool.md`.

**The schools have new names** (the ids Fire, Water, Air, Earth, Flora, Shadow and Blood stay in code and double as element tags; only what a player reads changed, through `SpellData.school_name`): Pyromancy, Aquamagy, Aerokinesis, Terramancy, Druidry, Umbramancy and Necromancy. The Library gives a title from the casts (`Library.title_of`).

**Ten spells were added (handoff chapter 14):**

| School | Spell | Shape | Real thing | Counterplay |
|---|---|---|---|---|
| Fire | Flaming Sphere | a ring drawn from its bottom, then a level line along the ground | a ball of fire that rolls, follows slopes, falls into pits and climbs a wall (`FlamingSphere`, a `CharacterBody2D`; it keeps the ground round it made through the `ground_watchers` group); burns out after a long roll | jump it; water and rain put it out |
| Water | Hailstorm | a ring, a line out of it, then a line down | a storm cloud that drops hail along the line | a roof |
| Air | Featherfall | a feather drifting down: three sweeps across, each bent down in the middle, each ending lower | a slow fall for a while | none needed |
| Flora | Barbs | a flick | a short spread of thorns | stone, fire |
| Earth | Pebble | a flick | a stone that falls as it flies (goes over a wall that stops a flat shot) | cover |
| Flora | Thorn Whip | the Tide Surf wave | a lash that drags the first thing it meets toward the caster (a wizard, an enemy, a loose page) | a wall, fire; a giant is too heavy |
| Flora | Insect Plague | an infinity sign, like a bee's wings | a stinging swarm, one cloud that ticks, drawn as insects; it follows the nearest wizard (the caster after a few seconds) | one hit, fire, water, smoke, wind |
| Necromancy | Leech | the Tide Surf wave, aimed at a wizard | a tether (`Leech`): while it holds, every stamina spell the caster casts is paid half by the caster and half by the other end; it breaks when they lose sight of each other, move too far apart, or either falls | a wall, distance |
| Air | Thunderclap | a cloud (a ring begun at its bottom), then a lightning bolt: a zigzag down out of it | thunder (a recording): throws back everyone near except the caster (no harm) and dazes them (`Wizard.daze_time`: slow, and no spell or chant) | stay out of its reach |
| Fire | Rocket Jump | an arrow pointing up (drawn with the fire button) | flame from the feet lifts the caster slowly at first and then faster, about 480 px up (`RocketJump`, `Wizard.rocket_time`) | none needed |
| Necromancy | Raise Dead | a Latin cross: a long stem and a shorter bar across it, nearer the top | a skeleton (a `Mob` with a `master`) with 50 health for 37 maximum stamina, not refunded | kill it |
| Umbramancy | Mirage | a tall box | a false page that wavers and fades when anyone comes near (`Mirage`, a `PagePickup`) | walk up to it; the AI learns after seeing one fade | The school and spell plan is in `docs/spell_pool.md`; the direction of the game (a last-wizard-standing page race, which replaced the
boss and the solo roguelite loop of `docs/roguelite_exploration_design.md`) is in `docs/pvp_arena_design.md`. The waiting room (`scenes/lab.tscn`, `scripts/lab.gd`) is where every spell is tried; the portal there
starts a run. The first screen also has a **Tutorial** (`scripts/tutorial.gd`: a book that starts empty and a row of things in the way, each with the pages that answer it lying at its foot; only the keys to walk and jump are on screen. A dummy and a giant (too strong to kill: a Faint puts it down) strike down whoever walks past them, a pond of piranhas (waded after a Spark, or crossed on ice or pads), turrets that hit whoever has no cover, thorns too long to walk through, a cliff only a vine climbs, a gap only the double jump chant crosses, a dark stretch of spikes only a light shows, a gate that asks for two spells together (a light then fire), a pit and past it a wall of brick (a leap, then a quake or a boulder), an eye that shoots (cover, then fire on the thorns), poison gas (wind, fire or a Barrier) with a second pit after it, and a pond of piranhas in the dark (a light, then a Spark), and last of all a run with no page to read that uses what was learned: a gap that takes the double jump chant, a cliff that takes a vine, a pit that takes a leap and a long thicket that takes fire (`Tutorial.FINALE_*`, from column 536 on). Whoever falls keeps the pages they read) and a **Library** (`scripts/library.gd`, `library_screen.gd`: what this machine remembers of the matches played on it, in `user://library.json`: matches played and won, and for each page how often it was found, its spell cast, and a match won with it in the book. Only the person at the machine, only in real matches; the tests never touch it).

**Attacking spells from the overnight batch of eight (2026-11-06; the owner vetoed six of them on 2026-11-07, see "Inventing a spell" in section 6) and the two the owner then approved (Supernova and Scythe). Each has a test in `tests/group_d_check.tscn`:**

| School | Spell | Shape | Real thing | Counterplay |
|---|---|---|---|---|
| Shadow | Eldritch Blast | an arrow (the beam goes the way it points) | a beam of crackling dark energy that strikes the first thing in its way at once, up to 640 px, as the spell of that name in Dungeons & Dragons does (`EldritchBlast`, a ray: no shot to dodge or turn) | a wall, distance |
| Blood | Hemorrhage | a drop of blood: the flame shape (`flare`), drawn over someone | a wound that bleeds a little at a time for a while (`Hemorrhage`) | it wears off |
| Fire | Supernova | a ring, then a flat oval round it, like Saturn (`saturn`, one stroke) | a dying star hangs where it was drawn for 5 seconds: it burns whoever is close, pulls everything toward it a little, then explodes, hurting and throwing everyone within about 320 px far away (`Supernova`); costs 80 | get clear before it blows; stone or a wall |
| Blood | Scythe | a crescent (the blade) | one swing of a real scythe (pixel art drawn for the game, `art/fx/scythe.png`, a pale ghost blade) in a half circle in front of the caster that cuts hard (45) and drives them back (`Scythe`) | stay out of reach, a wall |

The spellbook lines (see the book: every spell now has a plain description, a damage line and a cost line) are drafts until the owner confirms them. A Blood loop the recognizer takes for a flame but is not one is read again as the circle (`Caster._end`), because Hemorrhage's flame shares Blood's buttons with Burst's circle. `tests/attacks_look.tscn -- out=DIR` (needs a window) takes pictures of them.

**Pages per world:** each world lays only `Pages.count_for(biome, width)` pages (graveyard 16, peaks 16, jungle 18, ashlands 12, castle 18, underground 20, portal fields 10, at 1000 tiles wide, fewer in the smaller worlds, never under 6), and which ones is settled when the match begins, from its seed (`Pages.allotment`): each wizard is dealt starting pages of their own, and each world is given pages of its own from the rest, no page in two places, some in none. So a page is never in a world once a wizard holds it, and no two wizards start alike. Pages not laid do not carry over. A kind of gate the world has always keeps a page that opens it, swapped in from the spare pages if need be (`Pages.with_openers`). In a world with no halls, pages lying out in the open are at least `Pages.MIN_APART` (40) columns apart, apart from the three near the start (`tests/pages_spread_look.tscn` prints where they lie).

**Targeting types:** `directional`, `positional`, `angled`, `shape` and `cone`. The caster's `cast_resolved`
signal passes `info` (radius, line, rect, shapes, aim, spread, reach), and `arena.spawn_spell` routes it.
**No sides:** once a spell is cast it has no team. It hurts whoever it touches: enemies, the player, the dark
wizard, and the caster and its allies too (friendly fire). **The one exception is Raise Dead:** a skeleton has a master (`Mob.master`). It never attacks its master, and skeletons of different masters fight each other. It is the first thing in the game with a master; the spells themselves still have no sides, and every spell still hurts a skeleton (its master's too). It falls when its master falls. The one exception is a shot (Ignite, Frostbolt, an enemy's
bolt): it can't hit whoever fired it while it is still inside that body. Once it has flown clear, it can hit them, so
it hits them if it comes back. Blink and Fire Breath start on the caster's body, so the caster is passed by there as
well. `scripts/spells/spell_targets.gd` decides who can be hurt.

## 6. Designing a new spell: checklist

### Inventing a spell: what the owner has taught (read before you propose anything)

The owner wants agents to learn to invent spells without being told. Until they have shown they can, **never build a spell the owner has not approved as an idea**: first send a short list (the thing in plain words, the school, the gesture as a picture of it, why it is not like a spell we have), and build only what they pick. Keep adding what you learn here. The lessons so far come from an overnight batch of eight (Wind Cutter, Eldritch Blast, Sandblast, Sleet, Meteor, Strangler Vine, Hemorrhage, Steam Burst), most of which the owner vetoed:

- **Name it with a word people already say.** "Meteor", "Bat Swarm", "Lightning". Do not invent a compound ("Wind Cutter", "Eldritch Blast" drew "what is that?"). If a stranger would ask what the name means, the name is wrong.
- **Write the line the way a person would say it.** Starting with a verb is a habit of the old rules, not the test: the test is whether a human would choose these words. Rejected, though each fits a dictionary: "Hurl a blade of wind", "Hurl a bolt of darkness" (you cannot hurl these, and the reader does not know what they are), "Blast a cloud of sand and grit" (people do not say "blast" for this), "Call down a burning rock from the sky" (everyone knows what a meteor is; you do not "call down" one), "Sprout a coiling vine", "Open a wound that will not close", "Release a column of scalding steam". Do not describe the obvious ("burning rock" for a meteor). Show the owner the line next to the nearest line they already confirmed.
- **The gesture is a picture of the spell, never a shape that happened to be free in the school.** Hemorrhage's crescent, Steam Burst's wave and Strangler Vine's spiral were chosen because they were unused; the owner noticed.
- **No near-duplicates.** Sleet was Barbs in ice colours; Strangler Vine was Flytrap. Before proposing, find the nearest existing spell and say what the new one does that it cannot.
- **A spell must be worth casting.** Steam Burst was too weak to bother with. Say what it can do that nothing else can.
- **Do not tell a little story in the line.** "Call a wolf to hunt" and "Send a hawk after its prey" were rejected: the line names the thing and what it is, in the plain verb for it (summon, conjure, swing), not what it is for.
- **When the owner names a spell from another game (Eldritch Blast, Supernova), build it the way it behaves there.** Eldritch Blast is a beam that hits at once, not a slow dart.
- **A spell that is a real object needs real art, not a particle effect.** The Scythe was a pale smear until it had a scythe: search for free art (CC0, CC-BY or any free licence, section 7) and credit it.
- **A spell drawn "over" or "around" something must find everything inside the shape that was drawn**, not only what is near its middle (Hemorrhage missed big targets).
- **A spell with a warning is fairer than one that strikes at once** where it is cast on the spot (the Firewall flickers for a second before it burns).
- **A homing thing seeks anything alive** (wizards and creatures), not only wizards.
- **Check the school's name, not only its code id.** Flora is Druidry (nature, animals too), Shadow is Umbramancy, Blood is Necromancy. Animal spells belong in Druidry.

### The checklist

1. **Name the real-world thing.** If you can't, stop.
2. **Pick the school by what it is:**
   - Fire: heat, burning, lightning, light and smoke.
   - Water: cold, slowing, freezing, solid ice, dousing, floods.
   - Air: pushing, deflecting, shields and wind.
   - Earth: stone, ground, sand, weight.
   - Flora: plants: things that grow, hold and trap, and all burn.
   - Shadow: sight, decoys, curses and gravity.
3. **Draw what it looks like.** The stroke should be the thing's silhouette or its motion. **The dearer the spell, the more involved the stroke** (owner, 2026-11-07): a cheap spell is a flick or a
   single curve, a spell that costs a great deal (an Earthquake, an Eclipse, a Supernova) is drawn with a long, many-part stroke. Power and effort go together.
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
10. **Spellbook:** a short description, and the damage and cost lines from the spell's data, at the foot of the page. Keep it short.

## 7. Art: where it comes from and how it's built

- **The pipeline:** `tools/prepare_gothic_art.py <downloads dir>`. It builds `art/chars`, `art/mobs`,
  `art/tiles`, `art/props`, `art/backgrounds`, `art/fx`, `art/ui`, and generates `scripts/pixel_art.gd`
  (frame sizes and body boxes).
- **Folder names** the script expects are listed in its docstring.
- **Downloads are not kept in the repo.** Re-download them into a scratch folder.
- **Credits:** every source and licence is in `art/CREDITS.md`. Add a line for anything new.
- **Licences (owner decisions, 2026-10-25 and 2026-11-07):** we are **not restricted to CC0**. Use any art or sound we are really allowed to use in the game for free:
  CC0, CC-BY (a credit line in `art/CREDITS.md`: the author, the pack and a link), and any free licence or "free for commercial use" page whose terms we can meet.
  Read the terms of the page, put every source in `art/CREDITS.md`, and prefer CC0 when two assets fit equally. Do not spend money: a paid pack is not free.
  Where a licence puts a condition on the game itself (share-alike, GPL, "non-commercial only", "no redistribution"), tell the owner before using it.
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
- Sounds: the owner has heard them and they are fine (2026-11-05).

**Ideas the owner may like:**
- More spells that combine (fire melting ice, water putting out fire, lightning in pools and a fire whirl are built).
- More to the tutorial room (`Tutorial`, `scenes/tutorial.tscn`: a page for each school, with two meetings of spells), such as a place for the chants.
- Music (CC0 dark ambient).

When unsure, ask the owner one clear question rather than guessing big.
