# Read this first, every session

> **OWNER REVERSAL, 2026-11-23 (read before section 0): the spellbook now EXPLAINS.** The owner said the old cryptic wording was "absolutely wild" ("Win back what was just taken from you") and wants every description to say what actually happens, durations and conditions included: "Heal back any max stamina lost over the last 10 seconds." Where section 0 below says no mechanics narration, no durations, no conditions, that part is withdrawn; its other rules (American spelling, no team words, no key names in a diegetic line, "into" for what something becomes, short sentences a person would say) stand. **How to word one (the owner, same day, after the first attempt added too much):** say what the spell does, in ONE plain sentence a person would say, and put in a figure only where it defines the spell ("over the last 10 seconds"). Do NOT add edge cases or side rules nobody asked about ("can kill you", "any hit wakes you", "works once", "does nothing if you are wet"): the player finds those by playing. Explaining means naming the effect plainly, not listing every condition. Only the heals and chants of section 6a have been rewritten so far; the rest of the book still has the old lines and needs a pass, shown to the owner as a whole list before it is final.

This is a Godot game built by one owner through many sessions. This file is the complete handoff for every agent that
works on it. It holds everything you need: the owner's wording rules in section 0 (the number one priority), the game,
the rules, the codebase, the testing and the known problems. Chapter files for particular jobs are in `docs/handoff/`;
what is still to do is in chapter 16. It also tells you the mistakes already made, so you don't make them again.
`docs/original_vision.md` is the first design document. It is older than the game: use it for intent, but
trust the code and this file where they disagree.

**Read this file first, then the chapter for the job in hand** (`docs/handoff/`):

| Chapter | Read it before you... |
|---|---|
| `01_feedback_log.md` | do anything at all: every request the owner made, quoted, and the lesson behind it |
| `02_codebase_map.md` | change code: every script, the scene tree, coordinates, physics layers |
| `03_gestures_and_spell_design.md` | add or change a spell or gesture: how recognition works, design rules, school identities, vetted ideas. **Its last section, "The world has laws", binds every spell and every interaction: a spell makes things, the laws (`Elements`, `Damage`, `Substances`) do the rest; never one spell against another** |
| `04_art_and_assets.md` | add or change anything visible: style rules, every source, how to judge and process an asset |
| `05_audio.md` | touch sound: every sound has one owner and is played with `Sfx.cue(owner, event)`; sources, layering, choosing sounds you can't hear |
| `06_enemies_and_ai.md` | touch the creatures or the AI wizards |
| `07_testing.md` | say anything is done |
| `08_working_with_the_owner.md` | reply to the owner |
| `09_godot_pitfalls.md` | debug something strange |
| `12_liquids.md` | touch water or lava: pools are a flowing grid now (`LiquidGrid`, `Pond`), and a Sinkhole dug beside one fills from it |
| `11_network_play.md` | touch anything a second machine must see: wizards, spells, pages, gates, the match, the dedicated server |
| `13_special_worlds.md` | touch the portal fields, the ocean (swimming, breath, wrecks) or the sky (flying, rising pages, thunderclouds) |
| `16_open_work.md` | pick the next job: what the owner asked for that is not built, their standing decisions on it, and the known failures |
| `18_human_limits.md` | touch the AI wizards (`scripts/brain/`): every limit of a person's eyes, memory and hands the AI must keep, and the check that guards them |
| `19_character_creator.md` | touch how a wizard looks or moves: wizards are made of parts now (skin, outfit, hair, beard, hat, weapon), with 48 animations and a recolored magic layer. Built and in the game; section "As built" at its top says where everything is |
| `17_redesign_plan.md` | restructure the brain, the world, the wizard or the caster: what is wrong with each, the shape to aim for, the order, the checks that guard each |
| `19_character_creator.md` | touch the character creator in the game: wizards made of parts (`PartsLook`, `PartFrames`, `art/parts`), the magic layer's spell colors, which animation to play when |
| `20_making_wizard_parts.md` | make or change a custom wizard's art: a hat, hair, beard, outfit, color, weapon, an animation or an effect on the wizard (`tools/wizard_parts/`, `python tools/wizard_parts/rebuild_all.py`) |
| `22_ai_testing_plan.md` | test or improve the AI wizards: the step-by-step plan (2026-11-24), written so a smaller model can carry it out; `tools/ai_trial.py` measures a change |

> **Phrasal verbs (owner, 2026-11-23; the linguistics of "does a person say it").** People speaking naturally use *phrasal verbs* (a verb plus an adverbial *particle*: light **up**, slow **down**, heal **back**, go **to** sleep) and *prepositional verbs* (a verb plus the preposition that governs its object: lash **at** someone), where formal or technical writing uses the bare single verb. Bare "light the dark", "slow everything", "lash someone" are the wrong *register* (Latinate or technical, not spoken): "light" alone means ignite, "slow" alone is mostly an adjective, and "lash someone" claims a hit where "lash at" only aims it (the *conative alternation*, as "hit" vs "hit at"). So: (1) prefer the phrasal verb a person would say (lights **up** the ground, slows **down** everything, fall **down**, wash **away**, blow **out**); (2) pick the particle by what it adds: *up/down* mark a result or direction, *at* marks aiming, *out/away/off* mark removal; (3) use the fixed idiom for the act ("go to sleep", "take a rest", "gamble"), not a dictionary verb that means the same; (4) the test is always: would someone say it aloud to a friend? Do not add facts the owner did not ask for (Glowcap heals; the line does not say so).

---

## 0. Player-facing words: THE NUMBER ONE PRIORITY

