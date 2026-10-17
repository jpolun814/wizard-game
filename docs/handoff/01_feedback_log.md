# The owner's feedback, in order, and what each one teaches

Every request and correction the owner has made, with the lesson behind it. Read it to learn their taste: most
future requests will rhyme with these. Quotes are the owner's own words, typos and all.

---

## Round 1: "make this game much much better"

> "better graphics, better AI for the dark wizard, better hitboxes on the sprites, making sure everything is lined
> up properly and nothing looks weird (like the dark wizard spawning in the ground), come up with new spells that
> make thematic sense for the schools, come up with good "spell shapes" for those spells (not just something
> arbitrary)... download free-to-use graphics/sprites and things from online so that we dont have to create
> graphics in code... give me recommendations"

**Lessons:**
- They want ambition and initiative, not timid tweaks. "Get to work" means do a lot, and verify it.
- **Alignment matters to them.** Feet on the ground, hitboxes matching the drawing, nothing sunk into terrain.
  Check alignment in screenshots, with Godot's `--debug-collisions` when in doubt.
- **"Not just something arbitrary"** is the origin of the rule that a gesture must be a picture of its spell.
- **Assets over code drawing** was asked for on day one. It took three rounds to fully honour, so don't regress.
- They like recommendations at the end of a report.

> "the handoff file was old it may not be accurate to the game and what we want it to do"

**Lesson:** the code is the source of truth. `docs/original_vision.md` is history and intent, not a spec.

## Round 2: the first detailed play-test

> "i wanted the fire wall to be something anyone could pass through i didnt want it to be solid."

The Firewall had been changed so that it blocked enemies. **Lesson:** don't "fix" a mechanic into something the
owner didn't design. When an old description and the code disagree, ask, or pick the reading that matches the
physical analogue. A wall of fire is not a wall.

> "the spellbook gets taller when switching to the incantations page but it shouldn't. it should just put the
> other incantations onto the other page."

**Lesson:** fixed-size UI. Content must flow to the next page, never stretch the container.

> "i dont want to have to press space to go down through the one-way platforms and it's not clear to me what's a
> one-way platform vs not."

**Lessons:**
- Controls should be one obvious key: S drops through.
- Interactive differences must be **visible**. One-way platforms are wooden walkways; solid ground looks like
  earth or stone.

> "not sure im a fan of fire nova because it doesnt seem to reflect anything in real life and is impossible to
> block."

**The most important design lesson in this file.** Spells must be physically grounded and counterable. Fire Nova
was replaced with Fire Breath, a flamethrower that cover blocks.

> "the snow effects could be more visible they're pretty hard to see."

**Lesson:** check effects against **every** background, including the bright and snowy ones. White on white
vanishes; give small particles a dark rim.

> "i dont think the gravity well should do any damage."

**Lesson:** utility spells can be pure utility. Don't bolt damage onto everything.

> "the sounds for blink and spark aren't very accurate... i think the push spell sound isn't very good either."

**Lessons:**
- They do listen to the sounds, and they care that each one matches what happens on screen.
- Spark should be a crack followed by a thunder roll. Blink should be an electric zip. Push should be a whump
  of air.
- You cannot hear audio, so pick sounds by analysis and say so.

> "we should show in the spellbook that an earth wall cant be drawn out of nowhere it has to sprout from the
> ground or platform. also stone walls should be able to sprout from themselves."

**Lessons:**
- Hidden rules must be shown in the spellbook. The Stone Wall picture now has a ground strip under its start.
- Physical consistency again: stone grows from stone.

> "i dont want rituals to backfire if you bail out of them early."

**Lesson:** don't punish the player for stopping an action. Only real mistakes (a garbled chant) carry a cost.

> "that dark wizard was a lot of fun. you did an all-around great job"

**Lesson:** the duel against a visible-casting wizard is a core pillar. Protect it and build on it.

## Round 3

> "the force barrier shouldnt impact anything other than projectiles."

This means Force Wall. It used to shove characters too. **Lesson:** each spell does one clear thing.

> "the fire breath should change directions when i change directions, it should go up when i go up. get it?
> like as if its coming out of my mouth."

**Lesson:** effects that come from a character must stay attached to it, at the right body part, and follow its
facing. Think about how the effect would actually look coming out of a body.

> "the spellbook is a little too big and doesnt look enough like a book. and it moves when i want to type an
> incantation but the incantation textbox shouldnt have any impact on whats on screen"

**Lessons:**
- Opening one UI must never move another.
- "Look like a book" means a real book object, not a panel with text.

## Round 4: the art direction pivot

> "there are plenty of code-drawn polygons like the wizard hat and staff and stuff and the volcano and other such
> things that id love to have real assets for. and i think the wizard and dark wizard sprites need to look cooler
> and more serious. in general im not a fan of the cartoony style of the game i want it to be sick as hell"

**Lessons:**
- The style is dark, gothic, serious pixel art. Kenney's cartoony platformer art was rejected.
- The art was rebuilt around LuizMelo characters and GothicVania worlds (see `04_art_and_assets.md`).

## Round 5

> "the stonefall is just a white rectangle that falls."

A rendering bug: a texture was loaded inside `_draw` and freed. **Lesson:** look at your screenshots closely.
That white box was visible in a screenshot and got waved away as "probably a frozen enemy". Never explain away
something odd in a screenshot without proving it.

> "the storm clouds should hit anyone under the cloud, including the caster."

**Lesson:** fairness and physicality beat "smart" targeting. The old cloud preferred foes.

> "the stonefall shouldnt explode."

**Lesson:** don't add flashy effects that contradict the physics. A dropped rock thuds and kicks up dust.

> "i dont like that the earth melee guy looks different than the other melee guys."

**Lesson:** consistent visual language. The same role means the same creature, and the school is shown by
colour.

> "theres actually quite a few things that look like white rectangles instead of some sort of art. all the other
> code-drawn pictures stick out like sore thumbs they absolutely have to be replaced"

**Lesson:** the no-code-drawn-art rule is absolute for anything in the world.

## Round 6

> "when held, the wand looks like a staff."

**Lesson:** what the player holds must match what they picked up. The art had no wand, so the staff was cut down
to a wand in every frame.

> "lightning should not be able to go through platforms."

**Lesson:** physical consistency, again.

> "the spellbook really needs some work to look more on-theme."

**Lesson:** UI belongs to the art direction too. The spellbook became a pixel-art book with page-turn
animations, pixel fonts and pixel icons.

> "the spellbooks incantation descriptions are too wordy. all incantations cost no stamina so no need to repeat
> it all the time. no need to say what happens if you garble the incantation or want to stop casting it. no need
> for the seocnd page to say 'incantations, continued'"

**Lesson:** brevity. Say a shared fact once or not at all, and drop filler.

## Round 7

> "write a very robust handoff/guide file that teaches cheaper AI models exactly the vibe of the game..."

This document set is the result.

---

## Patterns across all rounds

1. **Physical plausibility.** Asked about in nearly every round: fire, lightning, walls, clouds and rocks should
   behave like the real thing.
2. **Fairness and counterplay.** Nothing unblockable. The caster is not exempt from area spells.
3. **Visual honesty.** Interactive things look different (platforms), and held items look right (the wand).
4. **Art quality and cohesion.** No placeholder shapes, one art style, one pixel size.
5. **Short text.**
6. **They enjoy depth that is learnable,** like the wizard drawing its spells where you can see them.