**The spellbook changed on 2026-11-07, but the change is small: it gained two stat lines and nothing else.** The owner first made the spellbook a canon tome with
no numbers, then reversed that part. A spell's page now has: (1) **its short description, written as before**: a plain phrase a person would say that names the thing,
about the length of the old lines ("Hurl a bolt of fire.", "Ignite a column of fire.", "Conjure a dying star."); (2) **a damage line**, in the shortest form, as a rate
where it ticks ("14 dmg/sec") or a flat figure where it strikes once ("30 dmg"), nothing when it deals none, and **for a spell or chant that heals, the same place holds what it mends with a plus sign** ("+55 max stamina", "+3 max stamina/sec", "up to +40 max stamina"; `Spell.heal_line`, `Mending.line_of`, section 6a); (3) **a cost line** ("30 stamina", and "maximum stamina"
for a Necromancy spell, which is paid in maximum stamina; a drawn size gives a range). The two stat lines are written by the game from the spell's data
(`Spell.damage_line`, `Spell.cost_line`; the owner settled the wording: "30 stamina" and "30 max stamina", with no durations for now). Chant pages: the short description, and the cost
(none, except a Rift's maximum stamina). **The two stat lines always sit at the foot of the page, just above the page number, damage first and cost last** (`Spellbook._foot`),
so a reader always knows where to look for them, whatever the length of the description above.

**The page also names the states a spell puts on someone (owner, 2026-11-19; a second change of heart on "let players learn the interactions").** Above the damage and cost lines
sits a row of small status icons (`Spell.applies`, `Spell.removes`, set in each spell's `.tres`; chants in `Spellbook.CHANT_STATES`). An icon for a state the spell takes off
wears a red cross and is dimmed ("Removes: Burning"). Hovering an icon shows the state's name and what it does to whoever is in it (`StatusBubbles.TIPS`, `Spellbook._status_row`;
tooltips appear at once: `gui/timers/tooltip_delay_sec` is 0). **What a tooltip says is what the state does to the one who has it, never what to cast against it** (no "cast X to
counter Y"). Tooltip style (owner): short fragments, one per line, no full stops, said the way a person would say them ("Take fire damage over time", not notes for a machine). A state
the page already shows by a "Removes" icon is not repeated in another state's tooltip (Wet does not say it puts out flames). The icons are the status bubbles' 9x9 pictures
(`tools/wizard_parts/status_icons.py`; the red cross is one of them); hovering a state's bubble on a wizard shows its name and the seconds it has left, as "Wet 5s" (owner; not shown for a held breath or a state with no clock). The states: Frozen, Slowed, Dazed, Hexed, Silenced,
Holding breath, Choking, Confused (was Raging), Fleeing, Bleeding, Veiled (its bubble shows how many blows are left), Hasted, Adrenaline, Unlimited, Extra jump, Wet, Burning, Oiled,
Sturdy, Fireproof (an obsidian shard), Invisible, Unconscious, Pursued (by a snail). Tangle and Sink are folded into Slowed. A new state needs an icon in that script, an entry in
`StatusBubbles.ORDER`, `NAMES` and `TIPS`, and a line in `_states`.

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

**American spelling (owner, 2026-11-07).** Anything a player reads uses American English: "Colors", "Favorite", "gray". The code and its comments use American spelling too, so a name is `color` and `center` everywhere.

**The book's order and its NEW mark (owner, 2026-11-07).** In the tutorial the pages are in the order they were found. Everywhere else (a match) they are grouped by school, and within a school in the order found; chants come last (`Spellbook._build_pages`). A page of a spell not yet cast, or a chant not yet said, this game carries a gold star and "NEW!" under its name (`Ledger.mark_cast`, `Spellbook._new_badge`); the waiting room, where every page is known, marks nothing. The star is Kenney's `art/particles/star_07.png`.

**Explicit means the figures, not an explanation. Do not narrate the spell.** The first redo (2026-11-07) wrote every page as a paragraph of mechanics ("the foot of it
flickers for a second, then the whole wall catches and burns for 4 seconds", "14 damage ... again every half second it stays in them") and the owner said it was "way
off the charts". Every other rule in this section still stands, and you may not relax a rule that the owner did not name. Specifically:
- **No mechanics narration.** Timings, warm-ups, how it ends, what it follows, what it is stopped by and what stops it are all left to the player to learn by casting.
  A reader learns "it flickers first" by casting it. The description says what the thing is, and nothing about how it behaves.
- **Stats are figures, not sentences.** Never "deals 14 damage to everything in the flames, again every half second": write the rate, "14 dmg/sec". Work the rate out
  from the code (damage per hit and how often it can land; a wizard cannot be hit more than once in `Wizard.HURT_GRACE`, half a second, by the same source: a spell that has `hit_source()` has its own window, one that does not shares the common one; see `docs/handoff/02_codebase_map.md`).
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

**Mixed text is the third case.** Floating words over a wizard ("Not enough stamina", "Perfect"), the Insight tooltip and
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
A line is either addressed to the reader ("Shoot a chilling bolt of ice.", "Cauterize your wounds to regain max stamina.", "Press Tab to open the spellbook.") or a plain
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
- Use **kindle** for fire ("Kindle a flame.").
- Use **freeze** for ice ("Freeze the surface of a body of water.").
- Use **sprout**, **grow**, **raise**, **summon** for things that come up out of the world.
- Use **negate** rather than **catch**, **absorb** or **block** when a spell stops harm ("Wrap yourself in a veil
  of blood that negates the next few attacks.").
- Do not write "for a while" or "for a little while" (owner, 2026-11-07: "I don't like the wording"). Leave the length out: the player learns it by casting. The one exception is where leaving it out would make a spell read as far too strong: Vires Fluant says "for a short amount of time".
- Use **the target** or **anyone** instead of **it**, **whoever** or **them** when the referent is unclear.

### The owner's standing corrections (each one is a rule)

- Decoy: "Conjure a shadow of yourself." Not "to draw attacks", which explains why and how to use it.
- Faint: "Knock the target unconscious." Not "Draw the strength out of whoever is under it".
- Frost Bridge: "Freeze the ground or a body of water." (owner, 2026-11-21, once it could freeze ground; before: "Freeze the surface of a body of water."). Not "Freeze the water into a bridge of ice".
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
- Rituals: "See how strong creatures are and what spells wizards know."
  "Jump again in mid-air." "Hold your breath."

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

## 0a. How to work: causes, not symptoms (owner, 2026-11-24: a day and a fifth of their tokens lost)

The owner asked for flaky tests to be fixed. I fixed whichever check failed last, re-ran the 17-minute full suite, and repeated for hours. Never do that. Rules:

1. **A request for a class of fix ("flaky tests", "this keeps happening") is a request to find the whole class before touching one instance.** First sweep the entire codebase for the pattern (grep every check, read the runner), list what you found, and fix them together. Do this in the first ten minutes, before any long run, not after the third failure.
2. **Known flaky patterns in this repo's checks:** a blind `_seconds(N)` sleep for something startable (poll for a ready line or condition, with a cap); a scene or node held in a variable across a long wait (look it up again each time); `await` on a signal that may already have fired; a copy of a multi-copy check quitting before the others are done; timing-heavy checks sharing the CPU with parallel ones; unseeded `randomize()` in code a check asserts on; asserting an exact value after a fixed wait.
3. **A failure is evidence, not a nuisance.** Find out why before changing anything. If the game is wrong, fix the game; never tune a test to match the code (see `docs/handoff/07_testing.md`).
4. **Loop a single check about 10 times, alone, before spending a full run.** A full run (about 17 minutes) is for confirming, never for discovering.
5. **Say how long a job will take before starting it, and report every ~5 minutes on long jobs.** If a fix has gone past an hour with new causes appearing, stop and tell the owner what class of problem it is and what you will sweep next.
6. **Do the thorough reading the owner would have to ask for.** If the owner has to push twice to get the right approach, the first approach was wrong: write the lesson here.

## 1. What the game is

A 2D side-view last-wizard-standing duel built in Godot 4.7.2 and GDScript. You are a wizard, and you cast spells by
**actually doing magic**:

- **Fast spells:** hold a school's mouse button(s) and draw a shape. The shape is read by a $1 recognizer
  plus hand-written shape detectors.
- **Rituals:** press Enter and type a pseudo-Latin chant. Typing accuracy sets the ritual's power.

A match: eight identical wizards (`WorldGraph.PLAYERS`: you and seven AI wizards, or friends over a network with AI wizards in the empty seats; the seven figures (LuizMelo's four, and CraftPix's Fire Wizard, Wanderer and Lightning Mage) are shared out and, once they run out, wear other sets of colours, `Net.rival_palette`) race through a generated world for spellbook pages and fight each other. The last one standing wins. The AI wizards cast the same
spells you do, drawing them visibly. There are no waves and no boss.

**The owner's taste, in their words:**
- "sick as hell"
- "not a fan of the cartoony style"
- "that dark wizard was a lot of fun"

**The look:** dark gothic pixel art.
- **Biomes** (the look of each place):
  - a blood-moon graveyard.
  - a jungle (rain, great trees with vines hanging from them), snowy peaks and ashlands (embers and lava over dark basalt).
  - a castle (the whole world is castles side by side, with gothic church interiors, doorways tall enough for a giant, a minotaur giant roaming the ground floors and knights on guard in them and, fewer, on the upper floors, who stand at their posts until a wizard comes near) and the underground (a great cavern under a roof of rock, no sky).
  - **Living scenery** (`WorldScenery.raise_biome_life`, `docs/handoff/02_codebase_map.md`): the graveyard has low mist (`MistBank`), bats (`CritterFlock`) and crypts (`Crypt`, each with a page and a skeleton guard); the jungle has rope bridges between neighbouring great trees (`CanopyBridge`), light shafts, fireflies, swaying vines, birds that burst away and downpours (`Squall`); the peaks have avalanches (`Avalanche`), sheets of ice that make a wizard slide (`IceSheet`) and an aurora; the ashlands have lava lakes that swell (`LavaSurge`), ash storms with falling embers (`EmberRain`) and volcanoes that rumble and shake the world, send up a plume of smoke (`SmokePlume`: no one sees through more than a little of it; on a person's own screen `SmokeVeil` hides what lies past it behind a paler haze, so the dark column and the haze are told apart) and pour lava over the rim that cools to a crust and goes (`Eruption`); the underground has glowing crystals, drips, stalactites that fall on whoever walks under (`FallingRock`) and cave-ins (`CaveLife`). Storms, avalanches, swells and cave-ins follow the world's age, so every machine of a match sees them at the same time. Run `tests/looks/showcase.tscn -- scenario=life` with `WORLD_SEED` (0 jungle, 1 graveyard, 4 mountains, 5 ashlands, 13 underground).
  - the portal fields (`portals`, "The Portal Fields": a level, quiet world where portals open every few seconds and carry a wizard to another; `docs/handoff/13_special_worlds.md`). It is the seventh biome, as much a biome as the others.
  - the ocean (`ocean`, "The Drowned Sea", `docs/handoff/13_special_worlds.md`): a sea over the whole world, mostly under water with very few islands, rafts of driftwood to start on, sunken ships with air pockets and a page, kelp; a wizard swims and holds its breath. Never a match's first world.
  - the sky (`sky`, "The Open Sky", `docs/handoff/13_special_worlds.md`): no ground, every wizard flies (`Wizard.flying`, rival brains are `SkyBrain`), pages rise past the falling wizards and come round again from below (`FallingPage`), clouds rise past and thunderclouds sting and strike (`SkyCloud`). Never a match's first world, and also one of the last world's choices.
  - There are nine biomes (`SurfaceGen.BIOMES`). A match has four worlds, so it visits four of the nine: each of the first three is one of them, in an order the seed picks (the ocean and the sky are dealt in after the first world), and the last, small world is all open sky, one of the five in `SurfaceGen.OPEN_BIOMES` (graveyard, peaks, jungle, ashlands, portal fields) that the match has not been in.
  - **Each biome has landmarks of its own, not just a reskin; only the underground has tunnels.** The graveyard is dark with rain and fog, and its skeletons roam
    (`Mob.roams`). The ashlands have volcanoes that erupt now and then (`Eruption`) and pits of lava. The snowy peaks are mountains to climb (`MountainGale`: wind that grows toward the summits and pushes a wizard without the run animation, seen as streaks; `SnowCloud`: clouds that drift past in front of whoever is in them), with a page on each
    summit. The jungle has pits of mud (`Mudslide`, dug by the world), thickets of thorns (`Bramble`) and great trees (`JungleTree`: dense, in two sizes and mirrored or not, every one with the oak's ledges to hop between and a vine to climb to the high one, where most of the pages lie; the AI climbs the vines; the ponds are full of `Piranhas`). Its art is still named for the swamp it was cut from. The castle is a row of castles with six floors: a cellar down a
    stairwell, the ground floor and four floors over it, three rooms to a floor (see `docs/world_generation.md`).
- **Characters and art:** CraftPix's free packs (the wizards, skeletons, minotaur giant, knights and werewolf: 128 px cells, `python tools/prepare_gothic_art.py <dir> --only=name,name`), LuizMelo's goblin, Ansimuz GothicVania environments, and CC0 pixel effects. The CraftPix licence is in `art/CREDITS.md`: free for the game, but the art must not be resold or offered as files, and the repo's visibility is the owner's call.

## 2. The rules that matter most

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
   **You may draw pixel art yourself, but only the way the other made sprites were (owner, 2026-11-21).** A picture drawn for the game is a Python script in `tools/` (see `tools/wizard_parts/`: `props.py`, `golem.py`, `status_icons.py`) that writes a PNG into `art/`, which the game then loads like any other picture; run it again to rebuild it. Never draw a world object at run time with polygons, circles or lines from your own code (that is the "no code-drawn pictures" rule above, and it stands). Say in the reply which pictures you drew. **Do not make sounds yourself** (owner, 2026-11-07: "you shouldn't do that"). A picture that you do not draw, and every sound, still has to come from a free source found online (CC0, CC-BY or any
   free licence, credited in `art/CREDITS.md`), not be drawn, synthesised or composed by an agent. A synthesised Eldritch Blast "sounded like a fart"; the Scythe blade an agent drew was kept only because the owner
   happened to like it. If nothing free fits, tell the owner and ask. **For sounds, look first in NOX SOUND's Essentials Series (CC0; the owner wants as many sounds as possible from it, 2026-11-19; `docs/handoff/05_audio.md`).**
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
   - Run `tests/checks/test_gestures.gd` and the showcase screenshots, and actually look at the screenshots.
   - Tell the owner what you could not verify (you cannot hear sounds or feel the controls).
9. **Keep text short in game.** The owner disliked wordy spellbook entries, repeated "costs no stamina",
   explaining edge cases, and filler headings like "Incantations, continued."
10. **Talk to the player, not about the game.** Every sentence of on-screen text is imperative and addressed to the player ("Press Tab to
	open the spellbook", "Gives you endless stamina"), never a statement about the system ("Tab opens the spellbook", "Snow slows everything under it"). A key
	and action table may use short verb-first labels. No ALL-CAPS result lines ("The ritual backfired", not "RITUAL BACKFIRED").
    **Spellbook entries** (the older nine rules; where they say "no numbers", "no cost" or "never mention cost scaling", the 2026-11-07 decision in section 0 replaces them):
    2. Say only what the spell does. Never name what counters it, what it combines with, or how to avoid it: the player learns those.
	3. Never mention self-harm ("you too"); it is implied.
	4. Never mention cost scaling or size ("a longer cone costs more").
	5. Write as a wizard inside the universe. No game-loop or meta words: wave, level, run, walkers, "to draw attacks", "as long as your stroke".
    6. Never mention interface actions such as double-clicking.
	7. Be accurate, and say "anyone" or "everything" where a spell has no teams.
    9. Never describe the stroke: the animation shows it.
11. **Don't change what they didn't ask about.** When feedback names five things, fix those five, check
    nothing else broke, and report briefly.
12. **Describe what the thing does to the player, never the numbers behind it** (outside the spellbook's spell and chant pages, which now give their costs and damage, section 0). No multipliers, percentages or comparisons: never "1.6 times faster", "50% more damage", "half damage" or "walks slower". Write "Run faster." The spellbook's damage and cost lines are the only numbers (section 0). Don't list side effects, weaknesses or interactions (what burns it, what it stops, what it combines with): the player learns those by playing. One effect per spell, in one short line.
13. **Name no team.** Spell and game text says "anyone", "anything" or "whoever", never "foes", "enemies", "allies" or "rivals" (spells have no teams, see section 5).
14. **The world has laws; spells only make things (owner, 2026-11-20).** Water puts out fire from any source, oil makes any fire burn longer on any body, heat lights, lightning shocks the wet, force shatters ice, a Barrier turns any shot. These are written once (`Elements`, `Damage`, `Substances`) and act on what a thing IS (groups, `wets`, `quench`, `fire_profile`, `blows_at`, wet/burning/oiled), never on which spell made it. Never write `if node is Fireball` or `if school == "Fire"` into an interaction. Full table and rules: `docs/handoff/03_gestures_and_spell_design.md`, last section.

## 3. Run, test and look

```
GODOT="/c/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                          # after adding or changing any asset
"$GODOT" --headless --path . --quit-after 200                  # parse check: grep the output for "SCRIPT ERROR"
python tools/test.py                                           # THE command: unit tests, then the quick checks (about 3 minutes); --unit, --changed, --full, --pictures (docs/handoff/07_testing.md)
python tools/run_checks.py                                     # the integration checks alone (test.py calls it)
python tools/run_checks.py --full                              # all of them, about 5 minutes
```

`docs/handoff/07_testing.md` lists every check, what it proves and how to run it alone, and says what to do after a change. Run the quick set before you say anything is done.

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
| P | Punch: 1 damage to whoever is in front, no stamina, 0.25 s apart (`Punch`, `wizard.punch`; with a weapon it is a blow with that weapon; AI wizards punch too, about 3 a second at most) |
| M | Mute |
| Esc | Pause and controls list (in a network game the world goes on) |
| F1 | Debug summon panel |
| R | New run, on the game-over screen |

## 5. Spells (the `Spell` resources in `res://data/spells/` are the single source of truth)

| School | Spell | Shape | Real thing | Counterplay |
|---|---|---|---|---|
| Fire | Ignite | straight flick | thrown fireball | dodge, Gust, walls |
| Fire | Firewall | a line along the ground, then a line up from its end (the flames rising): the first line is how wide the wall is, and the wider it is the more it costs (`StrokeShapes.across_and_up`, one `Firewall` column every 26 px along it) | burning brush line | it's passable and only burns; walk out of it |
| Fire | Fire Breath | cone `<` | flamethrower from the mouth (follows facing, rises on a jump) | cover, Barrier, distance |
| Fire | Smoke Screen | wavy line going up | a bank of smoke enemies cannot see through | wind (Tornado, Gust), Tsunami |
| Fire | Flare | flame: a loop with its point up | a small harmless flame that follows you and lights the dark | it burns out |
| Fire | Spark | tall zigzag | a lightning strike from the sky; stops at the first platform or ground | shelter under a platform |
| Water | Frostbolt | flick | thrown ice spear | as Ignite |
| Water | Icicles | one or more Vs in a row, under a ceiling | icicles hanging from the ceiling | step around |
| Water | Ice Prison | circle | freezing whoever is inside solid (4 seconds, and they hold their breath in it) | Push or Earth shatter; Barrier |
| Water | Blizzard | star then a level line | snow cloud | leave the area |
| Water | Frost Bridge | wavy line across water, or along level ground | freezing a pond so you can cross, or the ground into a sheet of ice (`IceSheet`, thaws after 25 s). All ice is slippery (group `slippery`, `IceSheet.under`: the pond's frozen top and every sheet; a wizard on it cannot stop or turn quickly) | fire melts it |
| Water | Geyser | an arrow pointing up | a jet of scalding water that throws what stands on it and scalds it (1 dmg/sec), with steam coming off it | step off while it bubbles |
| Air | Push | circle then a line out | a shove of air; the only spell that lifts you | positioning |
| Air | Barrier | circle | a shield bubble | wait it out |
| Air | Tornado | tall narrow coil going down | a whirlwind | avoid it |
| Air | Vacuum | infinity sign on its side (lungs), drawn over a wizard | the air drawn out of someone's lungs: they hold their breath (no chanting) and then suffocate | it lets go when the caster casts again or is hurt; step out of sight to cast, or hit the caster |
| Air | Updraft | arrow pointing up | a column of rising air that stays for the rest of the world; any number can be raised | none; it lifts anyone |
| Air | Gust | straight flick | wind along the stroke: turns shots, sweeps smoke and you sideways | a giant does not move |
| Earth | Stonefall | circle with a line down | a boulder that falls from where the circle was drawn and hits as hard as it falls (`Boulder.SPEED_PER_DAMAGE`) | watch the shadow |
| Earth | Stone Wall | line starting on the ground, a platform or another stone wall | a raised slab | Earthquake, Stonefall, shots wear it down |
| Earth | Mudslide | wavy line (as Frost Bridge) | a pit of mud: slows, no jumping | walk out |
| Earth | Stalagmite | one or more peaks (^) over the ground | spikes of rock that rise from the ground and hurt whatever touches them | step around |
| Earth | Earthquake | arrow with a head at both ends | the ground shakes, and every stone wall raised anywhere in the world comes down a moment in, and every wall of brick and plug of ice anywhere is worn down by the beats | be off the ground |
| Earth | Sinkhole | U | the ground opens: `Terrain.dig` cuts a pit the shape of the U that was drawn (`Sinkhole.profile_of`) in the open ground and the rock is cut again (permanent) | jump out, fly |
| Flora | Bramble | low sawtooth | a thicket of thorns: slows and pricks | jump it; fire |
| Flora | Spore Puff | cone `<` (as Fire Breath) | poison spores poured from your mouth | wind, water |
| Flora | Liana | leaf and line: an almond lying on its side, then a line up from its left point (a vine) | a vine to climb | fire |
| Flora | Great Oak | trunk drawn up into a round crown | a tree: ledges and a wall, and when it falls it crushes | fire, Earthquake, Stonefall; it creaks first |
| Flora | Flytrap | tall narrow W | a trap that snaps shut on whoever steps in | jump, fire |
| Flora | Lily Pads | a ring (the pad), then a level line across the water where they grow | floating leaves that lie only on the water below where it was cast (none where there is no water: "No water"), to cross a pond | fire; they sink after 8 s |
| Shadow | Decoy | a stick figure in one stroke (the Golem's shape, on the Umbramancy buttons) | a shadow that draws enemies' attacks | it wears out |
| Shadow | Eclipse | the outline of a crescent moon, drawn in one stroke | the whole world goes dark for as long as an Earthquake lasts (6 s); everyone sees only what is close; costs 60, as an Earthquake does | Flare |
| Shadow | Hex | pentagram (five-point star, one stroke) | a curse: 50% more damage | short time |
| Shadow | Silence | circle with a line struck through it | a ring where nothing can be cast, spell or chant (`Wizard.silenced`) | step out; it fades |
| Shadow | Black Hole | inward spiral | a dark knot that pulls everything toward it, fiercely close in and faintly from far off (walls still stop it) | walk out |
| Shadow | Shadow Step | flick | slipping along the stroke | |

**The spellbook page** (owner decision, 2026-11-07): the drawn picture, a short description, the damage it deals ("14 dmg/sec", "30 dmg") and its cost in stamina (maximum stamina for Necromancy), see section 0. Everything else about a spell, what counters it included, is learned in play. The table above is the first 32 spells. The others (Vacuum, Updraft, Sinkhole, Stalagmite, Silence, Fight or Flight, Sneak, Hunter's Mark, the Blood spells, Tide Surf, Obsidian Armor, Glowcap and Moonbeam) are in `data/spells/` and `docs/spell_pool.md`.

**The schools have new names** (the ids Fire, Water, Air, Earth, Flora, Shadow and Blood stay in code and double as element tags; only what a player reads changed, through `SpellData.school_name`): Pyromancy, Aquamagy, Aerokinesis, Terramancy, Druidry, Umbramancy and Necromancy. The Library gives a rank from how matches have gone (`Library.title`, `Library.rank_of`): a rating from 1 to 9 that each match moves by the finishing place, shown as Novice, Apprentice, Initiate, Adept, Magus, Master, Grandmaster, Archmage, Champion (owner, 2026-11-15; it replaced the old titles from casts: Novice, Pyromancer, Sorcerer). The rating will also set the level of the AI wizards in network matches.

**Spells added later:**

| School | Spell | Shape | Real thing | Counterplay |
|---|---|---|---|---|
| Air | Dancing Lights | a five-point star (`pentagram`, on the Air button) | colorful lights that pop up and fade close round the caster for 25 s (`DancingLights`; each light, `DancingLights.Mote`, is itself the light: a real light in the dark, and a light for the Eclipse and for sight); lights, not fires, so nothing puts them out; costs 14 | none needed |
| Fire | Jolt | Spark's zigzag turned on its side, three strokes drawn across (`bolt`; the recognizer ignores rotation, so `StrokeReader.settle` tells it from Spark by which way it runs: across is Jolt, down is Spark) | a bolt that leaves the staff along the stroke and strikes the first thing in its way at once (14), and hurries whoever it strikes for 1.5 s (`Jolt`). It is in the group `lightning`, so a wet body takes it harder by the law (`Damage`), not by any rule of its own; costs 20 (draft line: "Shoot a crackling bolt of lightning.") | a wall, distance |
| Water | Bathe | the Stonefall shape: a circle and a line down (on the Water button) | a shower over the caster that washes them clean (`Substances.wash`: flame, oil, chill, tangle, curse, wound, daze, fright and a snail on their heels all go) and leaves them wet; costs 30 (draft line: "Wash yourself clean in a shower of water.") | none needed |
| Air | Headwind | the Earthquake shape: an arrow with a head at both ends (on the Air button) | a wind round the caster for 12 s: whoever or whatever comes into it is slowed, every shot in the "shots" group included, lava balls, hail, a falling boulder, a falling stone and a rolling Flaming Sphere too (each shot has `hinder`; `new_spells_check` fails if one lacks it; slowed, not turned or stopped); the caster and their own shots go through it; costs 30 (draft line: "Surround yourself with a howling wind.") | leave it; it ends |
| Fire | Cauterize | an X (`cross`, on the Fire button; the X and its mirror are both templates) | the wounds are seared shut: +55 max stamina at once, then the wizard burns (the law of fire: a wet wizard cannot be lit, so for them it does nothing); costs 25 (`SelfMending.cauterize`; draft line: "Cauterize your wounds to regain max stamina.") | water |
| Water | Healing Spring | a basin and a spout (`spring`: a U, back along its top to the middle, and up), on the Water button | a basin of clear water wells up from the ground for the rest of the world (`HealingSpring`, art by `tools/spring_art.py`); anyone standing in it mends +2 max stamina/sec, the caster's rivals too, and is wet by the law of waters (the group "waters"); one to a wizard; needs ground; costs 40 (draft line: "A spring wells up that heals anyone standing in it.") | it is shared |
| Air | Breathe | a peace sign (`peace`: a ring, a line down through it and two to the sides, one stroke), on the Air button | +3 max stamina/sec for 10 s, and a blow ends it; costs 25 (`SelfMending.breathe`; draft line: "Regain max stamina for 10 seconds.") | a blow |
| Earth | Mud Mask | a figure of eight (`eight`, on the Earth buttons) | +2 max stamina/sec for 20 s, and nothing ends it; costs 40 (`SelfMending.mud_mask`; draft line: "Regain max stamina for 20 seconds.") | none |
| Fire | Flaming Sphere | a ring drawn from its bottom, then a level line along the ground | a ball of fire that rolls, follows slopes, falls into pits and climbs a wall (`FlamingSphere`, a `CharacterBody2D`; it keeps the ground round it made through the `ground_watchers` group); burns out after a long roll | jump it; water and rain put it out |
| Water | Hailstorm | a ring, a line out of it, then a line down | a storm cloud that drops hail along the line | a roof |
| Air | Featherfall | a feather drifting down: three sweeps across, each bent down in the middle, each ending lower | a slow fall for a while | none needed |
| Flora | Barbs | a flick | a short spread of thorns | stone, fire |
| Earth | Pebble | a flick | a stone that falls as it flies (goes over a wall that stops a flat shot) | cover |
| Flora | Thorn Whip | the Tide Surf wave | a lash that drags the first thing it meets toward the caster (a wizard, an enemy, a loose page) | a wall, fire; a giant is too heavy |
| Flora | Insect Plague | an infinity sign, like a bee's wings | a stinging swarm, one cloud that ticks, drawn as insects; it follows the nearest wizard it can see (the caster after a few seconds) | one hit, fire, water, wind; a Barrier, a faded (Sneak) wizard, smoke or a stone wall in its way |
| Necromancy | Leech | the Tide Surf wave, aimed at a wizard | a tether (`Leech`): while it holds, every stamina spell the caster casts is paid half by the caster and half by the other end; it breaks when they lose sight of each other, move too far apart, or either falls | a wall, distance |
| Air | Thunderclap | a cloud (a ring begun at its bottom), then a lightning bolt: a zigzag down out of it | thunder (a recording): throws back everyone near except the caster (no harm) and dazes them (`Wizard.daze_time`: slow, and no spell or chant) | stay out of its reach |
| Fire | Rocket Jump | an arrow pointing up (drawn with the fire button) | flame from the feet lifts the caster slowly at first and then faster, about 480 px up (`RocketJump`, `Wizard.rocket_time`) | none needed |
| Necromancy | Raise Dead | a Latin cross: a long stem and a shorter bar across it, nearer the top | a skeleton (a `Mob` with a `master`) with 50 health for 37 maximum stamina, not refunded | kill it |
| Flora | Wild Shape | a crescent moon (the Eclipse's shape, on the Druidry buttons), costs 40 | the wizard becomes a werewolf (CraftPix art, `WildShape.begin`): their own stamina is put aside, the wolf has a pool of 1 that nothing drains (owner, 2026-11-08: one blow ends it), it runs faster, jumps and claws (left click, 12 dmg) and casts nothing; the first blow turns the wizard back with the stamina they had, and does not kill them | it wears off; a rival's blows; a wall |
| Necromancy | Invincible Snail | a ring, then a level line out of it (the shell and the foot: `sphere`, on the Necromancy buttons), drawn over a wizard | a snail (`InvincibleSnail`, art drawn for the game in `tools/wizard_parts/props.py`, `art/mobs/snail/`) that crawls after them at a sixth of a walk and kills at a touch; nothing harms it; it fades when its quarry falls and goes with them from world to world, appearing in the exact middle of the new one (`MatchState.snails`); costs 120 maximum stamina; one per caster | a wall, a pit, a gap, a jump, flying, Ice Prison, Push |
| Earth | Golem | a stick figure in one stroke: the head (a ring), the body down from it, out to one foot, back, out to the other (`stick`) | the ground grows up around the wizard (`GolemRise`, spires of the world's own earth) and a man of stone stands out of it, for 10 seconds (`GolemForm`, `wizard.golem`, art drawn for the game by `tools/wizard_parts/golem.py`, `art/mobs/golem/`; the stone is the very texture of the ground, cut by `stone` in `wizard_body.gdshader`): slow (half pace), cannot cast, jumps low (0.7 of a jump) and shakes the ground where it lands (a screen shake, dust, 12 dmg and a toss to whoever stands near), takes half of every blow; a left click slams a fist for 40 that throws the target back, a right click brings both fists down for 80 after a long raise (2 s apart) and shakes the ground hard; costs 60 | it is slow: a pit, a gap, a wall; Faint, Ice Prison |
| Water | Water Jet | a cone, as Fire Breath's (`cone`) | a hose: a hard stream from the mouth that does no harm, pushes back wizards, creatures, loose rocks and shots (`WaterJet`), leaves a wizard Wet, puts out flames and washes an oil slick away; costs 20 (draft line: "Spray a torrent of water.") | the ground and walls stop it; a giant does not move |
| Earth | Oil Slick | a drop (a loop with its point up) then a level line along the ground (`oil`, drawn with `StrokeShapes.pad_line`) | a pool of oil (`OilSlick`) that makes the ground slippery (a wizard cannot stop or turn quickly, as on ice, `Wizard.OIL_GRIP`) and leaves whoever crosses it Oiled; any fire touching it sets the whole slick off in burning ground; it lies only on the ground it was cast on (it stops at a wall or a drop and never jumps to a platform above or the floor below, as a Mudslide does not); costs 24 (draft line: "Pour a slick of oil on the ground.") | water washes it away; walk out |
| Umbramancy | Mirage | a tall box | a false page that wavers and fades when anyone comes near (`Mirage`, a `PagePickup`) | walk up to it; the AI learns after seeing one fade |

The school and spell design, the gate tags and the balance pass are in `docs/spell_pool.md`. The waiting room (`scenes/lab.tscn`, `scripts/arena/lab.gd`) is where every spell is tried; the portal there
starts a run. The first screen also has a **Tutorial** (`scripts/arena/tutorial.gd`: a book that starts empty and a row of things in the way, each with the pages that answer it lying at its foot; only the keys to walk and jump are on screen. A dummy and a giant (too strong to kill: a Faint puts it down) strike down whoever walks past them, a pond of piranhas (waded after a Spark, or crossed on ice or pads), turrets that hit whoever has no cover, thorns too long to walk through, a cliff only a vine climbs, a gap only the double jump chant crosses, a dark stretch of spikes only a light shows, a gate that asks for two spells together (a light then fire), a pit and past it a wall of brick (a leap, then a quake or a boulder), an eye that shoots (cover, then fire on the thorns), poison gas (wind, fire or a Barrier) with a second pit after it, and a pond of piranhas in the dark (a light, then a Spark), and last of all a run with no page to read that uses what was learned: a gap that takes the double jump chant, a cliff that takes a vine, a pit that takes a leap and a long thicket that takes fire (`Tutorial.FINALE_*`, from column 536 on). Whoever falls keeps the pages they read) a **Duel** (`scripts/arena/duel.gd`, `scenes/duel.tscn`, owner 2026-11-21: the person against one AI wizard in a room one screen wide, each dealt a starting book as a match deals it, new books every round; the AI is at the level the waiting room's wall was last set to, else 9. Every round is written to `user://duel_logs/` by `DuelLog` at twenty samples a second, and `python -I tools/duel_study.py` sets the person's fighting and dodging beside the AI's; it was built so an agent can learn from how the owner fights) and a **Library** (`scripts/core/library.gd`, `library_screen.gd`: what this machine remembers of the matches played on it, in `user://library.json`: matches played and won, and for each page how often it was found, its spell cast, and a match won with it in the book. Only the person at the machine, only in real matches; the tests never touch it).

**Attacking spells from the overnight batch of eight (2026-11-06; the owner vetoed six of them on 2026-11-07, see "Inventing a spell" in section 6) and the two the owner then approved (Supernova and Scythe). Each has a test in `tests/checks/group_d_check.tscn`:**

| School | Spell | Shape | Real thing | Counterplay |
|---|---|---|---|---|
| Shadow | Eldritch Blast | an arrow (the beam goes the way it points) | a beam of crackling dark energy that strikes the first thing in its way at once, up to 640 px, as the spell of that name in Dungeons & Dragons does (`EldritchBlast`, a ray: no shot to dodge or turn) | a wall, distance |
| Blood | Hemorrhage | a drop of blood: the flame shape (`flare`), drawn over someone | a wound that bleeds a little at a time for a while (`Hemorrhage`), and drains the wounded wizard: slower (`Wizard.DRAINED_SPEED`) and a shaking hand (`Caster.tremor`, `BrainHand.shaken`) | it wears off |
| Fire | Supernova | a circle with a line struck through it, the "do not enter" sign (`silence`, as Silence has it, on the Fire button) | a dying star hangs where it was drawn for 5 seconds: it burns whoever is close, pulls everything toward it a little, then explodes, hurting and throwing everyone within about 320 px far away (`Supernova`); costs 80 | get clear before it blows; stone or a wall |
| Blood | Scythe | a crescent (the blade) | one swing of a real scythe (pixel art drawn for the game, `art/fx/scythe.png`, a pale ghost blade) in a half circle in front of the caster that cuts hard (45) and drives them back (`Scythe`) | stay out of reach, a wall |

The spellbook lines (see the book: every spell now has a plain description, a damage line and a cost line) are drafts until the owner confirms them. Where a school has both a circle and a flame, a loop the recognizer takes for a flame but is not one is read again without the flames (`Caster._end`). `tests/looks/attacks_look.tscn -- out=DIR` (needs a window) takes pictures of them.

**Pages per world:** each world lays only `Pages.count_for(biome, width)` pages (graveyard 16, peaks 16, jungle 18, ashlands 12, castle 18, underground 20, portal fields 10, at 1000 tiles wide, fewer in the smaller worlds, never under 6), and which ones is settled when the match begins, from its seed (`Pages.allotment`): each wizard is dealt starting pages of their own, and each world is given pages of its own from the rest, no page in two places, some in none. So a page is never in a world once a wizard holds it, and no two wizards start alike. Pages not laid do not carry over. **Cutscenes cannot be skipped in a game with others (owner, 2026-11-22: `CutScene._unskippable`, `Net.online()`; the skip-the-opening and skip-the-ending settings are ignored there).** **Every wizard also starts with one way to heal, a different one each (`Pages.HEALS`, section 6a).** **The starting pages fit the first world (owner, 2026-11-22): where a match begins in the dark (`Pages.DARK_START`: the underground), each wizard's starting pages include one that makes light, a different one for each seat (`Pages.LIGHT_MAKERS`, ten: Flare, Glowcap, Moonbeam, Dancing Lights, Fire Breath, the three that are fires, Ignite, Firewall and Flaming Sphere, since the world lights every fire, and Spark and Jolt, which flash the whole screen like lightning (`ScreenFlash`, owner 2026-11-22). Supernova glows greatly but is deliberately not counted; a wizard already dealt Ignite or Fire Breath needs no more). `Pages.starting_deal` / `cluster_of(…, first_biome)`; `test_pages` and `cluster_check` guard it. Another dark first world goes in `DARK_START`.** **A world leans to some pages (owner, 2026-11-21): `Pages.LEAN` gives a page a weight in that biome's draw (a spell's name, a chant's page or "school:X"; the Deep favors lights and fire, the others lean gently to their own school). It is chance with a tilt, not a rule, and still obeys "no page in two places".** **A page that could not be used in a world is never laid there (owner, 2026-11-21): `Pages.unusable_in(biome)` leaves out of the sky what needs ground or is not needed in the air (the lists in `SpellLimits`) , Lily Pads from worlds with no water (`Pages.DRY`; Frost Bridge freezes ground too, so it is laid anywhere) and Icicles from the open-air worlds (`SurfaceGen.OPEN_BIOMES`: no roof to hang from).** Light is not one school's job (owner, 2026-11-21): Air got Dancing Lights only because it was the smallest school then, and any school may make light. A new spell goes where its nature fits, and where schools are unequal, to the smaller one; the aim is 12 spells in every school (propose them first, as every new spell). **The worlds shrink hard (owner, 2026-11-23: to force fights): 900, 560, 340 and 240 columns, collapsing after 180, 150 and 120 seconds, and the last world closes in (`ClosingWalls`: after 60 s its two ends turn deadly, 4 damage every half second to anyone outside, and move in at 28 px/s from each side until a stretch of 1100 px is left; each end is a wall of fire made of the game's own fire pictures, with dark smoke behind it).** The underground world is 0.6 of a stage's width, as the castle world is (`MatchState.UNDERGROUND_SHARE`). A kind of gate the world has always keeps a page that opens it, swapped in from the spare pages if need be (`Pages.with_openers`). In a world with no halls, pages lying out in the open are at least `Pages.MIN_APART` (40) columns apart, apart from the three near the start (`tests/looks/pages_spread_look.tscn` prints where they lie).

**Reading a page (owner, 2026-11-21):** a page that is read flies to the reader from where it lay, one at a time (`PageFlight`), and its name rises beside them in its school's color (gold for a chant); a fallen wizard's book is read the same way, and the person's own book opens once the last page has arrived. The tutorial's first pages show "Press Tab to read" from afar (`PagePickup.always_hint`). A spell cast with too little stamina says "Not enough stamina" ("Not enough max stamina" for blood) and the stamina bar flares red (`HudBar.alarm`), so it is not taken for a misdrawn shape. The open book says, under it and at its sides, that the arrow keys turn the pages (`Spellbook._make_turn_cues`; the arrows pulse until a page has been turned).

**Targeting types:** `directional`, `pointed` (toward the far end of the stroke, as an arrow points: Thorn Whip, Eldritch Blast), `raised` (from where the stroke began, on the ground: Stone Wall), `positional`, `angled`, `shape` and `cone`. The caster's `cast_resolved`
signal passes `info` (radius, line, rect, shapes, aim, spread, reach), and `arena.spawn_spell` routes it (see `Casting`).
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
   only compares within the held button combination. Add a test case to `tests/checks/test_gestures.gd` and add the
   preview to `GestureTemplates.preview_points`. The AI wizards draw from those previews too.
5. **Physics honesty:** what blocks it, who it hurts (the caster too?), and whether it goes through platforms.
6. **Telegraph:** the enemy or player must see it coming. Examples: Stonefall's shadow, the falling-shot ring,
   the cloud's flicker.
7. **Art from a free pack,** recoloured to the school's colour in `tools/prepare_gothic_art.py`.
8. **A sound,** chosen with `tools/audio_profile.py` or mixed in `tools/make_sounds.py`. Say plainly that you
   couldn't listen to it.
9. **Teach the AI wizards to use it** (`scripts/brain/brain_combat.gd`): a score in `BrainCombat.attack` and a stroke in
   `BrainHand.attack_stroke`.
10. **Spellbook:** a short description, and the damage and cost lines from the spell's data, at the foot of the page. Keep it short.

## 6a. Healing (owner, 2026-11-22: there are many ways to heal, and each wizard starts with one)

Healing is always maximum stamina (`Wizard.heal`, never past `Wizard.MAX_STAMINA`), and a heal raises the stamina held by the same amount. Everything that mends a wizard other than the Glowcap is in `Mending` (`scripts/wizard/mending.gd`, reached as `wizard.mending`). The laws of it, written once there:
- **One heal over time at a time** (`Mending.begin` takes the place of the one that was on), and every heal over time, the Healing Spring's included, draws on **one allowance of `Mending.CAP` (6) maximum stamina a second** (`Mending.pour`). Sleep is the exception (`SLEEP_RATE` 12), since a sleeper can do nothing else.
- A **hit ends a Breathe and wakes a sleeper** (`Mending.struck`); **moving or casting ends a Rest**; nothing ends a Mud Mask.
- A heal that is a **gesture pays its price in current stamina** and heals maximum stamina (the exchange rate rises with the stroke's difficulty); **chants cost no stamina**.
- **The chants** (`RitualInput.RITUALS`, effects in `Mending.say`; the Latin is the owner's, "honc shue honc shue" for Long Rest is theirs): Mending ("sana me", +5 at once; the page names are "Charm of Mending", "Psalm of Rest", "Charm of Recovery", "Chant of the Bloody Needle" (owner), "Chant of the Cast Die" (owner), "Long Rest" (owner kept it), "Resurrection" (owner) and "Prayer of Restoration"; the owner also wants the kinds of chant told apart by word (Chant, Charm, Psalm, Prayer, Blessing, Incantation, Rite): charm for a small quick working, psalm for something calm, prayer for a great plea, blessing for a gift, incantation for a great working, in the order of the chants below; the owner rejected fancier names for the plain ones as "way off the reservation", so keep flavor modest), Rest ("quiesce paulum", +3/sec while still), Recovery ("redde quod ereptum", gives back what a wound took in the last 10 s, at most 40), Stitch ("suere vulnera mea", +3 for every blow you land for 30 s (owner, 2026-11-24: it was 15 and too weak): `MatchStats.hit` tells `Mending.landed`), Gamble ("alea iacta est", three times in four +30, one in four -30, and it can kill: `Wizard.lose_max`), Long Rest ("honc shue honc shue": the wizard sleeps, `Wizard.fall_asleep`/`wake`, mends 12/sec until whole, and `Substances.relieve` takes every ill off but a Hex and a snail), Second Chance (10 words: armed until used, kept in the book (`Ledger.armed`) so it goes between worlds, one at a time; `Mending.rescue` is asked in `Wizard._check_death`, so it works against every way of dying, and brings the wizard back at 30% of the most (60), at the last safe place they stood, with a short grace) and Restoration (12 words, like the Bonfire's, up to +120 by how well it was said). **The Bonfire and its chant ("Incantation of the Hearthfire", a 12-word chant for a long heal over time) were removed on 2026-11-23: the owner said a long heal over time needs a short incantation, and Rest and the Healing Spring already do that job, so it overlapped and was cut (`Bonfire`, its art and its tests are gone).**
- **Dealing** (`Pages.HEALS`, `Pages.EACH`): every wizard starts with one of Mending, Rest, Recovery, Stitch, Cauterize, Breathe, Mud Mask or Healing Spring, a different one each; Restoration, Long Rest, Second Chance and Gamble are found. A duel's book has none (`Duel.BOOK`).
- **The spellbook writes the figure where damage goes, with a plus sign** (`Spell.heal`/`heal_line`, `Mending.line_of` for chants): "+55 max stamina", a rate "+3 max stamina/sec", "up to +40 max stamina" where it may give less, "+30 max stamina or -30 max stamina" for the Gamble. The descriptions of Mending ("Close a small wound."), Rest ("Rest and mend."), Recovery, Stitch and Gamble are drafts; the others the owner chose.
- **The brain** (`BrainMend`): worn below half it says the greatest chant it holds (`heal_chant`), or draws Mud Mask, Breathe, Cauterize (worn below 40%) or Healing Spring (no rival close) in `tend`, and says Second Chance ahead of need; it never Gambles or Stitches. `tests/checks/heal_check.gd` proves every law, and `brain_spells_check` that the brain draws the four spells.
- No sounds were made for these (the chant sound stands in); the owner has not heard them.

## 6b. States on a body and the status bubbles (2026-11-18)

A wizard can be **Wet, Burning or Oiled** (`scripts/wizard/coating.gd`, reached as `wizard.coat`; marks bits WET/BURNING/OILED are synced to network likenesses). Wet: lightning
(`SparkStrike`) hits 1.6 times as hard, fire cannot light them, ice holds them longer, and a Blizzard freezes them in half the time (`Coating.CHILL_WET`). Burning: 2 damage each half second (not a grace hit), water puts it out, `BodyFlames` joins the
`"fires"` group so a burning wizard lights what they touch. Oiled: a fire that takes hold burns twice as long, and the oil goes. Wet comes from Water Jet, Tide Surf, Geyser, ponds, the ocean and rain; never from Hailstorm, Blizzard or Frostbolt.
**Status bubbles** (`StatusBubbles`, `wizard.bubbles`): one small bubble round the wizard for each state, clockwise from the top in the order the states began, with a ring that empties like a clock for the ones on a timer; a held breath turns into Choking when its air runs out.
Healing has two more: Mending (a heal is flowing in, with a clock for the timed ones) and Second chance (one is armed). The icons are made by `tools/wizard_parts/status_icons.py` (the owner allowed these to be drawn by the agent: an exception to the no-self-made-art rule, only for these icons). A network likeness shows only what the marks carry. Featherfall shows drifting feathers (`Featherfall.drift`).
In the air the keys only nudge a wizard (`Wizard.AIR_STEER`, `AIR_ACCEL`, `AIR_DRAG`), so a shove or a pull carries on; the AI's navigation has not been reworked for that (`brain_spells_check` and `ai_drills_check` fail, see `docs/handoff/16_open_work.md`).

## 7. Art: where it comes from

The pipeline, the sources, how to judge an asset and how to build one are in `docs/handoff/04_art_and_assets.md`. The rules that bind every change:

- **Credits:** every source and licence is in `art/CREDITS.md`. Add a line for anything new.
- **Licences (owner decisions, 2026-10-25 and 2026-11-07):** we are **not restricted to CC0**. Use any art or sound we are really allowed to use in the game for free: CC0,
  CC-BY (a credit line: the author, the pack and a link), and any free licence or "free for commercial use" page whose terms we can meet. Read the terms of the page, and prefer
  CC0 when two assets fit equally. Do not spend money: a paid pack is not free. Where a licence puts a condition on the game itself (share-alike, GPL, "non-commercial only",
  "no redistribution"), tell the owner before using it.
- **Downloads are not kept in the repo.** Re-download them into a scratch folder.
- **Look at an asset before using it** (a contact sheet): it must be dark, gothic pixel art at the characters' density, and an "effect" sheet may secretly hold a character.

## 8. Godot pitfalls

`docs/handoff/09_godot_pitfalls.md` lists the ones that already bit. The two that bite hardest: never `load()` a texture inside `_draw()` into a local variable (it is freed before
it renders, and draws as a white rectangle: use a `preload()` constant or a cache), and `var x := dict["k"]` does not parse (give the variable a type). Physics layers are in
`docs/handoff/02_codebase_map.md`.

## 9. Code style and structure

This code was grown one request at a time, which turns code into spaghetti unless each change keeps the shape
clean. It was cleaned up once, without losing any behaviour. Keep it that way:

- **Comments:** plain English `##` doc comments that say *why*, written like the existing ones. No jargon.
- **Names:** descriptive, and named after what the thing is *now*. When a feature changes, rename it (Quicksand
  became `Mudslide`; the fire walker's effect became `"burning"` when it stopped leaving a trail).
- **One script per spell effect.** Never add a branch on the spell's name (`if spell == "..."`) to a shared
  script. Simple effects extend `SpellEffect` (`scripts/spells/spell_effect.gd`) and fill in `_begin`, `_act`
  and `_finish`; bigger ones are their own Node. A simple effect needs nothing more (the spell's resource names its script); one that needs more is a recipe in one of the four tables in `scripts/spells/` (`CasterSpells`, `AimedSpells`, `PlacedSpells`, `ShapeSpells`, put together by `SpellSpawner`).
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
  arena or the AI (the earthquake's shaky hand is in `BrainHand.shaken`, not in the caster).
- **Use the engine.** Prefer Godot's own tools (groups, signals, `Area2D` overlaps, `StaticBody2D`, tweens,
  `Rect2` helpers) over hand-rolled bookkeeping.
- **Delete dead code** (unused functions, signals, art) in the same change that makes it dead, and update
  `art/CREDITS.md`, `tools/prepare_gothic_art.py` and these docs to match.
- **Refactoring:** change one thing at a time and re-run the full check after each step (startup, gestures,
  the soak scenario, the spells showcase), comparing screenshots against a baseline taken first.

## 10. Ideas the owner may like

- More spells that combine (fire melting ice, water putting out fire, lightning in pools and a fire whirl are built).
- More to the tutorial room (`Tutorial`, `scenes/tutorial.tscn`: a page for each school, with two meetings of spells), such as a place for the chants.
- Music is built (`Music`, `scripts/core/music.gd`: a track per place, chosen by the owner; `docs/handoff/05_audio.md`). Places still quiet are waiting for the owner's choice. No AI-made music, ever.

When unsure, ask the owner one clear question rather than guessing big.
